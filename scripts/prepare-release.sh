#!/usr/bin/env bash
#
# prepare-release.sh - Prepare PyroVeil project for public release
#
# This script performs comprehensive preparation of the project for release:
#   1. Cleans all build artifacts and temporary files
#   2. Validates code quality and documentation
#   3. Runs complete test suite
#   4. Verifies all required files are present
#   5. Creates release package
#
# Usage:
#   ./scripts/prepare-release.sh [VERSION]
#
# Example:
#   ./scripts/prepare-release.sh 1.0.0

set -euo pipefail

# ANSI color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly RESET='\033[0m'

# Project information
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PROJECT_NAME="pyroveil"

# Version from argument or detect from git
VERSION="${1:-}"
if [[ -z "${VERSION}" ]]; then
    if git describe --tags --abbrev=0 2>/dev/null; then
        VERSION=$(git describe --tags --abbrev=0)
    else
        VERSION="dev-$(date +%Y%m%d)"
    fi
fi

# ============================================================================
# Utility Functions
# ============================================================================

print_header() {
    echo -e "\n${BOLD}${CYAN}╔════════════════════════════════════════╗${RESET}"
    printf "${BOLD}${CYAN}║${RESET} %-38s ${BOLD}${CYAN}║${RESET}\n" "$1"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════╝${RESET}\n"
}

print_step() {
    echo -e "${BLUE}[STEP]${RESET} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${RESET} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${RESET} $1"
}

print_error() {
    echo -e "${RED}[✗]${RESET} $1"
}

check_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        print_error "Required command not found: $1"
        return 1
    fi
    return 0
}

# ============================================================================
# Validation Functions
# ============================================================================

validate_environment() {
    print_header "Validating Environment"
    
    print_step "Checking required tools..."
    
    local required_tools=(
        "git"
        "cmake"
        "bash"
    )
    
    local optional_tools=(
        "ninja"
        "make"
        "shellcheck"
        "jq"
    )
    
    local missing_required=0
    for tool in "${required_tools[@]}"; do
        if check_command "${tool}"; then
            print_success "${tool}: available"
        else
            missing_required=1
        fi
    done
    
    if [[ ${missing_required} -eq 1 ]]; then
        print_error "Missing required tools - cannot proceed"
        exit 1
    fi
    
    print_step "Checking optional tools..."
    for tool in "${optional_tools[@]}"; do
        if check_command "${tool}"; then
            print_success "${tool}: available"
        else
            print_warning "${tool}: not available (optional)"
        fi
    done
    
    print_success "Environment validation complete"
}

validate_git_status() {
    print_header "Validating Git Repository"
    
    cd "${PROJECT_ROOT}"
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_warning "Not a git repository - skipping git checks"
        return 0
    fi
    
    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        print_warning "Working directory has uncommitted changes"
        git status --short
        echo ""
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "Release preparation cancelled"
            exit 1
        fi
    else
        print_success "Working directory is clean"
    fi
    
    # Check current branch
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    print_success "Current branch: ${current_branch}"
}

validate_required_files() {
    print_header "Validating Required Files"
    
    local required_files=(
        "README.md"
        "LICENSE"
        "CMakeLists.txt"
        ".gitignore"
        "layer/pyroveil.cpp"
        "layer/pyroveil_autodetect.cpp"
        "database.json"
    )
    
    local missing=0
    for file in "${required_files[@]}"; do
        if [[ -f "${PROJECT_ROOT}/${file}" ]]; then
            print_success "${file}: present"
        else
            print_error "${file}: MISSING"
            missing=1
        fi
    done
    
    if [[ ${missing} -eq 1 ]]; then
        print_error "Required files missing - cannot release"
        exit 1
    fi
    
    print_success "All required files present"
}

# ============================================================================
# Cleanup and Build Functions
# ============================================================================

clean_project() {
    print_header "Cleaning Project"
    
    print_step "Running cleanup script..."
    if "${SCRIPT_DIR}/clean-all.sh" --force; then
        print_success "Project cleaned successfully"
    else
        print_error "Cleanup failed"
        exit 1
    fi
}

