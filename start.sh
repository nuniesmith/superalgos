#!/bin/bash
# Superalgos Start Script - Enhanced Version
# Exit immediately if a command exits with a non-zero status
set -e

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Get the current user and group ID
CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)

# Script version
SCRIPT_VERSION="1.1.0"

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

# Function to print system messages
print_system() {
    echo -e "${PURPLE}[SYSTEM]${NC} $1"
}

# Display a welcome banner
show_welcome() {
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                     SUPERALGOS LAUNCHER                        ║${NC}"
    echo -e "${GREEN}║                       Version ${SCRIPT_VERSION}                        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
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
    local PERM=${2:-775}  # Default permission is 775, but can be overridden
    
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
            sudo chown -R 1001:1001 "$dir" && sudo chmod -R $PERM "$dir"
            if [ $? -eq 0 ]; then
                print_status "Permissions set successfully with sudo"
            else
                print_error "Failed to set permissions even with sudo"
            fi
        else
            print_error "Cannot request sudo in non-interactive mode. Please run: sudo chown -R 1001:1001 $dir && sudo chmod -R $PERM $dir"
        fi
    else
        # Set permissions and ownership for container access (1001:1001)
        chown -R 1001:1001 "$dir" 2>/dev/null || print_warning "Could not set ownership for $dir"
        chmod -R $PERM "$dir" 2>/dev/null || print_warning "Could not set permissions for $dir"
    fi
}

# Check if Docker and Docker Compose are installed
check_docker_installed() {
    print_system "Checking Docker and Docker Compose installation..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check Docker version
    docker_version=$(docker --version | awk '{print $3}' | sed 's/,//')
    print_info "Docker version: $docker_version"
    
    # Check Docker is running
    if ! docker info &>/dev/null; then
        print_error "Docker daemon is not running. Please start Docker service first."
        exit 1
    fi
    
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
    
    # Check if docker-compose.yml exists
    if [ ! -f "docker-compose.yml" ]; then
        print_error "docker-compose.yml file not found in the current directory."
        print_info "Please run this script from the directory containing your docker-compose.yml file."
        exit 1
    fi
}

# Initialize required directories with correct permissions
initialize_directories() {
    print_system "Creating and initializing required directories..."
    
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
    safe_mkdir "Platform/My-PM2-Data" 777  # Use 777 permissions for PM2
    safe_mkdir "Platform/My-PM2-Data/logs" 777
    safe_mkdir "Platform/My-PM2-Data/pids" 777
    safe_mkdir "Platform/My-PM2-Data/modules" 777
    
    # Create empty workspace-credentials.json if not exists
    if [ ! -f "Platform/My-Secrets/workspace-credentials.json" ]; then
        echo '{}' > Platform/My-Secrets/workspace-credentials.json
        chmod 664 Platform/My-Secrets/workspace-credentials.json
        chown 1001:1001 Platform/My-Secrets/workspace-credentials.json 2>/dev/null || true
        print_status "Created empty workspace-credentials.json"
    fi
    
    # Create empty PM2 config file if not exists
    if [ ! -f "Platform/My-PM2-Data/module_conf.json" ]; then
        echo '{}' > Platform/My-PM2-Data/module_conf.json
        chmod 666 Platform/My-PM2-Data/module_conf.json
        chown 1001:1001 Platform/My-PM2-Data/module_conf.json 2>/dev/null || true
        print_status "Created empty module_conf.json for PM2"
    fi
    
    # Create .gitkeep files for empty directories
    for dir in Platform/My-{Data-Storage,Log-Files,Workspaces,Network-Nodes-Data,Social-Trading-Data,Secrets,PM2-Data}; do
        if [ ! -f "$dir/.gitkeep" ]; then
            touch "$dir/.gitkeep" 2>/dev/null || true
        fi
    done
}

