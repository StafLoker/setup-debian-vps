#!/bin/bash

set -euo pipefail

# Check if script is run as root
check_root() {
    [ "$EUID" -ne 0 ] && echo "Run as root" && exit 1
}

# Color Definitions
readonly RED='\033[31m'
readonly YELLOW='\033[33m'
readonly GREEN='\033[32m'
readonly PURPLE='\033[36m'
readonly BLUE='\033[34m'
readonly RESET='\033[0m'

# Global variables
CREATED_USERS=()
SUDO_USERS=()
SSH_PORT=""

# Installation paths
readonly REMNA_DIR="/opt/remnanode"

# External URLs
readonly MOTD_INSTALL_URL="https://raw.githubusercontent.com/StafLoker/linux-utils/main/motd/install.sh"

# Function to print INFO messages
log_info() {
    echo -e "${YELLOW}[INFO] $1${RESET}"
}

# Function to print SUCCESS messages
log_success() {
    echo -e "${GREEN}[SUCCESS] $1${RESET}"
}

# Function to print ERROR messages
log_error() {
    echo -e "${RED}[ERROR] $1${RESET}"
}

# Function to print WARNING messages
log_warning() {
    echo -e "${PURPLE}[WARNING] $1${RESET}"
}

# Function to print DEBUG messages
log_debug() {
    echo -e "${BLUE}[DEBUG] $1${RESET}"
}

# Function to check if Docker is installed
is_docker_installed() {
    command -v docker &> /dev/null && command -v docker-compose &> /dev/null
}

# Function to check if Remnanode is installed
is_remnanode_installed() {
    [[ -d "$REMNA_DIR" ]] && [[ -f "$REMNA_DIR/docker-compose.yml" ]]
}

# Function to ask yes/no questions
ask_yes_no() {
    local question="$1"
    local default="${2:-n}"
    local answer

    while true; do
        if [[ "$default" == "y" ]]; then
            read -p "$question [Y/n]: " answer
            answer=${answer:-y}
        else
            read -p "$question [y/N]: " answer
            answer=${answer:-n}
        fi

        case ${answer,,} in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) log_warning "Please answer 'y' or 'n'" ;;
        esac
    done
}

# Configure additional ports
configure_additional_ports() {
    log_info "Enter additional ports to open (enter 0 to finish):"
    log_info "Formats accepted: 333, 333/tcp, 333/udp"
    
    while true; do
        read -p "Enter port (0 to finish): " PORT
        
        if [[ "$PORT" == "0" ]]; then
            log_info "Finished configuring additional ports"
            break
        fi
        
        # Validate port format (number, number/tcp, number/udp)
        if [[ "$PORT" =~ ^[0-9]+$ ]]; then
            # Just a number, validate range
            if [ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ]; then
                log_debug "Opening port $PORT..."
                ufw allow $PORT
                log_success "Port $PORT opened successfully"
            else
                log_error "Invalid port number. Please enter a number between 1 and 65535, or 0 to finish."
            fi
        elif [[ "$PORT" =~ ^[0-9]+/(tcp|udp)$ ]]; then
            # Number with protocol, extract port number for validation
            PORT_NUM=$(echo "$PORT" | cut -d'/' -f1)
            if [ "$PORT_NUM" -ge 1 ] && [ "$PORT_NUM" -le 65535 ]; then
                log_debug "Opening port $PORT..."
                ufw allow $PORT
                log_success "Port $PORT opened successfully"
            else
                log_error "Invalid port number. Please enter a number between 1 and 65535, or 0 to finish."
            fi
        else
            log_error "Invalid port format. Use: 333, 333/tcp, or 333/udp (or 0 to finish)."
        fi
    done
}

# System update and basic packages
system_update() {
    log_debug "Start updating system"
    apt update && apt upgrade -y
    apt full-upgrade
    apt autoremove
    log_success "System update completed"

    log_debug "Install sudo package"
    apt install -y sudo
    log_success "Sudo package installed"

    # Add /usr/sbin to PATH if not already present
    log_debug "Configuring PATH to include /usr/sbin..."
    if ! grep -q 'export PATH=$PATH:/usr/sbin' ~/.bashrc; then
        echo 'export PATH=$PATH:/usr/sbin' >> ~/.bashrc
        log_success "/usr/sbin added to PATH in ~/.bashrc"
    else
        log_info "/usr/sbin already in PATH"
    fi

    # Apply changes to current session
    export PATH=$PATH:/usr/sbin
    log_success "PATH configuration completed"
}

