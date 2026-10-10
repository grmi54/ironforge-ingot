# IronForge Ingot

Automated Ubuntu Server installation tool for bare-metal servers.

## Overview

IronForge Ingot creates bootable Ubuntu ISOs with embedded auto-installation configurations. Perfect for deploying multiple servers with consistent configurations.

## Features

- **Profile-based installation**: Choose from predefined profiles (base, server, dev-workstation, k8s-node)
- **Fully automated**: Zero-touch installation from USB
- **Post-install scripts**: Automatic setup of Docker, SSH, users, and more
- **Bare-metal focused**: Optimized for physical server deployment

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
│   └── k8s-node.yaml
├── scripts/            # Post-installation scripts
│   ├── setup-ssh.sh
│   ├── setup-docker.sh
│   └── setup-users.sh
├── tools/              # Build tools
│   └── build-iso.sh    # Main build script
├── templates/          # Autoinstall templates
│   ├── autoinstall.yaml.template
│   └── grub.cfg.template
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

## License

MIT

## Contributing

Contributions welcome! Please open an issue or PR.
