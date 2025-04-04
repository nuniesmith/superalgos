#!/bin/bash
# Superalgos Start Script
# Exit immediately if a command exits with a non-zero status
set -e

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the current user and group ID
CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)

# Function to print status messages
print_status() {
    echo -e "${GREEN}[SUPERALGOS]${NC} $1"
}

# Function to print info messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to print error messages
print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if we need sudo to perform an operation
need_sudo() {
    local test_dir="$1"
    if [ $CURRENT_UID -ne 0 ]; then
        # Try to touch a test file to see if we have write permissions
        if ! touch "$test_dir/.test_permissions" 2>/dev/null; then
            return 0 # Need sudo
        fi
        rm -f "$test_dir/.test_permissions" 2>/dev/null
    fi
    return 1 # Don't need sudo
}

# Function to safely create and set permissions for a directory
safe_mkdir() {
    local dir="$1"
    
    # Create directory if it doesn't exist
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        print_status "Created $dir directory"
    else
        print_info "Directory $dir already exists"
    fi
    
    # Check if we need sudo for permission setting
    if need_sudo "$dir"; then
        print_warning "Elevated permissions required for $dir"
        if [ -t 1 ]; then  # Check if running in a terminal
            print_info "Requesting sudo access to set directory permissions..."
            sudo chown -R 1001:1001 "$dir" && sudo chmod -R 775 "$dir"
            if [ $? -eq 0 ]; then
                print_status "Permissions set successfully with sudo"
            else
                print_error "Failed to set permissions even with sudo"
            fi
        else
            print_error "Cannot request sudo in non-interactive mode. Please run: sudo chown -R 1001:1001 $dir && sudo chmod -R 775 $dir"
        fi
    else
        # Set permissions and ownership for container access (1001:1001)
        chown -R 1001:1001 "$dir" 2>/dev/null || print_warning "Could not set ownership for $dir"
        chmod -R 775 "$dir" 2>/dev/null || print_warning "Could not set permissions for $dir"
    fi
}

# Check if Docker and Docker Compose are installed
check_docker_installed() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check Docker version
    docker_version=$(docker --version | awk '{print $3}' | sed 's/,//')
    print_info "Docker version: $docker_version"
    
    # Check for docker-compose command
    if ! command -v docker-compose &> /dev/null; then
        print_warning "docker-compose not found. Checking for 'docker compose' plugin..."
        if docker compose version &> /dev/null; then
            print_info "Docker Compose plugin found."
            DOCKER_COMPOSE_CMD="docker compose"
        else
            print_error "Neither docker-compose nor docker compose plugin found. Please install Docker Compose."
            exit 1
        fi
    else
        DOCKER_COMPOSE_CMD="docker-compose"
        compose_version=$(docker-compose --version | awk '{print $3}' | sed 's/,//')
        print_info "Docker Compose version: $compose_version"
    fi
}

