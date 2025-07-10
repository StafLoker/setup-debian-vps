#!/bin/bash

set -euo pipefail

# Color Definitions
readonly RED='\033[31m'
readonly YELLOW='\033[33m'
readonly GREEN='\033[32m'
readonly PURPLE='\033[36m'
readonly BLUE='\033[34m'
readonly RESET='\033[0m'

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

#######################
### Welcome message ###
#######################

echo -e "${GREEN}>----- SETUP -----<${RESET}"

#####################
### Update system ###
#####################

log_info "STEP 1"
log_info "System update & install necessary packages"

log_debug "Start updating system"
apt update && apt upgrade -y
apt full-upgrade
apt autoremove
log_success "System update completed"

log_debug "Install sudo package"
apt install -y sudo
log_success "Sudo package installed"

#######################
### Change hostname ###
#######################

log_info "STEP 2"
log_info "Change the hostname"

read -p "Enter the new hostname [blank to skip]: " NEW_HOSTNAME

if [ -n "$NEW_HOSTNAME" ]; then
    log_debug "Changing the hostname to $NEW_HOSTNAME"
    hostnamectl set-hostname "$NEW_HOSTNAME"
    echo "127.0.1.1    $NEW_HOSTNAME" >> /etc/hosts
    log_success "Hostname changed to $NEW_HOSTNAME"
else
    log_warning "No hostname provided, skipping"
fi

############
### Root ###
############

log_info "STEP 3"
log_info "Change root password"

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

################
### New user ###
################

log_info "STEP 4"
log_info "Create new users"

CREATED_USERS=()
SUDO_USERS=()

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

###########
### SSH ###
###########

log_info "STEP 5"
log_info "Configure SSH"

# Get SSH port configuration
read -p "Enter SSH port (default: 403): " SSH_PORT
SSH_PORT=${SSH_PORT:-403}

log_debug "Configuring SSH config (sshd_config)"
sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

log_debug "Restarting SSH service..."
systemctl restart sshd
log_success "SSH configuration completed on port $SSH_PORT"

###########
### UFW ###
###########

log_info "STEP 6"
log_info "Configure firewall (UFW)"

INSTALLED_UFW=0

if ask_yes_no "Do you want to install and configure UFW?" "y"; then
    INSTALLED_UFW=1
    log_debug "Install ufw package"
    apt install -y ufw
    log_success "UFW package installed"

    log_debug "Configuring UFW..."
    ufw allow $SSH_PORT/tcp       # Allow SSH on configured port
    log_success "UFW configured successfully (SSH port $SSH_PORT allowed)"

    log_info "UFW status:"
    ufw status

    log_warning "After finishing the system configuration, you can run UFW"
else
    log_warning "UFW installation and configuration skipped"
fi

##############################
### Install other packages ###
##############################

log_info "STEP 7"
log_info "Install other packages"

log_debug "Install curl, wget, vim packages"
apt install -y curl wget vim
log_success "Additional packages installed"

#####################
### Customization ###
#####################

log_info "STEP 8"
log_info "Customization"

### MOTD Setup ###
###################

if ask_yes_no "Do you want to set up a custom welcome message (MOTD)?"; then
    log_debug "Creating custom MOTD script..."

    cat << EOF > /etc/update-motd.d/99-custom-message
#!/bin/bash
echo "Welcome to $(hostname), today is: $(date)"
echo "Server IP: $(hostname -I)"
echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')%"
echo "Ram Usage: $(free -m | grep Mem | awk '{print $3 "/" $2}') MB"
echo "Disk Usage (/): $(df -h / | awk 'NR==2 {print $5}')"
echo
echo "Last connections:"
last -a | head -n 5
echo
EOF

    chmod +x /etc/update-motd.d/99-custom-message
    log_success "Custom MOTD set up successfully"
else
    log_warning "MOTD setup skipped"
fi

#####################
### Podman & Remnanode ###
#####################

log_info "STEP 9"
log_info "Podman & Remnanode Installation"

### Podman Installation ###
############################

