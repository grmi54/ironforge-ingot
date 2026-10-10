#!/bin/bash
# SSH Setup Script
# Configures SSH server for security

set -e

echo "=== Setting up SSH ==="

# Backup original sshd_config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Configure SSH
cat > /etc/ssh/sshd_config <<EOF
# IronForge SSH Configuration

Port 22
AddressFamily any
ListenAddress 0.0.0.0

# Authentication
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

# Security
MaxAuthTries 3
LoginGraceTime 60
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# Session
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*

# Subsystem
Subsystem sftp /usr/lib/openssh/sftp-server

# Keep alive
ClientAliveInterval 60
ClientAliveCountMax 2
EOF

# Set proper permissions
chmod 644 /etc/ssh/sshd_config
chmod 600 /etc/ssh/ssh_host_*_key 2>/dev/null || true

# Restart SSH service
systemctl restart sshd || systemctl restart ssh || true

echo "=== SSH setup complete ==="
