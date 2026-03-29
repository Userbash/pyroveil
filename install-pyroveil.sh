#!/usr/bin/env bash
# install-pyroveil.sh - Universal PyroVeil Installer
# Supported systems: Bazzite, Fedora Silverblue/Kinoite, Arch Linux, Generic Linux

set -euo pipefail

VERSION="1.0.0"
REPO_URL="https://github.com/HansKristian-Work/pyroveil.git"
PREFIX="${PREFIX:-$HOME/.local}"
SRC_DIR="${SRC_DIR:-$HOME/.pyroveil-build}"

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log() { echo -e "${BLUE}[install-pyroveil]${NC} $*"; }
warn() { echo -e "${YELLOW}[install-pyroveil]${NC} $*"; }
error() { echo -e "${RED}[install-pyroveil]${NC} $*" >&2; }
success() { echo -e "${GREEN}[install-pyroveil]${NC} $*"; }
header() { echo -e "${BOLD}${CYAN}$*${NC}"; }

die() {
    error "$*"
    exit 1
}

# Detect system type (immutable vs. standard Linux distributions)
detect_system() {
    local system="unknown"
    
    if command -v rpm-ostree &>/dev/null; then
        system="immutable-fedora"
    elif [[ -f /etc/os-release ]]; then
        source /etc/os-release
        
        if [[ "$ID" == "bazzite" ]] || [[ "$ID_LIKE" =~ "bazzite" ]]; then
            system="bazzite"
        elif [[ "$ID" == "arch" ]] || [[ "$ID_LIKE" =~ "arch" ]]; then
            system="arch"
        elif [[ "$ID" == "fedora" ]] && command -v rpm-ostree &>/dev/null; then
            system="immutable-fedora"
        elif [[ "$ID" == "fedora" ]]; then
            system="fedora"
        elif [[ "$ID" =~ "debian" ]] || [[ "$ID_LIKE" =~ "debian" ]]; then
            system="debian"
        else
            system="generic"
        fi
    fi
    
    echo "$system"
}

