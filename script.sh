#!/bin/bash

#######################
### Welcome message ###
#######################

echo ">----- SETUP -----<"

#####################
### Update system ###
#####################

echo ">>>>> STEP 1 <<<<<"
echo " - System update & install necessary packages"

echo " -- Start updating system"
apt update && apt upgrade -y
apt full-upgrade
apt autoremove
echo " -- Done"

echo " -- Install sudo package"
apt install -y sudo
echo " -- Done"

#######################
### Change hostname ###
#######################

echo ">>>>> STEP 2 <<<<<"
echo " - Change the hostname"

read -p " -- Enter the new hostname [blank to skip]: " NEW_HOSTNAME

if [ -n "$NEW_HOSTNAME" ]; then
    echo " -- Changing the hostname to $NEW_HOSTNAME"
    hostnamectl set-hostname "$NEW_HOSTNAME"
    echo "127.0.1.1    $NEW_HOSTNAME" >> /etc/hosts
    echo " -- Done"
else
    echo " -- No hostname provided, skipping."
fi

############
### Root ###
############

echo ">>>>> STEP 3 <<<<<"
echo " - Change root password"

while true; do
    read -s -p " -- Enter new root password: " ROOT_PASSWORD
    echo ""
    read -s -p " -- Confirm new root password: " ROOT_PASSWORD_CONFIRM
    echo ""
    if [ "$ROOT_PASSWORD" == "$ROOT_PASSWORD_CONFIRM" ]; then
        break
    else
        echo " -- Root passwords do not match. Please try again."
    fi
done

echo " -- Changing root password..."
echo "root:$ROOT_PASSWORD" | chpasswd

################
### New user ###
################

echo ">>>>> STEP 4 <<<<<"
echo " - Create new users"

while true; do

    #### Username & password setup ####

    read -p " -- Enter the username of new user: " USERNAME

    while true; do
        read -s -p " -- Enter password for the new user ($USERNAME): " PASSWORD
        echo ""
        read -s -p " -- Confirm password for the new user ($USERNAME): " PASSWORD_CONFIRM
        echo ""
        if [ "$PASSWORD" == "$PASSWORD_CONFIRM" ]; then
            break
        else
            echo " -- Passwords do not match. Please try again."
        fi
    done

    echo " -- Creating $USERNAME..."
    useradd -m -s /bin/bash $USERNAME
    echo "$USERNAME:$PASSWORD" | chpasswd
    echo " -- Done"

    #### Sudo setup ####

    read -p " -- Add user $USERNAME to sudo group? [yes/no]: " USER_ADD_SUDO

    if [[ "$USER_ADD_SUDO" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo " -- Adding $USERNAME to the sudo group..."
        usermod -aG sudo $USERNAME
        echo " -- Done"
    fi

    #### SSH key setup ####

    read -p " -- Add an SSH key for user $USERNAME? [yes/no]: " ADD_SSH_KEY

    if [[ "$ADD_SSH_KEY" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        read -p " -- Enter the SSH public key for $USERNAME: " SSH_KEY

        echo " -- Setting up SSH key for $USERNAME..."
        su - $USERNAME -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
        su - $USERNAME -c "echo '$SSH_KEY' > ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
        echo " -- SSH key added for $USERNAME."
    fi

    read -p " -- Create one more user? [yes/no]: " CREATE_MORE_USER

    if [[ ! "$CREATE_MORE_USER" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        break
    fi
done

###########
### SSH ###
###########

echo ">>>>> STEP 5 <<<<<"
echo " - Configure SSH"

echo " -- Configuring SSH config (sshd_config)"
sed -i 's/#Port 22/Port 403/' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

echo " -- Restarting SSH service..."
systemctl restart sshd
echo " -- Done"

###########
### UFW ###
###########

echo ">>>>> STEP 6 <<<<<"
echo " - Configure firewall (UFW)"

read -p " -- Do you want to install and configure UFW? [yes/no]: " INSTALL_UFW
INSTALLED_UFW=0

if [[ "$INSTALL_UFW" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    INSTALLED_UFW=1
    echo " -- Install ufw package"
    apt install -y ufw
    echo " -- Done"

    echo " -- Configuring UFW..."
    ufw allow 403/tcp       # Allow SSH on port 403
    ufw allow 443/tcp       # Allow HTTPS (TLS) on port 443
    echo " -- Done"

    echo " -- Results"
    ufw status

    echo " -- After finishing the system configuration, you can run UFW"
else
    echo " -- UFW installation and configuration skipped."
fi

##############################
### Install other packages ###
##############################

echo ">>>>> STEP 7 <<<<<"
echo " - Install other packages"

echo " -- Install curl package"
apt install -y curl wget vim
echo " -- Done"

#####################
### Customization ###
#####################

echo ">>>>> STEP 8 <<<<<"
echo " - Customization"

### MOTD Setup ###
###################

read -p " -- Do you want to set up a custom welcome message (MOTD)? [yes/no]: " SETUP_MOTD

if [[ "$SETUP_MOTD" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo " -- Creating custom MOTD script..."

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
    echo " -- Custom MOTD set up successfully."
else
    echo " -- MOTD setup skipped."
fi

###############
### Options ###
###############

echo ">>>>> STEP 9 <<<<<"
echo " - Options"

### Install 3X-UI (XRAY Web manager)  ###
#########################################

read -p " -- Do you want to install and configure 3X-UI? [yes/no]: " INSTALL_3X_UI

if [[ "$INSTALL_3X_UI" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo " -- Install 3X-UI package"
    bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
    echo " -- Done"

    if [ $INSTALLED_UFW -eq 1 ]; then
        read -p " -- Add web panel port to UFW rule (allow), enter port: " WEB_PANEL_PORT
        
        if [ -n "$WEB_PANEL_PORT" ]; then
            ufw allow "$WEB_PANEL_PORT/tcp"
            echo " -- Port $WEB_PANEL_PORT added to UFW rules (TCP)"
        else
            echo " -- No port entered. Skipping UFW rule addition."
        fi
    fi

else
    echo " -- 3X-UI installation and configuration skipped."
fi

##########################
### Completion message ###
##########################

echo ">----- SETUP COMPLETE -----<"