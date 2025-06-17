# Setup script for Debian VPS server

Configuration includes [respect step order]:
- System update & install necessary packages
  - sudo
- Change hostname
- Change root password
- Create new users
  - Add user to sudo group
  - Add an SSH key for user
- Configure SSH
- Configure firewall (UFW)
- Install other packages
  - curl
- Customization
  - MOTD Setup
- Options
  - Install and configure 3X-UI