# Check and install required build dependencies for the detected system
check_dependencies() {
    local system=$1
    local missing_deps=()
    
    case "$system" in
        immutable-fedora|bazzite)
            if ! command -v distrobox &>/dev/null; then
                error "Distrobox is not installed!"
                error "Install it: rpm-ostree install distrobox && systemctl reboot"
                return 1
            fi
            ;;
        arch)
            for dep in git cmake ninja gcc; do
                if ! command -v $dep &>/dev/null; then
                    missing_deps+=("$dep")
                fi
            done
            
            if [[ ${#missing_deps[@]} -gt 0 ]]; then
                warn "Missing dependencies: ${missing_deps[*]}"
                warn "Installing dependencies..."
                sudo pacman -S --needed --noconfirm git cmake ninja gcc || die "Failed to install dependencies"
            fi
            ;;
        fedora)
            for dep in git cmake ninja-build gcc-c++; do
                if ! rpm -q $dep &>/dev/null; then
                    missing_deps+=("$dep")
                fi
            done
            
            if [[ ${#missing_deps[@]} -gt 0 ]]; then
                warn "Missing dependencies: ${missing_deps[*]}"
                warn "Installing dependencies..."
                sudo dnf install -y git cmake ninja-build gcc-c++ || die "Failed to install dependencies"
            fi
            ;;
        debian)
            for dep in git cmake ninja-build g++; do
                if ! dpkg -s $dep &>/dev/null 2>&1; then
                    missing_deps+=("$dep")
                fi
            done
            
            if [[ ${#missing_deps[@]} -gt 0 ]]; then
                warn "Missing dependencies: ${missing_deps[*]}"
                warn "Installing dependencies..."
                sudo apt-get update && sudo apt-get install -y git cmake ninja-build g++ || \
                    die "Failed to install dependencies"
            fi
            ;;
    esac
    
    return 0
}

# Install on immutable systems using distrobox container
install_immutable() {
    header "Installing PyroVeil on immutable system via Distrobox"
    
    local container_name="pyroveil-build"
    local image="fedora:latest"
    
    # Check if container already exists
    if distrobox list | grep -q "^${container_name}"; then
        log "Container $container_name already exists, reusing it"
    else
        log "Creating container $container_name..."
        distrobox create -n "$container_name" -i "$image" || die "Failed to create container"
    fi
    
    log "Preparing build environment in container..."
    
    # Build inside the container
    distrobox enter "$container_name" -- bash -c "
        set -euo pipefail
        
        # Install dependencies
        echo 'Installing dependencies...'
        sudo dnf install -y git cmake ninja-build gcc-c++ || exit 1
        
        # Clone repository
        if [[ -d /tmp/pyroveil ]]; then
            rm -rf /tmp/pyroveil
        fi
        
        echo 'Cloning PyroVeil repository...'
        git clone --depth 1 '$REPO_URL' /tmp/pyroveil || exit 1
        cd /tmp/pyroveil
        
        echo 'Initializing submodules...'
        git submodule update --init --recursive || exit 1
        
        echo 'Configuring CMake...'
        cmake -B build -G Ninja \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX='$PREFIX' || exit 1
        
        echo 'Building...'
        ninja -C build || exit 1
        
        echo 'Installing...'
        ninja -C build install || exit 1
        
        # Copy database and configs
        echo 'Installing database and game configs...'
        mkdir -p '$PREFIX/share/pyroveil/hacks'
        cp -r hacks/* '$PREFIX/share/pyroveil/hacks/' || true
        cp database.json '$PREFIX/share/pyroveil/' 2>/dev/null || true
        
        echo 'Build completed successfully!'
    " || die "Container build failed"
    
    success "Container build completed"
}

# Install on standard Linux systems (native build)
install_native() {
    header "Installing PyroVeil (native build)"
    
    # Clean old build directory
    if [[ -d "$SRC_DIR" ]]; then
        log "Removing old build directory..."
        rm -rf "$SRC_DIR"
    fi
    
    # Clone repository
    log "Cloning repository from $REPO_URL..."
    git clone --depth 1 "$REPO_URL" "$SRC_DIR" || die "Failed to clone repository"
    
    cd "$SRC_DIR"
    
    # Initialize submodules
    log "Initializing submodules..."
    git submodule update --init --recursive || die "Failed to update submodules"
    
    # Configure
    log "Configuring CMake..."
    cmake -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" || die "Failed to configure project"
    
    # Build
    log "Building (this may take several minutes)..."
    ninja -C build || die "Build failed"
    
    # Install
    log "Installing to $PREFIX..."
    ninja -C build install || die "Installation failed"
    
    # Copy additional files
    log "Installing configs and database..."
    mkdir -p "$PREFIX/share/pyroveil/hacks"
    cp -r hacks/* "$PREFIX/share/pyroveil/hacks/" 2>/dev/null || true
    cp database.json "$PREFIX/share/pyroveil/" 2>/dev/null || true
    
    success "Build and installation completed"
}

# Post-installation configuration
post_install() {
    header "Post-installation configuration"
    
    local layer_path="$PREFIX/share/vulkan/implicit_layer.d"
    local bashrc="$HOME/.bashrc"
    local profile="$HOME/.profile"
    
    # Configure VK_LAYER_PATH environment variable
    log "Configuring environment variables..."
    
    local env_line="export VK_LAYER_PATH=\"$layer_path:\${VK_LAYER_PATH:-}\""
    
    if ! grep -qF "VK_LAYER_PATH" "$bashrc" 2>/dev/null; then
        echo "" >> "$bashrc"
        echo "# PyroVeil Vulkan Layer" >> "$bashrc"
        echo "$env_line" >> "$bashrc"
        success "VK_LAYER_PATH added to $bashrc"
    else
        log "VK_LAYER_PATH already set in $bashrc"
    fi
    
    if [[ -f "$profile" ]] && ! grep -qF "VK_LAYER_PATH" "$profile" 2>/dev/null; then
        echo "" >> "$profile"
        echo "# PyroVeil Vulkan Layer" >> "$profile"
        echo "$env_line" >> "$profile"
        success "VK_LAYER_PATH added to $profile"
    fi
    
    # Export for current session
    export VK_LAYER_PATH="$layer_path${VK_LAYER_PATH:+:$VK_LAYER_PATH}"
    
    # Install utility scripts
    log "Installing utilities..."
    
    local bin_dir="$PREFIX/bin"
    mkdir -p "$bin_dir"
    
    # Copy automation scripts
    if [[ -f "$SRC_DIR/scripts/pyroveil-auto-detect.sh" ]]; then
        cp "$SRC_DIR/scripts/pyroveil-auto-detect.sh" "$bin_dir/pyroveil-auto-detect"
        chmod +x "$bin_dir/pyroveil-auto-detect"
    fi
    
    # Check if jq is installed
    if ! command -v jq &>/dev/null; then
        warn "jq is not installed - game auto-detection will not work"
        warn "Install it: sudo pacman -S jq (Arch) or sudo dnf install jq (Fedora)"
    fi
    
    # Verify layer files
    local so_file="$PREFIX/lib/libVkLayer_pyroveil_64.so"
    local json_file="$layer_path/VkLayer_pyroveil_64.json"
    
    if [[ -f "$so_file" ]] && [[ -f "$json_file" ]]; then
        success "Layer files installed correctly:"
        log "  - $so_file"
        log "  - $json_file"
    else
        error "Layer files not found!"
        [[ ! -f "$so_file" ]] && error "  Missing: $so_file"
        [[ ! -f "$json_file" ]] && error "  Missing: $json_file"
        return 1
    fi
    
    # Display supported games information
    local db_file="$PREFIX/share/pyroveil/database.json"
    if [[ -f "$db_file" ]] && command -v jq &>/dev/null; then
        echo ""
        header "Supported games:"
        jq -r '.games[] | "  ✓ \(.name) (AppID: \(.steam_appid // "N/A"))"' "$db_file"
    fi
    
    return 0
}

# Display final installation information and next steps
print_final_info() {
    echo ""
    header "╔════════════════════════════════════════════════════════╗"
    header "║       PyroVeil installed successfully! 🎉             ║"
    header "╚════════════════════════════════════════════════════════╝"
    echo ""
    
    success "Next steps:"
    echo ""
    echo "  1. Restart your terminal or run:"
    echo "     ${CYAN}source ~/.bashrc${NC}"
    echo ""
    echo "  2. For automatic operation, add to Steam launch options:"
    echo "     ${CYAN}PYROVEIL=1 %command%${NC}"
    echo ""
    echo "  3. PyroVeil will automatically detect your game and apply the correct config"
    echo ""
    echo "  4. To manually configure a specific game:"
    echo "     ${CYAN}pyroveil-auto-detect check <steam_appid>${NC}"
    echo ""
    echo "  5. List supported games:"
    echo "     ${CYAN}pyroveil-auto-detect list${NC}"
    echo ""
    
    if ! command -v jq &>/dev/null; then
        warn "⚠️  Game auto-detection requires jq to be installed:"
        warn "   Arch:   sudo pacman -S jq"
        warn "   Fedora: sudo dnf install jq"
    fi
    
    echo ""
    log "Installation completed in: $PREFIX"
    log "Game database: $PREFIX/share/pyroveil/database.json"
    log "Game configs: $PREFIX/share/pyroveil/hacks/"
    echo ""
}

# Main installation function
main() {
    header "╔════════════════════════════════════════════════════════╗"
    header "║  PyroVeil Universal Installer v${VERSION}              ║"
    header "║  Vulkan layer support for NVIDIA                      ║"
    header "╚════════════════════════════════════════════════════════╝"
    echo ""
    
    # Check permissions (must not be root)
    if [[ $EUID -eq 0 ]]; then
        die "Do not run this script as root! Use a regular user account."
    fi
    
    # Detect system type
    local system=$(detect_system)
    log "Detected system: ${BOLD}$system${NC}"
    echo ""
    
    # Check dependencies
    log "Checking dependencies..."
    check_dependencies "$system" || die "Failed to check/install dependencies"
    echo ""
    
    # Install based on system type
    case "$system" in
        immutable-fedora|bazzite)
            install_immutable
            ;;
        *)
            install_native
            ;;
    esac
    
    echo ""
    
    # Post-installation configuration
    post_install || die "Post-installation configuration failed"
    
    # Display final information
    print_final_info
}

# Execute installer
main "$@"
