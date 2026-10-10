#!/bin/bash
# IronForge Ingot - Build Custom Ubuntu ISO
# Usage: ./build-iso.sh --profile <profile> [--ubuntu-version <version>]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
UBUNTU_VERSION="24.04"
PROFILE=""
BUILD_DIR="${PROJECT_DIR}/build"
ISO_DIR="${BUILD_DIR}/iso"
EXTRACT_DIR="${BUILD_DIR}/extract"
OUTPUT_ISO="${BUILD_DIR}/ubuntu-custom.iso"

# Ubuntu ISO URLs
UBUNTU_ISO_URL="https://releases.ubuntu.com/${UBUNTU_VERSION}/ubuntu-${UBUNTU_VERSION}-live-server-amd64.iso"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Build a custom Ubuntu ISO with auto-installation.

Options:
    --profile <name>          Profile to use (required)
    --ubuntu-version <ver>    Ubuntu version (default: ${UBUNTU_VERSION})
    --output <path>           Output ISO path (default: ${OUTPUT_ISO})
    --help                    Show this help message

Available profiles:
EOF
    ls -1 "${PROJECT_DIR}/profiles/" | sed 's/.yaml$//' | sed 's/^/    - /'
    echo ""
    exit 0
}

check_dependencies() {
    log_info "Checking dependencies..."
    
    local deps=(xorriso curl wget)
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_error "Install with: sudo apt-get install ${missing[*]}"
        exit 1
    fi
    
    log_info "All dependencies satisfied"
}

download_ubuntu_iso() {
    local iso_path="${BUILD_DIR}/ubuntu-${UBUNTU_VERSION}-live-server-amd64.iso"
    
    if [ -f "$iso_path" ]; then
        log_info "Ubuntu ISO already downloaded: $iso_path"
        echo "$iso_path"
        return
    fi
    
    log_info "Downloading Ubuntu ${UBUNTU_VERSION} ISO..."
    log_info "URL: ${UBUNTU_ISO_URL}"
    
    mkdir -p "$BUILD_DIR"
    curl -L "$UBUNTU_ISO_URL" -o "$iso_path"
    
    log_info "Download complete: $iso_path"
    echo "$iso_path"
}

extract_iso() {
    local source_iso="$1"
    
    if [ -d "$EXTRACT_DIR" ]; then
        log_info "Cleaning previous extraction..."
        rm -rf "$EXTRACT_DIR"
    fi
    
    log_info "Extracting ISO..."
    mkdir -p "$EXTRACT_DIR"
    
    # Extract ISO using xorriso
    xorriso -osirrox on -indev "$source_iso" -extract / "$EXTRACT_DIR"
    
    log_info "Extraction complete"
}

generate_autoinstall_config() {
    local profile="$1"
    local profile_path="${PROJECT_DIR}/profiles/${profile}.yaml"
    local template_path="${PROJECT_DIR}/templates/autoinstall.yaml.template"
    local output_path="${EXTRACT_DIR}/nocloud/autoinstall.yaml"
    
    if [ ! -f "$profile_path" ]; then
        log_error "Profile not found: $profile_path"
        exit 1
    fi
    
    if [ ! -f "$template_path" ]; then
        log_error "Template not found: $template_path"
        exit 1
    fi
    
    log_info "Generating autoinstall configuration for profile: $profile"
    
    # Create nocloud directory
    mkdir -p "${EXTRACT_DIR}/nocloud"
    
    # For now, just copy the profile as the autoinstall config
    # In a real implementation, you'd use a template engine like Jinja2
    # For simplicity, we'll create a basic autoinstall.yaml
    
    cat > "$output_path" <<EOF
#cloud-config
autoinstall:
  version: 1
  locale: en_US.UTF-8
  keyboard:
    layout: us
  timezone: UTC
  
  identity:
    hostname: ubuntu-server
    username: admin
    password: "\$6\$rounds=4096\$randomsalt\$hashedpassword"
  
  ssh:
    install-server: true
    allow-pw: false
    authorized-keys: []
  
  storage:
    layout:
      name: lvm
  
  packages:
    - curl
    - wget
    - git
    - docker.io
  
  late-commands:
    - echo "Post-install scripts would run here"
EOF
    
    # Create meta-data
    cat > "${EXTRACT_DIR}/nocloud/meta-data" <<EOF
instance-id: ironforge-$(date +%s)
local-hostname: ubuntu-server
EOF
    
    log_info "Autoinstall configuration generated: $output_path"
}

copy_scripts() {
    log_info "Copying post-install scripts..."
    
    mkdir -p "${EXTRACT_DIR}/ironforge/scripts"
    cp -r "${PROJECT_DIR}/scripts/"* "${EXTRACT_DIR}/ironforge/scripts/"
    chmod +x "${EXTRACT_DIR}/ironforge/scripts/"*.sh
    
    log_info "Scripts copied"
}

update_grub() {
    local template_path="${PROJECT_DIR}/templates/grub.cfg.template"
    local grub_cfg="${EXTRACT_DIR}/boot/grub/grub.cfg"
    
    log_info "Updating GRUB configuration..."
    
    # Backup original
    cp "$grub_cfg" "${grub_cfg}.bak"
    
    # Copy template
    cp "$template_path" "$grub_cfg"
    
    log_info "GRUB configuration updated"
}

build_iso() {
    local output_iso="$1"
    
    log_info "Building custom ISO..."
    
    # Create output directory
    mkdir -p "$(dirname "$output_iso")"
    
    # Build ISO with xorriso
    xorriso -as mkisofs \
        -r \
        -V "IRONFORGE_$(date +%Y%m%d)" \
        -o "$output_iso" \
        -J -l \
        -b isolinux/isolinux.bin \
        -c isolinux/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -eltorito-alt-boot \
        -e boot/grub/efi.img \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
        -isohybrid-apm-hfsplus \
        "$EXTRACT_DIR"
    
    log_info "ISO built successfully: $output_iso"
}

cleanup() {
    log_info "Cleaning up..."
    rm -rf "$EXTRACT_DIR"
    log_info "Cleanup complete"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        --ubuntu-version)
            UBUNTU_VERSION="$2"
            shift 2
            ;;
        --output)
            OUTPUT_ISO="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate arguments
if [ -z "$PROFILE" ]; then
    log_error "Profile is required"
    usage
fi

# Main execution
main() {
    log_info "IronForge Ingot - Building custom Ubuntu ISO"
    log_info "Profile: $PROFILE"
    log_info "Ubuntu version: $UBUNTU_VERSION"
    
    check_dependencies
    
    # Download Ubuntu ISO
    local ubuntu_iso
    ubuntu_iso=$(download_ubuntu_iso)
    
    # Extract ISO
    extract_iso "$ubuntu_iso"
    
    # Generate autoinstall config
    generate_autoinstall_config "$PROFILE"
    
    # Copy scripts
    copy_scripts
    
    # Update GRUB
    update_grub
    
    # Build custom ISO
    build_iso "$OUTPUT_ISO"
    
    # Cleanup
    cleanup
    
    log_info "Build complete!"
    log_info "Output ISO: $OUTPUT_ISO"
    log_info ""
    log_info "To create a bootable USB:"
    log_info "  sudo dd if=$OUTPUT_ISO of=/dev/sdX status=progress"
}

main