# Change hostname
change_hostname() {
    read -p "Enter the new hostname [blank to skip]: " NEW_HOSTNAME

    if [ -n "$NEW_HOSTNAME" ]; then
        log_debug "Changing the hostname to $NEW_HOSTNAME"
        hostnamectl set-hostname "$NEW_HOSTNAME"
        echo "127.0.1.1    $NEW_HOSTNAME" >> /etc/hosts
        log_success "Hostname changed to $NEW_HOSTNAME"
    else
        log_warning "No hostname provided, skipping"
    fi
}

# Change root password
change_root_password() {
    while true; do
        read -s -p "Enter new root password: " ROOT_PASSWORD
        echo ""
        read -s -p "Confirm new root password: " ROOT_PASSWORD_CONFIRM
        echo ""
        if [ "$ROOT_PASSWORD" == "$ROOT_PASSWORD_CONFIRM" ]; then
            break
        else
            log_error "Root passwords do not match. Please try again."
        fi
    done

    log_debug "Changing root password..."
    echo "root:$ROOT_PASSWORD" | chpasswd
    log_success "Root password changed successfully"
}

# Create new users
create_users() {
    while true; do
        #### Username & password setup ####
        read -p "Enter the username of new user: " USERNAME

        while true; do
            read -s -p "Enter password for the new user ($USERNAME): " PASSWORD
            echo ""
            read -s -p "Confirm password for the new user ($USERNAME): " PASSWORD_CONFIRM
            echo ""
            if [ "$PASSWORD" == "$PASSWORD_CONFIRM" ]; then
                break
            else
                log_error "Passwords do not match. Please try again."
            fi
        done

        log_debug "Creating $USERNAME..."
        useradd -m -s /bin/bash $USERNAME
        echo "$USERNAME:$PASSWORD" | chpasswd
        log_success "User $USERNAME created successfully"
        
        # Add to created users array
        CREATED_USERS+=("$USERNAME")

        #### Sudo setup ####
        if ask_yes_no "Add user $USERNAME to sudo group?"; then
            log_debug "Adding $USERNAME to the sudo group..."
            usermod -aG sudo $USERNAME
            log_success "$USERNAME added to sudo group"
            # Add to sudo users array
            SUDO_USERS+=("$USERNAME")
        fi

        #### SSH key setup ####
        if ask_yes_no "Add an SSH key for user $USERNAME?"; then
            read -p "Enter the SSH public key for $USERNAME: " SSH_KEY

            log_debug "Setting up SSH key for $USERNAME..."
            su - $USERNAME -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
            su - $USERNAME -c "echo '$SSH_KEY' > ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
            log_success "SSH key added for $USERNAME"
        fi

        if ! ask_yes_no "Create one more user?"; then
            break
        fi
    done
}

# Configure SSH
configure_ssh() {
    # Get SSH port configuration
    read -p "Enter SSH port (default: 22): " SSH_PORT
    SSH_PORT=${SSH_PORT:-22}

    log_debug "Configuring SSH config (sshd_config)"
    sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
    sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

    log_debug "Restarting SSH service..."
    systemctl restart sshd
    log_success "SSH configuration completed on port $SSH_PORT"
}

# Configure UFW
configure_ufw() {
    log_debug "Install ufw package"
    apt install -y ufw
    log_success "UFW package installed"

    log_debug "Configuring UFW..."
    ufw allow $SSH_PORT/tcp       # Allow SSH on configured port
    log_success "UFW configured successfully (SSH port $SSH_PORT allowed)"

    log_info "UFW status:"
    ufw status

    log_warning "After finishing the system configuration, you can run UFW"
}

# Install other packages
install_packages() {
    log_debug "Install common packages"
    apt install -y vim wget ca-certificates tree
    log_success "Additional packages installed"
}

