#!/bin/bash
# Superalgos Start Script
# Exit immediately if a command exits with a non-zero status
set -e

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
    echo -e "${GREEN}[SUPERALGOS]${NC} $1"
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to print error messages
print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to safely create and set permissions for a directory
safe_mkdir() {
    local dir="$1"
    
    # Create directory if it doesn't exist
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        print_status "Created $dir directory"
    fi
    
    # Attempt to set permissions, with detailed error reporting
    if ! chmod 775 "$dir" 2>/dev/null; then
        print_warning "Could not set permissions for $dir"
        print_warning "Filesystem details for $dir:"
        df -h "$dir" || print_error "Unable to get filesystem details"
        print_warning "Current directory permissions:"
        ls -ld "$dir" || print_error "Unable to list directory details"
    fi
}

# Check if Docker and Docker Compose are installed
check_docker_installed() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_warning "docker-compose not found. Attempting to use 'docker compose' command."
        DOCKER_COMPOSE_CMD="docker compose"
    else
        DOCKER_COMPOSE_CMD="docker-compose"
    fi
}

# Pull the latest Superalgos image
pull_latest_image() {
    print_status "Pulling the latest Superalgos image..."
    "$DOCKER_COMPOSE_CMD" pull superalgos
}

# Initialize secrets and required directories
initialize_secrets() {
    print_status "Checking and initializing secrets and directories..."
    
    # Create My-Secrets directory if not exists
    safe_mkdir "My-Secrets"
    
    # Create empty workspace-credentials.json if not exists
    if [ ! -f "My-Secrets/workspace-credentials.json" ]; then
        echo '{}' > My-Secrets/workspace-credentials.json
        print_status "Created empty workspace-credentials.json"
    fi
    
    # List of required directories
    REQUIRED_DIRS=(
        "My-Data-Storage"
        "My-Log-Files/Platform"
        "My-Workspaces"
        "My-Network-Nodes-Data"
        "My-Social-Trading-Data"
    )
    
    # Create required directories
    for dir in "${REQUIRED_DIRS[@]}"; do
        # Split directory path if needed
        base_dir=$(echo "$dir" | cut -d'/' -f1)
        sub_dir=$(echo "$dir" | cut -d'/' -f2-)
        
        # Create base directory
        safe_mkdir "$base_dir"
        
        # Create subdirectory if specified
        if [ -n "$sub_dir" ] && [ "$sub_dir" != "$base_dir" ]; then
            safe_mkdir "$base_dir/$sub_dir"
        fi
    done
}

# Start Superalgos
start_superalgos() {
    print_status "Starting Superalgos..."
    "$DOCKER_COMPOSE_CMD" up -d
}

# View logs
view_logs() {
    print_status "Showing Superalgos logs (press Ctrl+C to exit)..."
    "$DOCKER_COMPOSE_CMD" logs -f superalgos
}

# Main script execution
main() {
    # Check for help flag
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        echo "Superalgos Start Script"
        echo "Usage: ./start.sh [options]"
        echo "Options:"
        echo " --pull Pull the latest image before starting"
        echo " --logs View logs after starting"
        echo " -h, --help Show this help message"
        exit 0
    fi
    
    # Check Docker installation
    check_docker_installed
    
    # Pull image if requested
    if [[ "$1" == "--pull" ]]; then
        pull_latest_image
    fi
    
    # Initialize secrets and directories
    initialize_secrets
    
    # Start Superalgos
    start_superalgos
    
    # View logs if requested
    if [[ "$1" == "--logs" ]]; then
        view_logs
    else
        print_status "Superalgos started successfully. Use 'docker-compose logs -f superalgos' to view logs."
    fi
}

# Run the main function with all script arguments
main "$@"