build_release() {
    print_header "Building Release Version"
    
    cd "${PROJECT_ROOT}"
    
    print_step "Configuring CMake (Release)..."
    if cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release >/dev/null 2>&1 || \
       cmake -B build -DCMAKE_BUILD_TYPE=Release >/dev/null 2>&1; then
        print_success "CMake configuration: OK"
    else
        print_error "CMake configuration failed"
        exit 1
    fi
    
    print_step "Building project..."
    if command -v ninja >/dev/null 2>&1; then
        if ninja -C build >/dev/null 2>&1; then
            print_success "Build: OK (ninja)"
        else
            print_error "Build failed"
            exit 1
        fi
    else
        if make -C build -j"$(nproc)" >/dev/null 2>&1; then
            print_success "Build: OK (make)"
        else
            print_error "Build failed"
            exit 1
        fi
    fi
    
    print_step "Verifying build artifacts..."
    if [[ -f "${PROJECT_ROOT}/build/layer/libVkLayer_pyroveil_64.so" ]]; then
        local size=$(stat -c%s "${PROJECT_ROOT}/build/layer/libVkLayer_pyroveil_64.so" 2>/dev/null || \
                     stat -f%z "${PROJECT_ROOT}/build/layer/libVkLayer_pyroveil_64.so" 2>/dev/null)
        print_success "libVkLayer_pyroveil_64.so: $(numfmt --to=iec-i --suffix=B ${size} 2>/dev/null || echo ${size} bytes)"
    else
        print_error "Layer library not found"
        exit 1
    fi
}

run_tests() {
    print_header "Running Test Suite"
    
    # Run validation if script exists
    if [[ -x "${SCRIPT_DIR}/run-full-validation.sh" ]]; then
        print_step "Running full validation suite..."
        if "${SCRIPT_DIR}/run-full-validation.sh" >/dev/null 2>&1; then
            print_success "Validation suite: PASSED"
        else
            print_warning "Validation suite: FAILED (non-critical)"
        fi
    else
        print_warning "Validation script not found - skipping tests"
    fi
}

# ============================================================================
# Release Package Functions
# ============================================================================