if ask_yes_no "Do you want to install Podman and Remnanode?"; then
    log_debug "Installing Podman..."
    apt-get update
    apt-get -y install podman
    log_success "Podman installed successfully"

    ### User Selection ###
    ######################

    log_info "Available sudo users for Remnanode installation:"
    if [ ${#SUDO_USERS[@]} -eq 0 ]; then
        log_error "No sudo users available. Remnanode requires a sudo user."
        log_warning "Skipping Remnanode installation."
    else
        # Print available sudo users
        for user in "${SUDO_USERS[@]}"; do
            log_info "- $user"
        done
        echo ""
        
        # Loop until valid user is selected
        while true; do
            read -p "Enter the username to install Remnanode for: " REMNA_USER
            
            # Check if user exists and is in SUDO_USERS array
            if [[ " ${SUDO_USERS[*]} " =~ " ${REMNA_USER} " ]]; then
                log_success "User $REMNA_USER selected for Remnanode installation"
                break
            else
                log_error "User $REMNA_USER is not in the sudo users list or does not exist!"
                log_warning "Please select a user from the available sudo users list above."
            fi
        done

        ### Remnanode Configuration ###
        ###############################

        log_info "Configuring Remnanode for user $REMNA_USER..."

        # Create configuration directory
        mkdir -p /etc/remnanode
        
        # Get port configuration
        read -p "Enter the port for Remnanode (default: 5777): " REMNA_PORT
        REMNA_PORT=${REMNA_PORT:-5777}

        # Get SSL certificate
        log_info "Enter the SSL certificate (copy from main panel):"
        log_info "Format: SSL_CERT=\"CERT_FROM_MAIN_PANEL\""
        
        while true; do
            read -p "SSL Certificate: " SSL_CERT_INPUT
            
            # Check if input starts with SSL_CERT= and remove it
            if [[ "$SSL_CERT_INPUT" =~ ^SSL_CERT= ]]; then
                # Remove SSL_CERT= prefix and quotes if present
                SSL_CERT="${SSL_CERT_INPUT#SSL_CERT=}"
                SSL_CERT="${SSL_CERT%\"}"  # Remove trailing quote
                SSL_CERT="${SSL_CERT#\"}"  # Remove leading quote
                log_debug "Cleaned SSL_CERT input"
            else
                SSL_CERT="$SSL_CERT_INPUT"
            fi
            
            # Validate that we have some content
            if [[ -n "$SSL_CERT" ]]; then
                break
            else
                log_error "SSL certificate cannot be empty. Please provide a valid certificate."
            fi
        done

        # Create .env file
        log_debug "Creating environment configuration..."
        tee /etc/remnanode/.env > /dev/null <<EOF
APP_PORT=$REMNA_PORT
SSL_CERT="$SSL_CERT"
EOF

        # Set proper permissions for the .env file
        chown $REMNA_USER:$REMNA_USER /etc/remnanode/.env
        chmod 600 /etc/remnanode/.env

        log_success "Environment file created at /etc/remnanode/.env"

        ### Firewall Configuration ###
        ###############################

        log_debug "Configuring firewall for port $REMNA_PORT..."
        ufw allow $REMNA_PORT
        log_success "UFW rule added for port $REMNA_PORT"

        ### Run Container and Generate Systemd ###
        ###########################################

        log_debug "Running Remnanode container..."
        sudo -u $REMNA_USER podman run \
            --name remnanode \
            --publish "$REMNA_PORT:$REMNA_PORT" \
            --env-file /etc/remnanode/.env \
            --detach \
            docker.io/remnawave/node:latest

        log_debug "Generating systemd service..."
        sudo -u $REMNA_USER podman generate systemd --new --files --name remnanode
        
        # Enable linger first
        log_debug "Enabling linger for user $REMNA_USER..."
        loginctl enable-linger $REMNA_USER
        log_success "Linger enabled - service will start automatically on boot"

        # Enable and start the user service
        log_debug "Enabling and starting Remnanode service..."
        sudo -u $REMNA_USER systemctl --user daemon-reload
        sudo -u $REMNA_USER systemctl --user enable container-remnanode
        sudo -u $REMNA_USER systemctl --user start container-remnanode

        log_debug "Checking service status..."
        sudo -u $REMNA_USER systemctl --user status container-remnanode --no-pager -l

        log_success "Remnanode installation completed!"
        log_success "Service is running on port $REMNA_PORT"
        log_info "You can check logs with: sudo -u $REMNA_USER journalctl --user -u container-remnanode -f"
    fi
else
    log_warning "Podman and Remnanode installation skipped."
fi

##########################
### Completion message ###
##########################

echo -e "${GREEN}>----- SETUP COMPLETE -----<${RESET}"

if [[ "$INSTALLED_UFW" -eq 1 ]]; then
    if ask_yes_no "Do you want to enable UFW now?" "y"; then
        log_debug "Enabling UFW..."
        ufw --force enable
        log_success "UFW enabled successfully"
        ufw status
    else
        log_warning "UFW not enabled. You can enable it later with: sudo ufw enable"
    fi
fi

if [[ "${INSTALL_PODMAN:-n}" =~ ^([yY][eE][sS]|[yY])$ ]] && [ ${#SUDO_USERS[@]} -gt 0 ] && [[ -n "${REMNA_USER:-}" ]]; then
    echo ""
    log_success "RemnaNode Information:"
    log_info "- Service: container-remnanode (user service)"
    log_info "- Port: $REMNA_PORT"
    log_info "- User: $REMNA_USER"
    log_info "- Config: /etc/remnanode/.env"
    log_debug "- Status: sudo -u $REMNA_USER systemctl --user status container-remnanode"
    log_debug "- Logs: sudo -u $REMNA_USER journalctl --user -u container-remnanode -f"
    echo ""
fi