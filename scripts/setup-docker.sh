#!/bin/bash
# Docker Setup Script
# Configures Docker daemon and adds user to docker group

set -e

echo "=== Setting up Docker ==="

# Create docker daemon configuration
mkdir -p /etc/docker

cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "live-restore": true,
  "default-address-pools": [
    {
      "base": "172.17.0.0/12",
      "size": 24
    }
  ]
}
EOF

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Add current user to docker group
if [ -n "$SUDO_USER" ]; then
    usermod -aG docker "$SUDO_USER"
fi

# Add admin user to docker group if exists
if id "admin" &>/dev/null; then
    usermod -aG docker admin
fi

# Add dev user to docker group if exists
if id "dev" &>/dev/null; then
    usermod -aG docker dev
fi

# Install Docker Compose (latest stable)
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Verify installation
docker --version
docker-compose --version

echo "=== Docker setup complete ==="
