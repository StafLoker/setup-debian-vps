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
echo " -- Done"

echo " -- Install sudo package"
apt install -y sudo
echo " -- Done"

############
### Root ###
############

echo ">>>>> STEP 2 <<<<<"
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

echo ">>>>> STEP 3 <<<<<"
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

echo ">>>>> STEP 4 <<<<<"
echo " - Configure SSH"

read -p " -- Enter the SSH public key to add for $USERNAME: " SSH_KEY

echo " -- Setting up SSH key for $USERNAME..."
su - $USERNAME -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
su - $USERNAME -c "echo '$SSH_KEY' > ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
echo " -- Done"

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

echo ">>>>> STEP 5 <<<<<"
echo " - Configure firewall (UFW)"

read -p " -- Do you want to install and configure UFW? [yes/no]: " INSTALL_UFW
INSTALLED_UFW = 0

if [[ "$INSTALL_UFW" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    INSTALLED_UFW = 1
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

echo ">>>>> STEP 6 <<<<<"
echo " - Install other packages"

echo " -- Install curl package"
apt install -y curl
echo " -- Done"

###############
### Options ###
###############

### Install 3X-UI (XRAY Web manager)  ###
#########################################

read -p " -- Do you want to install and configure 3X-UI? [yes/no]" INSTALL_3X_UI

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