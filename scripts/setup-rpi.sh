#!/bin/bash
# Raspberry Pi Optimization Script - IronForge Ingot
# Post-install script for RPi-specific optimizations

set -e

echo "=== Setting up Raspberry Pi optimizations ==="

# 1. CPU Governor (performance mode for server)
if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
    echo "performance" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
    echo "CPU governor set to performance"
fi

# 2. ZRAM configuration (compressed swap to preserve SD card)
if [ -f /etc/default/zramswap ]; then
    cat > /etc/default/zramswap <<EOF
# IronForge ZRAM Configuration
ALGO=lz4
PERCENT=50
EOF
    systemctl enable zramswap
    systemctl start zramswap
    echo "ZRAM configured and enabled"
fi

# 3. tmpfs for logs (reduces SD card writes)
if ! grep -q "/var/log" /etc/fstab; then
    echo "tmpfs /var/log tmpfs defaults,noatime,size=50M 0 0" >> /etc/fstab
    echo "tmpfs configured for /var/log"
fi

# 4. Reduce SD card wear
# Add noatime to mount options if not already present
sed -i 's/defaults,/defaults,noatime,/g' /etc/fstab

# 5. Configure UFW firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
echo "UFW firewall configured and enabled"

# 6. Configure sysctl parameters
cat > /etc/sysctl.d/99-ironforge.conf <<EOF
# IronForge sysctl configuration
vm.swappiness=10
vm.vfs_cache_pressure=50
net.core.netdev_max_backlog=5000
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=65535
EOF
sysctl --system
echo "sysctl parameters configured"

echo "=== Raspberry Pi optimizations complete ==="
