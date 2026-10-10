#!/bin/bash
# IronForge Ingot - Build Raspberry Pi Ubuntu Image
# Usage: ./build-rpi-img.sh --profile <profile> [--ubuntu-version <version>]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
UBUNTU_VERSION="24.04"
PROFILE=""
BUILD_DIR="${PROJECT_DIR}/build"
OUTPUT_IMG="${BUILD_DIR}/rpi-ubuntu-server.img"
TEMP_DIR="${BUILD_DIR}/temp"

# Ubuntu RPi image URL
UBUNTU_RPI_URL="https://cdimage.ubuntu.com/releases/${UBUNTU_VERSION}/release/ubuntu-${UBUNTU_VERSION}-preinstalled-server-arm64+raspi.img.xz"

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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Build a custom Ubuntu image for Raspberry Pi with auto-installation.

Options:
    --profile <name>          Profile to use (required)
    --ubuntu-version <ver>    Ubuntu version (default: ${UBUNTU_VERSION})
    --output <path>           Output image path (default: ${OUTPUT_IMG})
    --help                    Show this help message

Available profiles:
EOF
    ls -1 "${PROJECT_DIR}/profiles/" | grep "^rpi-" | sed 's/.yaml$//' | sed 's/^/    - /'
    echo ""
    echo "Example:"
    echo "    $0 --profile rpi-server"
    echo ""
    echo "After building, flash the image to SD card:"
    echo "    sudo dd if=${OUTPUT_IMG} of=/dev/sdX status=progress"
    echo ""
    exit 0
}

check_dependencies() {
    log_info "Checking dependencies..."
    
    local deps=(curl xz parted losetup mount umount python3)
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    # Check for python3-yaml
    if ! python3 -c "import yaml" 2>/dev/null; then
        missing+=("python3-yaml")
    fi
    
    # Check for Jinja2
    if ! python3 -c "import jinja2" 2>/dev/null; then
        missing+=("python3-jinja2")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_error "Install with: sudo apt-get install ${missing[*]}"
        exit 1
    fi
    
    log_info "All dependencies satisfied"
}

download_rpi_image() {
    local img_path="${BUILD_DIR}/ubuntu-${UBUNTU_VERSION}-preinstalled-server-arm64+raspi.img.xz"
    
    if [ -f "$img_path" ]; then
        log_info "Ubuntu RPi image already downloaded: $img_path"
        echo "$img_path"
        return
    fi
    
    log_info "Downloading Ubuntu ${UBUNTU_VERSION} RPi image..."
    log_info "URL: ${UBUNTU_RPI_URL}"
    log_info "This may take several minutes (~3GB)..."
    
    mkdir -p "$BUILD_DIR"
    curl -L "$UBUNTU_RPI_URL" -o "$img_path"
    
    log_info "Download complete: $img_path"
    echo "$img_path"
}

decompress_image() {
    local xz_path="$1"
    local img_path="${BUILD_DIR}/ubuntu-${UBUNTU_VERSION}-preinstalled-server-arm64+raspi.img"
    
    if [ -f "$img_path" ]; then
        log_info "Image already decompressed: $img_path"
        echo "$img_path"
        return
    fi
    
    log_info "Decompressing image..."
    xz -dk "$xz_path"
    
    log_info "Decompression complete: $img_path"
    echo "$img_path"
}

mount_image() {
    local img_path="$1"
    
    log_info "Mounting image..."
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    
    # Setup loop device
    LOOP_DEV=$(losetup --find --show --partscan "$img_path")
    log_info "Loop device created: $LOOP_DEV"
    
    # Wait for partitions to appear
    sleep 2
    
    # Mount boot partition (FAT32)
    mkdir -p "${TEMP_DIR}/boot"
    mount "${LOOP_DEV}p1" "${TEMP_DIR}/boot"
    log_info "Boot partition mounted"
    
    # Save loop device for later
    echo "$LOOP_DEV" > "${TEMP_DIR}/loop_device"
}

parse_profile() {
    local profile_name="$1"
    local profile_path="${PROJECT_DIR}/profiles/${profile_name}.yaml"
    
    if [ ! -f "$profile_path" ]; then
        log_error "Profile not found: $profile_path"
        exit 1
    fi
    
    log_info "Profile validated: $profile_name"
}