# Check and update docker-compose.yml if needed
check_docker_compose() {
    print_system "Checking docker-compose.yml configuration..."
    
    # Check for old volume paths
    if grep -q './My-Data-Storage:' docker-compose.yml; then
        print_warning "Your docker-compose.yml appears to use old volume paths."
        
        # Ask if user wants to auto-update
        if [ -t 1 ]; then  # Check if running in a terminal
            read -p "Would you like to automatically update paths in docker-compose.yml? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                # Create backup
                cp docker-compose.yml docker-compose.yml.bak
                print_info "Created backup of docker-compose.yml as docker-compose.yml.bak"
                
                # Update paths
                sed -i 's#./My-Data-Storage:#./Platform/My-Data-Storage:#g' docker-compose.yml
                sed -i 's#./My-Log-Files:#./Platform/My-Log-Files:#g' docker-compose.yml
                sed -i 's#./My-Workspaces:#./Platform/My-Workspaces:#g' docker-compose.yml
                sed -i 's#./My-Network-Nodes-Data:#./Platform/My-Network-Nodes-Data:#g' docker-compose.yml
                sed -i 's#./My-Social-Trading-Data:#./Platform/My-Social-Trading-Data:#g' docker-compose.yml
                sed -i 's#./My-Secrets:#./Platform/My-Secrets:#g' docker-compose.yml
                
                print_status "Updated volume paths in docker-compose.yml"
            else
                print_info "Please manually update volume paths in docker-compose.yml to use './Platform/My-Data-Storage' format"
            fi
        else
            print_info "You need to update volume paths in docker-compose.yml to use './Platform/My-Data-Storage' format"
            print_info "Example: './Platform/My-Data-Storage:/app/Platform/My-Data-Storage:z'"
        fi
    else
        print_info "Volume paths in docker-compose.yml appear to be correct."
    fi
    
    # Check if using named volume for PM2
    if grep -q 'pm2_data:/app/Platform/My-PM2-Data' docker-compose.yml; then
        print_info "Using named volume for PM2 data (recommended)."
    elif grep -q './Platform/My-PM2-Data:/app/Platform/My-PM2-Data' docker-compose.yml; then
        print_warning "Using bind mount for PM2 data. Consider switching to a named volume:"
        
        # Ask if user wants to auto-update
        if [ -t 1 ]; then  # Check if running in a terminal
            read -p "Would you like to update docker-compose.yml to use a named volume for PM2? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                # Create backup if not already created
                if [ ! -f "docker-compose.yml.bak" ]; then
                    cp docker-compose.yml docker-compose.yml.bak
                    print_info "Created backup of docker-compose.yml as docker-compose.yml.bak"
                fi
                
                # Check if volumes section exists
                if ! grep -q "^volumes:" docker-compose.yml; then
                    # Add volumes section at the top
                    sed -i '1s/^/volumes:\n  pm2_data:\n\n/' docker-compose.yml
                else
                    # Add pm2_data to existing volumes section
                    sed -i '/^volumes:/a\  pm2_data:' docker-compose.yml
                fi
                
                # Update PM2 volume mounting
                sed -i 's#./Platform/My-PM2-Data:/app/Platform/My-PM2-Data#pm2_data:/app/Platform/My-PM2-Data#g' docker-compose.yml
                
                print_status "Updated docker-compose.yml to use named volume for PM2 data"
            else
                print_info "You may want to manually update your docker-compose.yml"
                print_info "Add 'volumes: pm2_data:' at the top level of docker-compose.yml"
                print_info "Then change './Platform/My-PM2-Data:/app/Platform/My-PM2-Data' to 'pm2_data:/app/Platform/My-PM2-Data'"
            fi
        else
            print_info "Add 'volumes: pm2_data:' at the top level of docker-compose.yml"
            print_info "Then change './Platform/My-PM2-Data:/app/Platform/My-PM2-Data' to 'pm2_data:/app/Platform/My-PM2-Data'"
        fi
    fi
}

# Start Superalgos
start_superalgos() {
    print_system "Starting Superalgos containers..."
    "$DOCKER_COMPOSE_CMD" up -d
    
    if [ $? -eq 0 ]; then
        print_status "Superalgos started successfully!"
        print_info "You can access the platform at: http://superalgos.local"
        print_info "Dashboard available at: http://superalgos.local/dashboard"
        print_info "Direct access (if superalgos.local DNS is not set up): http://localhost:34248"
    else
        print_error "Failed to start Superalgos. Check the logs for more information."
        return 1
    fi
}