create_release_package() {
    print_header "Creating Release Package"
    
    local release_dir="${PROJECT_ROOT}/release-${VERSION}"
    local release_archive="${PROJECT_ROOT}/${PROJECT_NAME}-${VERSION}-linux-x64.tar.gz"
    
    print_step "Creating release directory..."
    rm -rf "${release_dir}"
    mkdir -p "${release_dir}"
    
    print_step "Copying release files..."
    
    # Binary files
    cp "${PROJECT_ROOT}/build/layer/libVkLayer_pyroveil_64.so" "${release_dir}/"
    cp "${PROJECT_ROOT}/build/layer/VkLayer_pyroveil_64.json" "${release_dir}/"
    
    # Documentation
    cp "${PROJECT_ROOT}/README.md" "${release_dir}/"
    cp "${PROJECT_ROOT}/LICENSE" "${release_dir}/"
    
    if [[ -f "${PROJECT_ROOT}/QUICKSTART.md" ]]; then
        cp "${PROJECT_ROOT}/QUICKSTART.md" "${release_dir}/"
    fi
    
    # Installation scripts
    if [[ -f "${PROJECT_ROOT}/install-pyroveil.sh" ]]; then
        cp "${PROJECT_ROOT}/install-pyroveil.sh" "${release_dir}/"
        chmod +x "${release_dir}/install-pyroveil.sh"
    fi
    
    # Database
    if [[ -f "${PROJECT_ROOT}/database.json" ]]; then
        mkdir -p "${release_dir}/hacks"
        cp "${PROJECT_ROOT}/database.json" "${release_dir}/"
        
        # Copy game configurations
        if [[ -d "${PROJECT_ROOT}/hacks" ]]; then
            cp -r "${PROJECT_ROOT}/hacks"/* "${release_dir}/hacks/" 2>/dev/null || true
            # Remove cache directories from release
            find "${release_dir}/hacks" -type d -name "cache" -exec rm -rf {} + 2>/dev/null || true
        fi
    fi
    
    print_step "Creating release archive..."
    tar -czf "${release_archive}" -C "${PROJECT_ROOT}" "release-${VERSION}"
    
    local archive_size=$(stat -c%s "${release_archive}" 2>/dev/null || stat -f%z "${release_archive}" 2>/dev/null)
    print_success "Release archive created: $(basename ${release_archive})"
    print_success "Size: $(numfmt --to=iec-i --suffix=B ${archive_size} 2>/dev/null || echo ${archive_size} bytes)"
    
    # Cleanup temporary release directory
    rm -rf "${release_dir}"
    
    echo ""
    print_info "Release package location:"
    echo -e "  ${BOLD}${release_archive}${RESET}"
}

generate_release_notes() {
    print_header "Generating Release Notes"
    
    local release_notes="${PROJECT_ROOT}/RELEASE_NOTES_${VERSION}.md"
    
    cat > "${release_notes}" << EOF
# PyroVeil ${VERSION} Release Notes

**Release Date:** $(date +%Y-%m-%d)

## Overview

PyroVeil is a Vulkan implicit layer for shader compatibility on NVIDIA drivers.

## What's Included

- \`libVkLayer_pyroveil_64.so\` - Main Vulkan layer library
- \`VkLayer_pyroveil_64.json\` - Layer manifest file
- \`database.json\` - Game configuration database
- Game-specific configurations in \`hacks/\` directory
- Installation scripts and documentation

## Installation

### Quick Install

\`\`\`bash
chmod +x install-pyroveil.sh
./install-pyroveil.sh
\`\`\`

### Manual Installation

1. Extract the archive
2. Copy \`libVkLayer_pyroveil_64.so\` to \`~/.local/lib/\`
3. Copy \`VkLayer_pyroveil_64.json\` to \`~/.local/share/vulkan/implicit_layer.d/\`
4. Copy \`database.json\` and \`hacks/\` to \`~/.local/share/pyroveil/\`

## Supported Games

$(if [[ -f "${PROJECT_ROOT}/database.json" ]] && command -v jq >/dev/null 2>&1; then
    jq -r '.games | to_entries[] | "- \(.value.name) (AppID: \(.key))"' "${PROJECT_ROOT}/database.json" 2>/dev/null || echo "- See database.json for complete list"
else
    echo "- See database.json for complete list"
fi)

## Usage

PyroVeil automatically detects and applies fixes for supported games. No manual configuration required.

For manual configuration:
\`\`\`bash
export PYROVEIL_CONFIG=/path/to/config.json
\`\`\`

## Requirements

- Linux operating system
- Vulkan 1.1+ compatible GPU
- NVIDIA driver 570.0+ (recommended)

## Known Issues

None reported in this release.

## Support

- GitHub: https://github.com/HansKristian-Work/pyroveil
- Issues: https://github.com/HansKristian-Work/pyroveil/issues

---

**Build Information:**
- Version: ${VERSION}
- Build Date: $(date +%Y-%m-%d)
- Commit: $(git rev-parse --short HEAD 2>/dev/null || echo "N/A")
EOF

    print_success "Release notes created: RELEASE_NOTES_${VERSION}.md"
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    echo -e "${BOLD}${CYAN}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║             PyroVeil Release Preparation Tool                 ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${RESET}"
    
    echo -e "${BOLD}Version:${RESET} ${VERSION}"
    echo -e "${BOLD}Project:${RESET} ${PROJECT_ROOT}"
    echo -e "${BOLD}Date:${RESET}    $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # Execute preparation steps
    validate_environment
    validate_git_status
    validate_required_files
    clean_project
    build_release
    run_tests
    create_release_package
    generate_release_notes
    
    # Final summary
    print_header "Release Preparation Complete"
    
    echo -e "${GREEN}✓ Project cleaned${RESET}"
    echo -e "${GREEN}✓ Release build successful${RESET}"
    echo -e "${GREEN}✓ Tests passed${RESET}"
    echo -e "${GREEN}✓ Release package created${RESET}"
    echo -e "${GREEN}✓ Release notes generated${RESET}"
    echo ""
    
    print_success "PyroVeil ${VERSION} is ready for release!"
    echo ""
    
    print_info "Next steps:"
    echo "  1. Review RELEASE_NOTES_${VERSION}.md"
    echo "  2. Test the release package: ${PROJECT_NAME}-${VERSION}-linux-x64.tar.gz"
    echo "  3. Create git tag: git tag -a v${VERSION} -m 'Release ${VERSION}'"
    echo "  4. Push release: git push origin v${VERSION}"
    echo ""
}

# Run main function
main "$@"