# Initialize required directories with correct permissions
initialize_directories() {
    print_status "Creating and initializing required directories..."
    
    # Create Platform directory
    safe_mkdir "Platform"
    
    # Create required directories with proper nesting
    safe_mkdir "Platform/My-Data-Storage"
    safe_mkdir "Platform/My-Log-Files"
    safe_mkdir "Platform/My-Log-Files/Platform"  # Note the nested Platform directory
    safe_mkdir "Platform/My-Workspaces"
    safe_mkdir "Platform/My-Network-Nodes-Data"
    safe_mkdir "Platform/My-Social-Trading-Data"
    
    # Create My-Secrets directory if needed
    safe_mkdir "Platform/My-Secrets"
    
    # Create PM2 Data directory with additional subdirectories
    safe_mkdir "Platform/My-PM2-Data"
    safe_mkdir "Platform/My-PM2-Data/logs"
    safe_mkdir "Platform/My-PM2-Data/pids"
    safe_mkdir "Platform/My-PM2-Data/modules"
    
    print_status "Setting extra permissions for PM2 directory..."
    # Ensure PM2 data directory has the correct permissions
    if need_sudo "Platform/My-PM2-Data"; then
        if [ -t 1 ]; then  # Check if running in a terminal
            sudo chmod -R 777 "Platform/My-PM2-Data"
        else
            print_warning "Cannot set enhanced permissions for PM2 data. Please run: sudo chmod -R 777 Platform/My-PM2-Data"
        fi
    else
        chmod -R 777 "Platform/My-PM2-Data" 2>/dev/null || print_warning "Could not set enhanced permissions for Platform/My-PM2-Data"
    fi
    
    # Create empty workspace-credentials.json if not exists
    if [ ! -f "Platform/My-Secrets/workspace-credentials.json" ]; then
        echo '{}' > Platform/My-Secrets/workspace-credentials.json
        chmod 664 Platform/My-Secrets/workspace-credentials.json
        
        # Try to set ownership with sudo if needed
        if need_sudo "Platform/My-Secrets"; then
            if [ -t 1 ]; then  # Check if running in a terminal
                sudo chown 1001:1001 Platform/My-Secrets/workspace-credentials.json
            else
                print_warning "Cannot set correct ownership for workspace-credentials.json. Non-interactive mode."
            fi
        else
            chown 1001:1001 Platform/My-Secrets/workspace-credentials.json 2>/dev/null || true
        fi
        
        print_status "Created empty workspace-credentials.json"
    fi
    
    # Create empty PM2 config file if not exists
    if [ ! -f "Platform/My-PM2-Data/module_conf.json" ]; then
        echo '{}' > Platform/My-PM2-Data/module_conf.json
        chmod 666 Platform/My-PM2-Data/module_conf.json
        
        # Try to set ownership with sudo if needed
        if need_sudo "Platform/My-PM2-Data"; then
            if [ -t 1 ]; then  # Check if running in a terminal
                sudo chown 1001:1001 Platform/My-PM2-Data/module_conf.json
            else
                print_warning "Cannot set correct ownership for module_conf.json. Non-interactive mode."
            fi
        else
            chown 1001:1001 Platform/My-PM2-Data/module_conf.json 2>/dev/null || true
        fi
        
        print_status "Created empty module_conf.json for PM2"
    fi
    
    # Check for permission issues
    print_status "Checking directory permissions..."
}

# Update docker-compose.yml volume paths if needed
check_docker_compose() {
    print_status "Checking docker-compose.yml configuration..."
    
    if grep -q './My-Data-Storage:' docker-compose.yml; then
        print_warning "Your docker-compose.yml appears to use old volume paths."
        print_info "You need to update volume paths in docker-compose.yml to use './Platform/My-Data-Storage' format"
        print_info "Example: './Platform/My-Data-Storage:/app/Platform/My-Data-Storage:z'"
    else
        print_info "Volume paths in docker-compose.yml appear to be correct."
    fi
    
    # Check if using named volume for PM2
    if grep -q 'pm2_data:/app/Platform/My-PM2-Data' docker-compose.yml; then
        print_info "Using named volume for PM2 data (recommended)."
    elif grep -q './Platform/My-PM2-Data:/app/Platform/My-PM2-Data' docker-compose.yml; then
        print_warning "Using bind mount for PM2 data. Consider switching to a named volume:"
        print_info "Add 'volumes: pm2_data:' at the top level of docker-compose.yml"
        print_info "Then change './Platform/My-PM2-Data:/app/Platform/My-PM2-Data' to 'pm2_data:/app/Platform/My-PM2-Data'"
    fi
}

# Start Superalgos
start_superalgos() {
    print_status "Starting Superalgos..."
    "$DOCKER_COMPOSE_CMD" up -d
    
    if [ $? -eq 0 ]; then
        print_status "Superalgos started successfully!"
        print_info "You can access the platform at: http://superalgos.local"
        print_info "Dashboard available at: http://superalgos.local/dashboard"
    else
        print_error "Failed to start Superalgos. Check the logs for more information."
        return 1
    fi
}

# View logs
view_logs() {
    print_status "Showing Superalgos logs (press Ctrl+C to exit)..."
    "$DOCKER_COMPOSE_CMD" logs -f superalgos
}

# Stop Superalgos
stop_superalgos() {
    print_status "Stopping Superalgos..."
    "$DOCKER_COMPOSE_CMD" down
    
    if [ $? -eq 0 ]; then
        print_status "Superalgos stopped successfully."
    else
        print_error "Failed to stop Superalgos cleanly."
        return 1
    fi
}

# Show container status
show_status() {
    print_status "Checking Superalgos container status..."
    "$DOCKER_COMPOSE_CMD" ps
}

