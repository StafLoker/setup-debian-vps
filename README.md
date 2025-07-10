<div align="center">
   <h1><b>Setup Script for Debian VPS</b></h1>
   <p><i>~ Automated server configuration ~</i></p>
   <p align="center">
       · <a href="https://github.com/StafLoker/setup-debian-vps/releases">Releases</a> ·
   </p>
</div>

<div align="center">
   <a href="https://github.com/StafLoker/setup-debian-vps/releases"><img src="https://img.shields.io/github/downloads/StafLoker/setup-debian-vps/total.svg?style=flat" alt="downloads"/></a>
   <a href="https://github.com/StafLoker/setup-debian-vps/releases"><img src="https://img.shields.io/github/release-pre/StafLoker/setup-debian-vps.svg?style=flat" alt="latest version"/></a>
   <a href="https://github.com/StafLoker/setup-debian-vps/blob/main/LICENSE"><img src="https://img.shields.io/github/license/StafLoker/setup-debian-vps.svg?style=flat" alt="license"/></a>
   <p>Comprehensive automated configuration script for fresh Debian VPS servers with security hardening, user management, and optional services.</p>
</div>

## **Quick Execute**
```bash
apt install curl -y && bash -c "$(curl -fsSL https://raw.githubusercontent.com/StafLoker/setup-debian-vps/main/script.sh)"
```

## **Configuration Steps**
The script follows a modular approach with specific steps for optimal server configuration:

### **STEP 1 - System Update & Packages**
- Complete system update and upgrade
- Install essential packages:
  - sudo

### **STEP 2 - Change Hostname**
- Optional hostname configuration
- Automatic `/etc/hosts` file update

### **STEP 3 - Root Password**
- Secure root password setup
- Password confirmation validation

### **STEP 4 - User Management**
- Create multiple users with secure passwords
- Optional sudo group assignment
- SSH key configuration per user
- Support for multiple user creation

### **STEP 5 - SSH Configuration**
- Custom SSH port configuration (default: 403)
- Disable root login for security
- Disable password authentication (key-only access)
- Automatic SSH service restart

### **STEP 6 - Firewall (UFW)**
- **Automatic UFW installation** (no longer optional)
- Configure SSH port rules automatically
- UFW activation at setup completion

### **STEP 7 - Additional Packages**
- Install essential development and administration tools:
  - wget
  - vim

### **STEP 8 - Customization**
- Custom MOTD (Message of the Day) setup
- Real-time system information display:
  - Server hostname and date
  - IP address
  - CPU usage
  - RAM usage
  - Disk usage
  - Recent connection history

### **STEP 9 - Optional Software Installation**
Interactive menu-driven installation of containerization services:

#### **Available Options:**
1. **Docker** - Container runtime with compose
   - Official Docker Engine installation
   - Docker Compose plugin included
   - Complete container ecosystem
   - **Post-installation user setup**: Select sudo users to add to docker group
   
2. **Remnanode** - Container service management
   - **Requires Docker** (auto-installs if needed)
   - **System-wide installation** in `/opt/remnanode`
   - SSL certificate configuration
   - Custom port setup (default: 5777)
   - Docker Compose deployment
   - **Flexible port management**: Add additional ports with multiple formats:
     - `333` (default protocol)
     - `333/tcp` (TCP protocol)
     - `333/udp` (UDP protocol)
   - Automatic firewall rule configuration
   
3. **Exit** - Complete optional installations

## **Features**

### **Security Hardening**
- Disabled root SSH access
- Key-based authentication only
- Custom SSH ports
- Automatic firewall configuration
- Secure user management

### **User Experience**
- Interactive prompts with validation
- Colored logging system
- Clear progress indicators
- Comprehensive error handling

## **License**
This project is open source and available under standard terms.