# Customization
setup_customization() {
    ### MOTD Setup ###
    if ask_yes_no "Do you want to set up a custom welcome message (MOTD)?"; then
        log_debug "Removing standard Debian MOTD files..."
        # Remove or disable default MOTD files
        rm -f /etc/motd
        rm -f /etc/update-motd.d/10-uname
        chmod -x /etc/update-motd.d/* 2>/dev/null || true
        log_success "Standard MOTD files removed"

        log_debug "Installing custom MOTD scripts..."
        # Install MOTD scripts from linux-utils repo
        bash -c "$(curl -fsSL $MOTD_INSTALL_URL)"
        log_success "Custom MOTD scripts installed successfully"
    else
        log_warning "MOTD setup skipped"
    fi
}

# Optional software installation
optional_software() {
    ### Main Optional Software Menu ###
    while true; do
        echo ""
        log_info "Available optional software:"

        # Show Docker status
        if is_docker_installed; then
            log_info "1. Docker (Container Runtime) [INSTALLED]"
        else
            log_info "1. Docker (Container Runtime)"
        fi

        # Show Remnanode status
        if is_remnanode_installed; then
            log_info "2. Remnanode [INSTALLED]"
        else
            log_info "2. Remnanode"
        fi

        log_info "3. Exit optional installations"
        echo ""

        read -p "Select option (1-3): " OPTION

        case $OPTION in
            1)
                # Check if Docker is already installed
                if is_docker_installed; then
                    log_warning "Docker is already installed"
                    continue
                fi

                if ask_yes_no "Install Docker?"; then
                    install_docker
                fi
                ;;
            2)
                # Check if Remnanode is already installed
                if is_remnanode_installed; then
                    log_warning "Remnanode is already installed"
                    continue
                fi

                # Check if Docker is installed
                if ! is_docker_installed; then
                    log_warning "Docker is not installed. Installing Docker first..."
                    install_docker
                fi

                install_remnanode
                ;;
            3)
                log_info "Exiting optional installations"
                break
                ;;
            *)
                log_warning "Invalid option. Please select 1-3."
                ;;
        esac
    done
}

# Docker Installation Function
install_docker() {
    log_debug "Installing Docker..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt update

    # Install docker with compose
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    log_success "Docker installed successfully"

    ### Add users to docker group ###
    if [ ${#SUDO_USERS[@]} -gt 0 ]; then
        log_info "Available sudo users to add to docker group:"
        for user in "${SUDO_USERS[@]}"; do
            log_info "- $user"
        done
        echo ""

        while true; do
            read -p "Enter the username to add to docker group (or '0' to skip): " DOCKER_USER

            if [[ "$DOCKER_USER" == "0" ]]; then
                log_warning "Skipping docker group assignment"
                break
            elif [[ " ${SUDO_USERS[*]} " =~ " ${DOCKER_USER} " ]]; then
                log_debug "Adding $DOCKER_USER to docker group..."
                usermod -aG docker $DOCKER_USER
                log_success "$DOCKER_USER added to docker group"
                break
            else
                log_error "User $DOCKER_USER is not in the sudo users list!"
                log_warning "Please select a user from the available sudo users list above, or type '0' to skip."
            fi
        done
    else
        log_warning "No sudo users available to add to docker group"
    fi
}

# Remnanode Installation Function
install_remnanode() {
    log_info "Configuring Remnanode..."

    mkdir -p "$REMNA_DIR"
    
    # Get version configuration
    read -p "Enter the Remnanode version to install (default: latest): " REMNA_VERSION
    REMNA_VERSION=${REMNA_VERSION:-latest}
    log_info "Installing Remnanode version: $REMNA_VERSION"

    # Get port configuration
    read -p "Enter the port for Remnanode (default: 5777): " REMNA_PORT
    REMNA_PORT=${REMNA_PORT:-5777}

    # Get secret key
    log_info "Enter the Secret key (copy from main panel):"

    while true; do
        read -p "Secret key: " SECRET_KEY_INPUT

        # Check if input starts with SECRET_KEY= and remove it
        if [[ "$SECRET_KEY_INPUT" =~ ^SECRET_KEY= ]]; then
            # Remove SECRET_KEY= prefix and quotes if present
            SECRET_KEY="${SECRET_KEY_INPUT#SECRET_KEY=}"
            SECRET_KEY="${SECRET_KEY%\"}"  # Remove trailing quote
            SECRET_KEY="${SECRET_KEY#\"}"  # Remove leading quote
            log_debug "Cleaned SECRET_KEY input"
        else
            SECRET_KEY="$SECRET_KEY_INPUT"
        fi

        # Validate that we have some content
        if [[ -n "$SECRET_KEY" ]]; then
            break
        else
            log_error "Secret key cannot be empty. Please provide a valid certificate."
        fi
    done

    # Create .env file
    log_debug "Creating environment configuration..."
    cat > "$REMNA_DIR/.env" << EOF
NODE_PORT=$REMNA_PORT
SECRET_KEY="$SECRET_KEY"
EOF

    # Create docker-compose.yml file
    log_debug "Creating docker-compose.yml file..."
    cat > "$REMNA_DIR/docker-compose.yml" << EOF
services:
  remnanode:
    container_name: remnanode
    hostname: remnanode
    image: remnawave/node:$REMNA_VERSION
    restart: always
    network_mode: host
    env_file:
      - .env
EOF

    # Set proper permissions
    chmod 600 "$REMNA_DIR/.env"

    log_success "Docker Compose configuration created at $REMNA_DIR"

    ### Start the container ###
    log_debug "Starting Remnanode container..."
    cd "$REMNA_DIR"
    docker compose up -d
    log_success "Remnanode container started successfully"

    ### Configure firewall for Remnanode port ###
    if command -v ufw &> /dev/null; then
        log_debug "Configuring firewall for Remnanode port $REMNA_PORT..."
        ufw allow $REMNA_PORT
        log_success "UFW rule added for Remnanode port $REMNA_PORT"

        ### Additional ports configuration ###
        log_info "Do you want to open additional ports for this service? (like 443/tcp)"
        configure_additional_ports
    else
        log_warning "UFW is not installed. Skipping firewall configuration."
        log_info "To configure firewall later, install UFW and run: sudo ufw allow $REMNA_PORT"
    fi

    ### Service status ###
    log_debug "Checking container status..."
    docker ps | grep remnanode

    log_success "Remnanode installation completed!"
    log_success "Service is running on port $REMNA_PORT"
    log_info "You can stop the service with: docker compose -f $REMNA_DIR/docker-compose.yml down"
    log_info "You can start the service with: docker compose -f $REMNA_DIR/docker-compose.yml up -d"
}

# Show main menu
show_main_menu() {
    echo -e "${GREEN}>----- SETUP OS -----<${RESET}"
    echo ""
    log_info "Select how you want to run the setup:"
    log_info "1. Full setup (run all steps)"
    log_info "2. Run specific steps independently"
    echo ""
    log_info "Ctrl+C for exit"
    echo ""

    while true; do
        read -p "Select option (1-2): " SETUP_MODE

        case $SETUP_MODE in
            1)
                log_info "Running full setup..."
                echo ""
                return 0
                ;;
            2)
                log_info "Entering interactive mode..."
                echo ""
                return 1
                ;;
            *)
                log_warning "Invalid option. Please select 1 or 2."
                ;;
        esac
    done
}

# Show interactive step menu
show_interactive_menu() {
    while true; do
        echo ""
        echo -e "${GREEN}>----- AVAILABLE INDEPENDENT STEPS -----<${RESET}"
        log_info "1. System update & install necessary packages"
        log_info "2. Change the hostname"
        log_info "3. Change root password"
        log_info "4. Create new users"
        log_info "5. Install other packages"
        log_info "6. Customization (MOTD)"
        log_info "7. Optional Software Installation (Docker, Remnanode)"
        echo ""
        log_info "q. Exit and finish setup"
        echo ""

        read -p "Select step (1-7 or q to exit): " STEP_CHOICE

        case $STEP_CHOICE in
            1)
                log_info "STEP 1: System update & install necessary packages"
                system_update
                ;;
            2)
                log_info "STEP 2: Change the hostname"
                change_hostname
                ;;
            3)
                log_info "STEP 3: Change root password"
                change_root_password
                ;;
            4)
                log_info "STEP 4: Create new users"
                create_users
                ;;
            5)
                log_info "STEP 5: Install other packages"
                install_packages
                ;;
            6)
                log_info "STEP 6: Customization"
                setup_customization
                ;;
            7)
                log_info "STEP 7: Optional Software Installation"
                optional_software
                ;;
            q|Q)
                log_info "Exiting interactive mode..."
                break
                ;;
            *)
                log_warning "Invalid option. Please select 1-7 or q to exit."
                ;;
        esac
    done
}

# Final setup
enable_ufw() {
    echo -e "${GREEN}>----- SETUP COMPLETE -----<${RESET}"

    if ask_yes_no "Do you want to enable UFW now?" "y"; then
        log_debug "Enabling UFW..."
        ufw --force enable
        log_success "UFW enabled successfully"
        ufw status
    else
        log_warning "UFW not enabled. You can enable it later with: sudo ufw enable"
    fi
}

# Run full setup (all steps in sequence)
run_full_setup() {
    # STEP 1: System update & install necessary packages
    log_info "STEP 1: System update & install necessary packages"
    system_update

    # STEP 2: Change the hostname
    log_info "STEP 2: Change the hostname"
    change_hostname

    # STEP 3: Change root password
    log_info "STEP 3: Change root password"
    change_root_password

    # STEP 4: Create new users
    log_info "STEP 4: Create new users"
    create_users

    # STEP 5: Configure SSH
    log_info "STEP 5: Configure SSH"
    configure_ssh

    # STEP 6: Configure firewall (UFW)
    log_info "STEP 6: Configure firewall (UFW)"
    configure_ufw

    # STEP 7: Install other packages
    log_info "STEP 7: Install other packages"
    install_packages

    # STEP 8: Customization
    log_info "STEP 8: Customization"
    setup_customization

    # STEP 9: Optional Software Installation
    log_info "STEP 9: Optional Software Installation"
    optional_software

    # Final setup
    enable_ufw
}

# Main function
main() {
    # Check root privileges first
    check_root

    if show_main_menu; then
        run_full_setup
    else
        show_interactive_menu
    fi
}

main "$@"