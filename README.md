# IronForge Ingot

Automated Ubuntu Server installation tool for bare-metal servers.

## Overview

IronForge Ingot creates bootable Ubuntu ISOs with embedded auto-installation configurations. Perfect for deploying multiple servers with consistent configurations.

## Features

- **Profile-based installation**: Choose from predefined profiles (base, server, dev-workstation, k8s-node, rpi-server)
- **Fully automated**: Zero-touch installation from USB or SD card
- **Post-install scripts**: Automatic setup of SSH, users, and more
- **Bare-metal focused**: Optimized for physical server deployment
- **Raspberry Pi support**: Dedicated image builder for RPi 5 with cloud-init

## Quick Start

### Prerequisites

- Linux system with root access
- `xorriso`, `curl`, `wget` installed
- Ubuntu Server ISO (will be downloaded automatically if not present)

### Build an ISO

```bash
# Build with server profile
./tools/build-iso.sh --profile server

# Build with custom profile
./tools/build-iso.sh --profile my-custom-profile

# Specify Ubuntu version
./tools/build-iso.sh --profile server --ubuntu-version 24.04
```

### Create Bootable USB

```bash
# Find your USB device
lsblk

# Write ISO to USB (WARNING: This will erase the device)
sudo dd if=build/ubuntu-custom.iso of=/dev/sdX status=progress
```

### Install Server

1. Boot the target server from USB
2. Installation starts automatically (no intervention needed)
3. Server reboots with configured Ubuntu
4. Remove USB and SSH into the server

## Project Structure

```
ironforge-ingot/
├── profiles/           # Installation profiles (YAML)
│   ├── base.yaml       # Minimal installation
│   ├── server.yaml     # Production server
│   ├── dev-workstation.yaml
│   ├── k8s-node.yaml
│   └── rpi-server.yaml # Raspberry Pi 5 server
├── scripts/            # Post-installation scripts
│   ├── setup-ssh.sh
│   ├── setup-docker.sh
│   ├── setup-users.sh
│   └── setup-rpi.sh    # RPi-specific optimizations
├── tools/              # Build tools
│   ├── build-iso.sh    # Main build script (x86_64)
│   └── build-rpi-img.sh # Raspberry Pi image builder
├── templates/          # Autoinstall templates
│   ├── autoinstall.yaml.template
│   ├── grub.cfg.template
│   ├── rpi-user-data.template  # RPi cloud-init user-data
│   └── rpi-meta-data.template  # RPi cloud-init meta-data
├── build/              # Build output (gitignored)
└── README.md
```

## Profiles

### base
Minimal Ubuntu installation with essential packages only.

### server
Production server with Docker, monitoring tools, and security hardening.

### dev-workstation
Development environment with common tools and utilities.

### k8s-node
Kubernetes node with container runtime and networking tools.

### rpi-server
Raspberry Pi 5 server with SD card optimizations (zram, tmpfs, CPU governor). No Docker by default - use Ansible for application deployment.

## Raspberry Pi

### Prerequisites

- Linux system with root access
- `curl`, `xz`, `parted`, `losetup`, `python3`, `python3-yaml` installed
- ~5GB free disk space for image download and build
- SD card reader for flashing

### Install Dependencies

```bash
sudo apt-get update
sudo apt-get install -y curl xz-utils parted mount python3 python3-yaml python3-jinja2
```

### Build RPi Image

```bash
# Build with rpi-server profile
./tools/build-rpi-img.sh --profile rpi-server

# Specify Ubuntu version (default: 24.04)
./tools/build-rpi-img.sh --profile rpi-server --ubuntu-version 24.04

# Custom output path
./tools/build-rpi-img.sh --profile rpi-server --output build/my-rpi-server.img
```

The build process:
1. Downloads Ubuntu 24.04 ARM64 preinstalled image for RPi (~3GB)
2. Decompresses the `.img.xz` file
3. Mounts the boot partition (FAT32)
4. Generates cloud-init configuration from profile
5. Injects `user-data` and `meta-data` into boot partition
6. Unmounts and produces `build/rpi-ubuntu-server.img`

### Flash to SD Card

```bash
# 1. Insert SD card into your computer

# 2. Find the SD card device
lsblk
# Look for your SD card (e.g., /dev/sdb, /dev/mmcblk0)
# WARNING: Make sure you select the correct device!

# 3. Flash the image (WARNING: This will erase the SD card)
sudo dd if=build/rpi-ubuntu-server.img of=/dev/sdX status=progress
# Replace /dev/sdX with your actual SD card device

# 4. Sync and safely remove
sync
```

### First Boot

1. Insert the SD card into your Raspberry Pi 5
2. Connect ethernet cable (or use WiFi if configured)
3. Power on the Raspberry Pi
4. Wait 2-3 minutes for first-boot cloud-init configuration
5. Find the IP address:
   - Check your router's DHCP leases
   - Or use: `nmap -sn 192.168.1.0/24` (adjust subnet)
   - Or connect monitor/keyboard to RPi
6. SSH into the server:
   ```bash
   ssh admin@<rpi-ip-address>
   ```

### Default Credentials

- **Username**: `admin`
- **Password**: Set in profile (default: `hashedpassword` - change immediately!)

**Important**: Change the default password on first login:
```bash
passwd
```

### Reproducible Builds

To reproduce the exact same image:

```bash
# Tag the current version
git tag v1.0-rpi
git push origin v1.0-rpi

# Later, rebuild from the tag
git checkout v1.0-rpi
./tools/build-rpi-img.sh --profile rpi-server
```

The build is deterministic: same profile + same Ubuntu version = same image.

### Customizing RPi Profile

Edit `profiles/rpi-server.yaml` to customize:

```yaml
# Change hostname
hostname: my-rpi-server

# Add SSH keys for passwordless login
users:
  - username: admin
    ssh_authorized_keys:
      - ssh-rsa AAAA...

# Add packages
packages:
  - curl
  - git
  - vim
  # Add your packages here

# RPi-specific options
rpi:
  cpu_governor: performance  # or powersave
  enable_zram: true
  zram_fraction: 0.5         # 50% of RAM
  tmpfs_logs: true           # Reduce SD writes
  wifi_enabled: true
  bluetooth_enabled: true
```

## Creating Custom Profiles

Create a new YAML file in `profiles/`:

```yaml
hostname: my-server
locale: en_US
keyboard: us
timezone: UTC

storage:
  layout: lvm

users:
  - username: admin
    ssh_authorized_keys:
      - ssh-rsa AAAA...

packages:
  - curl
  - git

post_install_scripts:
  - setup-ssh.sh
```

## Roadmap

- [ ] PXE boot support
- [ ] Web UI for profile management
- [ ] Hardware detection and customization
- [ ] Encrypted storage support
- [ ] RAID configuration
- [ ] Raspberry Pi 4 support
- [ ] WiFi AP mode for headless RPi setup

## License

MIT

## Contributing

Contributions welcome! Please open an issue or PR.
