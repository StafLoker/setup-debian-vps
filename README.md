<div align="center">
   <h1><b>Setup Script for Debian VPS</b></h1>
   <p><i>~ Automated server configuration ~</i></p>
   <p align="center">
       · <a href="https://github.com/StafLoker/setup-debian-vps/releases">Releases</a> ·
       <a href="https://github.com/StafLoker/setup-debian-vps/issues">Issues</a> ·
       <a href="https://github.com/StafLoker/setup-debian-vps/wiki">Wiki</a> ·
   </p>
</div>

<div align="center">
   <a href="https://github.com/StafLoker/setup-debian-vps/releases"><img src="https://img.shields.io/github/downloads/StafLoker/setup-debian-vps/total.svg?style=flat" alt="downloads"/></a>
   <a href="https://github.com/StafLoker/setup-debian-vps/releases"><img src="https://img.shields.io/github/release-pre/StafLoker/setup-debian-vps.svg?style=flat" alt="latest version"/></a>
   <a href="https://github.com/StafLoker/setup-debian-vps/blob/main/LICENSE"><img src="https://img.shields.io/github/license/StafLoker/setup-debian-vps.svg?style=flat" alt="license"/></a>
   <p>Comprehensive automated configuration script for fresh Debian VPS servers with security hardening, user management.</p>
</div>

## **Quick Execute**
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/StafLoker/setup-debian-vps/main/script.sh)"
```

## **Configuration Steps**
The script follows a specific order for optimal server configuration:

### **STEP 1 - System Update & Packages**
- System update and upgrade
- Install necessary packages:
  - sudo

### **STEP 2 - Change Hostname**
- Optional hostname configuration
- Updates `/etc/hosts` file

### **STEP 3 - Root Password**
- Secure root password setup
- Password confirmation validation

### **STEP 4 - User Management**
- Create new users with secure passwords
- Add users to sudo group (optional)
- SSH key configuration for users

### **STEP 5 - SSH Configuration**
- Change SSH port to custom one
- Disable root login
- Disable password authentication

### **STEP 6 - Firewall (UFW)**
- Install and configure UFW
- Allow SSH on custom port
- Optional activation at the end

### **STEP 7 - Additional Packages**
- Install essential tools:
  - curl
  - wget
  - vim

### **STEP 8 - Customization**
- Custom MOTD (Message of the Day) setup
- System information display

### **STEP 9 - Optional Services**
- **Podman & RemnaNode Installation**
  - Install Podman container runtime
  - Configure RemnaNode service
  - User-specific systemd service
  - Automatic startup configuration
  - Port publishing and firewall rules

## **License**
This project is open source and available under standard terms.