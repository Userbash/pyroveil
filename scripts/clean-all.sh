#!/usr/bin/env bash
#
# clean-all.sh - Complete project cleanup script
#
# This script removes all build artifacts, caches, temporary files,
# and generated content to restore the project to a clean state.
#
# Usage:
#   ./scripts/clean-all.sh           - Interactive mode (asks for confirmation)
#   ./scripts/clean-all.sh --force   - Non-interactive mode (immediate cleanup)
#
# What gets cleaned:
#   - Build directories (build/, cmake-build-*)
#   - Compiled libraries and executables (*.so, *.a, *.o)
#   - CMake cache files
#   - Shader caches
#   - Editor temporary files
#   - Log files
#   - Test artifacts

set -uo pipefail

# ANSI color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly RESET='\033[0m'

# Project root directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Cleanup statistics
DIRS_REMOVED=0
FILES_REMOVED=0
SPACE_FREED=0

# ============================================================================
# Utility Functions
# ============================================================================

print_header() {
    echo -e "\n${BOLD}${BLUE}========================================${RESET}"
    echo -e "${BOLD}${BLUE}$1${RESET}"
    echo -e "${BOLD}${BLUE}========================================${RESET}\n"
}

print_info() {
    echo -e "${BLUE}[INFO]${RESET} $1"
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

# Calculate size of directory/file in bytes
get_size() {
    if [[ -e "$1" ]]; then
        du -sb "$1" 2>/dev/null | awk '{print $1}'
    else
        echo "0"
    fi
}

# Human-readable size formatting
format_size() {
    local size=$1
    if command -v numfmt >/dev/null 2>&1; then
        numfmt --to=iec-i --suffix=B "${size}"
    else
        echo "${size} bytes"
    fi
}

# Remove directory with size tracking
remove_dir() {
    local dir="$1"
    if [[ -d "${dir}" ]]; then
        local size=$(get_size "${dir}")
        print_info "Removing directory: ${dir}"
        rm -rf "${dir}"
        ((DIRS_REMOVED++))
        SPACE_FREED=$((SPACE_FREED + size))
        print_success "Removed $(format_size ${size})"
    fi
}

# Remove file with size tracking
remove_file() {
    local file="$1"
    if [[ -f "${file}" ]]; then
        local size=$(get_size "${file}")
        rm -f "${file}"
        ((FILES_REMOVED++))
        SPACE_FREED=$((SPACE_FREED + size))
    fi
}

# Remove files by pattern
remove_pattern() {
    local pattern="$1"
    local description="$2"
    
    print_info "Cleaning: ${description}"
    
    local count=0
    while IFS= read -r -d '' file; do
        remove_file "${file}"
        ((count++))
    done < <(find "${PROJECT_ROOT}" -type f -name "${pattern}" -print0 2>/dev/null)
    
    if [[ ${count} -gt 0 ]]; then
        print_success "Removed ${count} file(s)"
    fi
}

# ============================================================================
# Cleanup Functions
# ============================================================================

clean_build_directories() {
    print_header "Cleaning Build Directories"
    
    # Standard build directories
    remove_dir "${PROJECT_ROOT}/build"
    remove_dir "${PROJECT_ROOT}/cmake-build-debug"
    remove_dir "${PROJECT_ROOT}/cmake-build-release"
    remove_dir "${PROJECT_ROOT}/build-ci"
    
    # Find and remove any build-* directories
    while IFS= read -r -d '' dir; do
        remove_dir "${dir}"
    done < <(find "${PROJECT_ROOT}" -maxdepth 1 -type d -name "build-*" -print0 2>/dev/null)
}

clean_compiled_artifacts() {
    print_header "Cleaning Compiled Artifacts"
    
    # Shared libraries
    remove_pattern "*.so" "Shared libraries"
    remove_pattern "*.so.*" "Versioned shared libraries"
    
    # Static libraries
    remove_pattern "*.a" "Static libraries"
    
    # Object files
    remove_pattern "*.o" "Object files"
    remove_pattern "*.obj" "Object files (Windows)"
    
    # Executables
    remove_pattern "*.exe" "Executables"
}

clean_cmake_files() {
    print_header "Cleaning CMake Cache Files"
    
    # CMake cache and generated files
    remove_file "${PROJECT_ROOT}/CMakeCache.txt"
    remove_dir "${PROJECT_ROOT}/CMakeFiles"
    remove_pattern "cmake_install.cmake" "CMake install manifests"
    remove_pattern "CTestTestfile.cmake" "CTest files"
    remove_pattern "install_manifest.txt" "Install manifests"
}

clean_shader_caches() {
    print_header "Cleaning Shader Caches"
    
    # PyroVeil shader caches
    while IFS= read -r -d '' cache_dir; do
        remove_dir "${cache_dir}"
    done < <(find "${PROJECT_ROOT}/hacks" -type d -name "cache" -print0 2>/dev/null)
    
    # Fossilize caches
    remove_pattern "*.foz" "Fossilize shader caches"
    remove_pattern "*.cache" "Generic cache files"
}

clean_editor_files() {
    print_header "Cleaning Editor Temporary Files"
    
    # Vim
    remove_pattern "*.swp" "Vim swap files"
    remove_pattern "*.swo" "Vim swap files"
    remove_pattern "*~" "Vim backup files"
    
    # Emacs
    remove_pattern "\#*\#" "Emacs autosave files"
    
    # VS Code
    remove_dir "${PROJECT_ROOT}/.vscode"
    
    # General backup files
    remove_pattern "*.bak" "Backup files"
    remove_pattern "*.backup" "Backup files"
    remove_pattern "*.orig" "Original files"
    remove_pattern "*.tmp" "Temporary files"
}

clean_logs() {
    print_header "Cleaning Log Files"
    
    remove_pattern "*.log" "Log files"
    remove_dir "${PROJECT_ROOT}/logs"
}

clean_test_artifacts() {
    print_header "Cleaning Test Artifacts"
    
    remove_dir "${PROJECT_ROOT}/Testing"
    remove_dir "${PROJECT_ROOT}/test_results"
    
    # Coverage files
    remove_pattern "*.gcda" "Coverage data files"
    remove_pattern "*.gcno" "Coverage notes files"
    remove_pattern "*.gcov" "Coverage output files"
}

clean_install_test() {
    print_header "Cleaning Installation Test Directories"
    
    remove_dir "${PROJECT_ROOT}/install-test"
    remove_dir "${PROJECT_ROOT}/prefix"
    remove_dir "${PROJECT_ROOT}/staging"
}

clean_python_cache() {
    print_header "Cleaning Python Cache"
    
    while IFS= read -r -d '' dir; do
        remove_dir "${dir}"
    done < <(find "${PROJECT_ROOT}" -type d -name "__pycache__" -print0 2>/dev/null)
    
    remove_pattern "*.pyc" "Python compiled files"
    remove_pattern "*.pyo" "Python optimized files"
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    print_header "PyroVeil Project Cleanup"
    echo -e "Project: ${BOLD}${PROJECT_ROOT}${RESET}"
    echo -e "Date: ${BOLD}$(date '+%Y-%m-%d %H:%M:%S')${RESET}"
    echo ""
    
    # Check for --force flag
    local force_mode=false
    if [[ "${1:-}" == "--force" ]] || [[ "${1:-}" == "-f" ]]; then
        force_mode=true
    fi
    
    # Confirmation prompt (unless --force)
    if [[ "${force_mode}" == false ]]; then
        print_warning "This will remove all build artifacts, caches, and temporary files."
        echo -en "${YELLOW}Continue? [y/N]${RESET} "
        read -r response
        if [[ ! "${response}" =~ ^[Yy]$ ]]; then
            print_info "Cleanup cancelled by user"
            exit 0
        fi
        echo ""
    fi
    
    # Execute cleanup operations
    clean_build_directories
    clean_compiled_artifacts
    clean_cmake_files
    clean_shader_caches
    clean_editor_files
    clean_logs
    clean_test_artifacts
    clean_install_test
    clean_python_cache
    
    # Print summary
    print_header "Cleanup Summary"
    echo -e "${GREEN}Directories removed:${RESET} ${DIRS_REMOVED}"
    echo -e "${GREEN}Files removed:${RESET} ${FILES_REMOVED}"
    echo -e "${GREEN}Space freed:${RESET} $(format_size ${SPACE_FREED})"
    echo ""
    print_success "Project cleanup completed successfully!"
    echo ""
    print_info "To rebuild the project, run:"
    echo -e "  ${BOLD}cmake -B build -G Ninja${RESET}"
    echo -e "  ${BOLD}ninja -C build${RESET}"
}

# Run main function
main "$@"
