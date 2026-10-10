#!/bin/bash
# Development Tools Setup Script
# Installs common development tools and utilities

set -e

echo "=== Setting up development tools ==="

# Install Zsh if requested
if command -v apt-get &> /dev/null; then
    apt-get install -y zsh || true
fi

# Install Oh My Zsh for users
for user in admin dev; do
    if id "$user" &>/dev/null; then
        user_home=$(eval echo "~$user")
        
        # Install Oh My Zsh
        if [ ! -d "$user_home/.oh-my-zsh" ]; then
            sudo -u "$user" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true
        fi
        
        # Set Zsh as default shell
        chsh -s /bin/zsh "$user" || true
    fi
done

# Install Rust for users
for user in admin dev; do
    if id "$user" &>/dev/null; then
        user_home=$(eval echo "~$user")
        sudo -u "$user" curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sudo -u "$user" sh -s -- -y || true
    fi
done

# Install Node.js (latest LTS)
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt-get install -y nodejs
fi

# Install common npm packages globally
npm install -g yarn pnpm || true

# Install Python tools
pip3 install --upgrade pip || true
pip3 install poetry black flake8 pytest || true

# Install Go (if not present)
if ! command -v go &> /dev/null; then
    GO_VERSION="1.22.0"
    wget -q https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
    tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
    rm go${GO_VERSION}.linux-amd64.tar.gz
    
    # Add Go to PATH for all users
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile.d/go.sh
fi

# Install VS Code (if not present)
if ! command -v code &> /dev/null; then
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
    install -D -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
    rm /tmp/packages.microsoft.gpg
    
    apt-get update
    apt-get install -y code
fi

# Install Docker Compose completion
if [ -f /usr/local/bin/docker-compose ]; then
    curl -L "https://raw.githubusercontent.com/docker/compose/$(docker-compose version --short)/contrib/completion/bash/docker-compose" -o /etc/bash_completion.d/docker-compose
fi

# Install kubectl completion
if command -v kubectl &> /dev/null; then
    kubectl completion bash > /etc/bash_completion.d/kubectl
fi

echo "=== Development tools setup complete ==="
