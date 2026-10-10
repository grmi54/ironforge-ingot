#!/bin/bash
# Users Setup Script
# Configures user accounts and sudo access

set -e

echo "=== Setting up users ==="

# Configure sudo
cat > /etc/sudoers.d/ironforge <<EOF
# IronForge sudo configuration
%sudo ALL=(ALL:ALL) ALL
admin ALL=(ALL) NOPASSWD:ALL
dev ALL=(ALL) NOPASSWD:ALL
EOF

chmod 440 /etc/sudoers.d/ironforge

# Configure bash defaults
cat > /etc/skel/.bashrc <<'EOF'
# ~/.bashrc - IronForge defaults

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# History settings
HISTCONTROL=ignoreboth
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend

# Check window size after each command
shopt -s checkwinsize

# Make less more friendly for non-text input files
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# Set prompt
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Enable color support
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Useful aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'

# Add local bin to PATH
export PATH="$HOME/.local/bin:$PATH"
EOF

# Create .ssh directory for users
for user in admin dev; do
    if id "$user" &>/dev/null; then
        user_home=$(eval echo "~$user")
        mkdir -p "$user_home/.ssh"
        chmod 700 "$user_home/.ssh"
        touch "$user_home/.ssh/authorized_keys"
        chmod 600 "$user_home/.ssh/authorized_keys"
        chown -R "$user:$user" "$user_home/.ssh"
    fi
done

echo "=== Users setup complete ==="