# Fix permissions for all directories
fix_permissions() {
    print_status "Fixing permissions for all Superalgos directories..."
    
    if [ $CURRENT_UID -ne 0 ]; then
        if [ -t 1 ]; then  # Check if running in a terminal
            print_info "Requesting sudo to fix permissions..."
            # Re-run the same command with sudo
            exec sudo "$0" --fix-permissions
            # If exec fails, the script will continue
            print_error "Failed to escalate privileges. Please run: sudo $0 --fix-permissions"
            return 1
        else
            print_error "Cannot request sudo in non-interactive mode. Please run: sudo $0 --fix-permissions"
            return 1
        fi
    fi
    
    chown -R 1001:1001 Platform/
    chmod -R 775 Platform/
    
    # Extra permissions for PM2 directory
    chmod -R 777 Platform/My-PM2-Data/
    
    print_status "Permissions fixed successfully."
}

# Fix PM2 permissions specifically
fix_pm2_permissions() {
    print_status "Fixing permissions specifically for PM2 data directory..."
    
    if [ $CURRENT_UID -ne 0 ]; then
        if [ -t 1 ]; then  # Check if running in a terminal
            print_info "Requesting sudo to fix PM2 permissions..."
            sudo mkdir -p Platform/My-PM2-Data/{logs,pids,modules}
            sudo chown -R 1001:1001 Platform/My-PM2-Data/
            sudo chmod -R 777 Platform/My-PM2-Data/
        else
            print_error "Cannot request sudo in non-interactive mode. Please run these commands manually:"
            print_info "sudo mkdir -p Platform/My-PM2-Data/{logs,pids,modules}"
            print_info "sudo chown -R 1001:1001 Platform/My-PM2-Data/"
            print_info "sudo chmod -R 777 Platform/My-PM2-Data/"
            return 1
        fi
    else
        mkdir -p Platform/My-PM2-Data/{logs,pids,modules}
        chown -R 1001:1001 Platform/My-PM2-Data/
        chmod -R 777 Platform/My-PM2-Data/
    fi
    
    # Create empty module_conf.json if not exists
    if [ ! -f "Platform/My-PM2-Data/module_conf.json" ]; then
        echo '{}' > Platform/My-PM2-Data/module_conf.json
        chmod 666 Platform/My-PM2-Data/module_conf.json
        chown 1001:1001 Platform/My-PM2-Data/module_conf.json 2>/dev/null || true
    fi
    
    print_status "PM2 permissions fixed successfully."
}

# Main script execution
main() {
    # Check for help flag
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        echo "Superalgos Start Script"
        echo "Usage: ./start.sh [options]"
        echo ""
        echo "Options:"
        echo " --pull             Pull the latest image before starting"
        echo " --logs             View logs after starting"
        echo " --stop             Stop all Superalgos containers"
        echo " --restart          Restart all Superalgos containers"
        echo " --status           Show status of Superalgos containers"
        echo " --fix-permissions  Fix permissions on all directories (requires sudo)"
        echo " --fix-pm2          Fix only PM2 directory permissions (requires sudo)"
        echo " -h, --help         Show this help message"
        exit 0
    fi
    
    # Check for fix-permissions flag
    if [[ "$1" == "--fix-permissions" ]]; then
        fix_permissions
        exit $?
    fi
    
    # Check for fix-pm2 flag
    if [[ "$1" == "--fix-pm2" ]]; then
        fix_pm2_permissions
        exit $?
    fi
    
    # Check Docker installation
    check_docker_installed
    
    # Check for restart flag
    if [[ "$1" == "--restart" ]]; then
        stop_superalgos
        initialize_directories
        check_docker_compose
        start_superalgos
        exit 0
    fi
    
    # Check for stop flag
    if [[ "$1" == "--stop" ]]; then
        stop_superalgos
        exit 0
    fi
    
    # Check for status flag
    if [[ "$1" == "--status" ]]; then
        show_status
        exit 0
    fi
    
    # Initialize directories
    initialize_directories
    
    # Check docker-compose configuration
    check_docker_compose
    
    # Pull image if requested
    if [[ "$1" == "--pull" ]]; then
        print_status "Pulling the latest Superalgos image..."
        "$DOCKER_COMPOSE_CMD" pull superalgos
    fi
    
    # Start Superalgos
    start_superalgos
    
    # View logs if requested
    if [[ "$1" == "--logs" ]]; then
        view_logs
    else
        print_status "Use './$0 --logs' to view logs or '$DOCKER_COMPOSE_CMD logs -f superalgos'"
    fi
}

# Run the main function with all script arguments
main "$@"