generate_cloud_init() {
    local user_data_template="${PROJECT_DIR}/templates/rpi-user-data.template"
    local meta_data_template="${PROJECT_DIR}/templates/rpi-meta-data.template"
    local user_data_output="${TEMP_DIR}/boot/user-data"
    local meta_data_output="${TEMP_DIR}/boot/meta-data"
    local render_script="${PROJECT_DIR}/tools/render-template.py"
    
    if [ ! -f "$user_data_template" ]; then
        log_error "Template not found: $user_data_template"
        exit 1
    fi
    
    if [ ! -f "$render_script" ]; then
        log_error "Render script not found: $render_script"
        exit 1
    fi
    
    log_info "Generating cloud-init configuration..."
    
    # Generate user-data
    python3 "$render_script" user-data \
        "$user_data_template" \
        "${PROJECT_DIR}/profiles/${PROFILE}.yaml" \
        "$user_data_output" \
        "$PROFILE"
    
    # Generate meta-data
    python3 "$render_script" meta-data \
        "$meta_data_template" \
        "${PROJECT_DIR}/profiles/${PROFILE}.yaml" \
        "$meta_data_output"
    
    log_info "Cloud-init configuration generated"
}

unmount_image() {
    log_info "Unmounting image..."
    
    # Unmount boot partition
    umount "${TEMP_DIR}/boot" || true
    
    # Detach loop device
    if [ -f "${TEMP_DIR}/loop_device" ]; then
        LOOP_DEV=$(cat "${TEMP_DIR}/loop_device")
        losetup -d "$LOOP_DEV" || true
        log_info "Loop device detached: $LOOP_DEV"
    fi
    
    # Clean up temp directory
    rm -rf "$TEMP_DIR"
    
    log_info "Image unmounted"
}

copy_output() {
    local source_img="$1"
    local output_img="$2"
    
    log_info "Creating output image..."
    
    mkdir -p "$(dirname "$output_img")"
    cp "$source_img" "$output_img"
    
    log_info "Output image created: $output_img"
}

cleanup() {
    log_info "Cleaning up..."
    
    # Ensure unmount in case of error
    unmount_image 2>/dev/null || true
    
    log_info "Cleanup complete"
}

# Trap errors and cleanup
trap cleanup EXIT

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
            OUTPUT_IMG="$2"
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
    log_info "IronForge Ingot - Building Raspberry Pi Ubuntu Image"
    log_info "Profile: $PROFILE"
    log_info "Ubuntu version: $UBUNTU_VERSION"
    echo ""
    
    # Check dependencies
    log_step "Checking dependencies"
    check_dependencies
    echo ""
    
    # Download Ubuntu RPi image
    log_step "Downloading Ubuntu RPi image"
    local xz_path
    xz_path=$(download_rpi_image)
    echo ""
    
    # Decompress image
    log_step "Decompressing image"
    local img_path
    img_path=$(decompress_image "$xz_path")
    echo ""
    
    # Parse profile
    log_step "Parsing profile"
    parse_profile "$PROFILE"
    echo ""
    
    # Mount image
    log_step "Mounting image"
    mount_image "$img_path"
    echo ""
    
    # Generate cloud-init
    log_step "Generating cloud-init configuration"
    generate_cloud_init
    echo ""
    
    # Unmount image
    log_step "Unmounting image"
    unmount_image
    echo ""
    
    # Copy to output
    log_step "Creating output image"
    copy_output "$img_path" "$OUTPUT_IMG"
    echo ""
    
    # Disable trap since we cleaned up manually
    trap - EXIT
    
    log_info "Build complete!"
    log_info "Output image: $OUTPUT_IMG"
    echo ""
    log_info "To flash the image to SD card:"
    log_info "  1. Insert SD card"
    log_info "  2. Find device: lsblk"
    log_info "  3. Flash image: sudo dd if=$OUTPUT_IMG of=/dev/sdX status=progress"
    log_info "  4. Insert SD card into Raspberry Pi 5"
    log_info "  5. Power on and wait for first-boot configuration"
    echo ""
    log_info "Default credentials:"
    log_info "  Username: admin"
    log_info "  Password: (set in profile or generated)"
    echo ""
}

main