# View logs
view_logs() {
    print_system "Showing Superalgos logs (press Ctrl+C to exit)..."
    "$DOCKER_COMPOSE_CMD" logs -f superalgos
}

# Stop Superalgos
stop_superalgos() {
    print_system "Stopping Superalgos containers..."
    "$DOCKER_COMPOSE_CMD" down
    
    if [ $? -eq 0 ]; then
        print_status "Superalgos stopped successfully."
    else
        print_error "Failed to stop Superalgos cleanly."
        return 1
    fi
}

# Restart Superalgos
restart_superalgos() {
    print_system "Restarting Superalgos containers..."
    stop_superalgos
    initialize_directories
    check_docker_compose
    start_superalgos
}

# Show container status
show_status() {
    print_system "Checking Superalgos container status..."
    "$DOCKER_COMPOSE_CMD" ps
}

# Fix permissions for all directories
fix_permissions() {
    print_system "Fixing permissions for all Superalgos directories..."
    
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
    print_system "Fixing permissions specifically for PM2 data directory..."
    
    if [ $CURRENT_UID -ne 0 ]; then
        if [ -t 1 ]; then  # Check if running in a terminal
            print_info "Requesting sudo to fix PM2 permissions..."
            sudo mkdir -p Platform/My-PM2-Data/{logs,pids,modules}
            sudo chown -R 1001:1001 Platform/My-PM2-Data/
            sudo chmod -R 777 Platform/My-PM2-Data/
            
            # Create empty module_conf.json if not exists
            if [ ! -f "Platform/My-PM2-Data/module_conf.json" ]; then
                echo '{}' | sudo tee Platform/My-PM2-Data/module_conf.json > /dev/null
                sudo chmod 666 Platform/My-PM2-Data/module_conf.json
                sudo chown 1001:1001 Platform/My-PM2-Data/module_conf.json
            fi
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
        
        # Create empty module_conf.json if not exists
        if [ ! -f "Platform/My-PM2-Data/module_conf.json" ]; then
            echo '{}' > Platform/My-PM2-Data/module_conf.json
            chmod 666 Platform/My-PM2-Data/module_conf.json
            chown 1001:1001 Platform/My-PM2-Data/module_conf.json
        fi
    fi
    
    print_status "PM2 permissions fixed successfully."
}

# Show help/usage information
show_help() {
    echo "Superalgos Start Script - Version $SCRIPT_VERSION"
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
    echo " --check            Check configuration and directories without starting"
    echo " --update           Update the script to the latest version"
    echo " -h, --help         Show this help message"
    echo ""
    echo "Examples:"
    echo " ./start.sh                  # Start Superalgos"
    echo " ./start.sh --logs           # Start Superalgos and view logs"
    echo " ./start.sh --fix-pm2        # Fix PM2 permissions only"
    echo ""
}

# Main script execution
main() {
    show_welcome
    
    # Check for help flag
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        show_help
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
        restart_superalgos
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
    
    # Check for check configuration flag
    if [[ "$1" == "--check" ]]; then
        initialize_directories
        check_docker_compose
        print_status "Configuration check completed. No changes were made to running containers."
        exit 0
    fi
    
    # Initialize directories
    initialize_directories
    
    # Check docker-compose configuration
    check_docker_compose
    
    # Pull image if requested
    if [[ "$1" == "--pull" ]]; then
        print_system "Pulling the latest Superalgos image..."
        "$DOCKER_COMPOSE_CMD" pull superalgos
    fi
    
    # Start Superalgos unless --check was specified
    if [[ "$1" != "--check" ]]; then
        start_superalgos
    fi
    
    # View logs if requested
    if [[ "$1" == "--logs" ]]; then
        view_logs
    else
        print_info "Use './$0 --logs' to view logs or '$DOCKER_COMPOSE_CMD logs -f superalgos'"
    fi
}

# Run the main function with all script arguments
main "$@"