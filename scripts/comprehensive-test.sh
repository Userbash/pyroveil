#!/usr/bin/env bash
#
# comprehensive-test.sh - Complete PyroVeil Test Suite
#
# This master script runs ALL validation checks in the correct order:
# 1. Pre-build checks (syntax, dependencies, JSON validation)
# 2. Build system tests (CMake configuration, compilation)
# 3. Module tests (auto-detection, parsers, utilities)
# 4. Integration tests (end-to-end workflows)
# 5. Post-build checks (logging, documentation, static analysis)
# 6. Steam detection tests (library scanner, AppID detection)
#
# Usage:
#   ./scripts/comprehensive-test.sh [options]
#
# Options:
#   --quick         Fast checks only (skip compilation, static analysis)
#   --skip-build    Skip build/compilation tests
#   --verbose       Enable verbose output from all tests
#   --report FILE   Generate detailed report to FILE
#   --ci            CI mode (fail on warnings, strict error checking)
#
# Exit codes:
#   0 - All tests passed
#   1 - One or more tests failed
#   2 - Critical dependency missing
#   3 - Build failure (compilation errors)
#
# Copyright (c) 2025 PyroVeil Contributors
# SPDX-License-Identifier: MIT

set -uo pipefail  # Don't use -e to allow individual test failures

# ANSI color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly RESET='\033[0m'

# Project directories
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly BUILD_DIR="${PROJECT_ROOT}/build"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0
WARNED_TESTS=0

# Test categories
declare -A CATEGORY_PASSED
declare -A CATEGORY_FAILED
declare -A CATEGORY_SKIPPED

# Command-line options
QUICK_MODE=false
SKIP_BUILD=false
VERBOSE=false
CI_MODE=false
REPORT_FILE=""
AUTO_FIX=false
DRY_RUN=false

# Test results storage
declare -a TEST_RESULTS
declare -a FAILED_TEST_DETAILS

# Start time
START_TIME=$(date +%s)

#######################################
# Print functions
#######################################

print_banner() {
    echo -e "${BOLD}${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                   ║"
    echo "║        PyroVeil Comprehensive Test Suite v2.0                     ║"
    echo "║        Complete Validation of All Components                     ║"
    echo "║                                                                   ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

print_header() {
    echo -e "\n${BOLD}${MAGENTA}┌─────────────────────────────────────────────────────────────┐${RESET}"
    printf "${BOLD}${MAGENTA}│${RESET} %-59s ${BOLD}${MAGENTA}│${RESET}\n" "$1"
    echo -e "${BOLD}${MAGENTA}└─────────────────────────────────────────────────────────────┘${RESET}\n"
}

print_section() {
    echo -e "\n${BOLD}${BLUE}▶ $1${RESET}"
}

#######################################
# Auto-fix functions
#######################################

auto_fix_shebang() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    local first_line
    first_line=$(head -n1 "$file")
    
    if [[ ! "$first_line" =~ ^#! ]]; then
        [[ "$VERBOSE" == "true" ]] && echo "  ${YELLOW}Fixing shebang in $file${RESET}"
        if [[ "$DRY_RUN" == "false" ]]; then
            # Backup original
            cp "$file" "${file}.bak"
            # Add shebang
            echo '#!/usr/bin/env bash' | cat - "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
            chmod +x "$file"
            echo "  ${GREEN}✓ Fixed shebang in $file${RESET}"
            return 0
        else
            echo "  ${CYAN}[DRY-RUN] Would fix shebang in $file${RESET}"
        fi
    fi
    return 1
}

auto_fix_permissions() {
    local file="$1"
    if [[ -f "$file" ]] && [[ ! -x "$file" ]]; then
        [[ "$VERBOSE" == "true" ]] && echo "  ${YELLOW}Fixing permissions for $file${RESET}"
        if [[ "$DRY_RUN" == "false" ]]; then
            chmod +x "$file"
            echo "  ${GREEN}✓ Made $file executable${RESET}"
            return 0
        else
            echo "  ${CYAN}[DRY-RUN] Would make $file executable${RESET}"
        fi
    fi
    return 1
}

auto_fix_submodules() {
    if [[ -f "${PROJECT_ROOT}/.gitmodules" ]]; then
        # Check if submodules are initialized
        if [[ ! -e "${PROJECT_ROOT}/third_party/spirv-cross/.git" ]] || \
           [[ ! -e "${PROJECT_ROOT}/third_party/glslang/.git" ]]; then
            [[ "$VERBOSE" == "true" ]] && echo "  ${YELLOW}Initializing git submodules${RESET}"
            if [[ "$DRY_RUN" == "false" ]]; then
                git -C "${PROJECT_ROOT}" submodule update --init --recursive --quiet
                echo "  ${GREEN}✓ Git submodules initialized${RESET}"
                return 0
            else
                echo "  ${CYAN}[DRY-RUN] Would initialize git submodules${RESET}"
            fi
        fi
    fi
    return 1
}

auto_install_optional_tools() {
    local missing_tools=()
    
    command -v shellcheck >/dev/null 2>&1 || missing_tools+=("shellcheck")
    command -v cppcheck >/dev/null 2>&1 || missing_tools+=("cppcheck")
    command -v clang-format >/dev/null 2>&1 || missing_tools+=("clang-format")
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo "  ${YELLOW}Optional tools not installed: ${missing_tools[*]}${RESET}"
        echo "  ${CYAN}Install with: sudo dnf install ${missing_tools[*]}${RESET}"
        
        # Only prompt in interactive mode with explicit confirmation
        if [[ "$CI_MODE" == "false" ]] && [[ "$DRY_RUN" == "false" ]] && [[ -t 0 ]]; then
            read -p "  Install now? (y/N): " -n 1 -r -t 5 2>/dev/null || REPLY=N
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                if command -v sudo >/dev/null 2>&1; then
                    sudo dnf install -y "${missing_tools[@]}"
                    echo "  ${GREEN}✓ Optional tools installed${RESET}"
                    return 0
                else
                    echo "  ${RED}✗ sudo not available${RESET}"
                fi
            fi
        fi
    fi
    return 1
}

run_auto_fixes() {
    if [[ "$AUTO_FIX" != "true" ]]; then
        return 0
    fi
    
    echo -e "\n${BOLD}${CYAN}Running Auto-Fix...${RESET}\n"
    
    local fixes_applied=0
    
    # Fix shebangs in scripts
    for script in "${PROJECT_ROOT}/scripts/"*.sh; do
        if auto_fix_shebang "$script"; then
            ((fixes_applied++))
        fi
    done
    
    # Fix permissions
    for script in "${PROJECT_ROOT}/scripts/"*.sh; do
        if auto_fix_permissions "$script"; then
            ((fixes_applied++))
        fi
    done
    
    # Fix submodules
    if auto_fix_submodules; then
        ((fixes_applied++))
    fi
    
    # Note optional tools (don't try to install automatically)
    local missing_tools=()
    command -v shellcheck >/dev/null 2>&1 || missing_tools+=("shellcheck")
    command -v cppcheck >/dev/null 2>&1 || missing_tools+=("cppcheck")
    command -v clang-format >/dev/null 2>&1 || missing_tools+=("clang-format")
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo "  ${YELLOW}ℹ Optional tools not installed: ${missing_tools[*]}${RESET}"
        echo "  ${CYAN}  Install with: sudo dnf install ${missing_tools[*]}${RESET}"
    fi
    
    if [[ $fixes_applied -gt 0 ]]; then
        echo -e "\n${GREEN}✓ Applied $fixes_applied fix(es)${RESET}\n"
    else
        echo -e "\n${CYAN}No fixes needed${RESET}\n"
    fi
}

print_test() {
    echo -n "  ${DIM}[TEST]${RESET} $1 ... "
}

print_pass() {
    echo -e "${GREEN}✓ PASS${RESET}"
    ((PASSED_TESTS++))
    ((TOTAL_TESTS++))
}

print_fail() {
    echo -e "${RED}✗ FAIL${RESET}"
    ((FAILED_TESTS++))
    ((TOTAL_TESTS++))
}

print_warn() {
    echo -e "${YELLOW}⚠ WARN${RESET}"
    ((WARNED_TESTS++))
    ((TOTAL_TESTS++))
}

print_skip() {
    echo -e "${YELLOW}○ SKIP${RESET}"
    ((SKIPPED_TESTS++))
    ((TOTAL_TESTS++))
}

log_result() {
    local category="${1:-Unknown}"
    local test_name="${2:-Unknown}"
    local result="${3:-UNKNOWN}"
    
    TEST_RESULTS+=("[$category] $test_name: $result")
    
    # Track failed tests separately
    if [[ "$result" == "FAIL" ]]; then
        FAILED_TEST_DETAILS+=("[$category] $test_name")
    fi
    
    case "$result" in
        PASS)
            CATEGORY_PASSED[$category]=$((${CATEGORY_PASSED[$category]:-0} + 1))
            ;;
        FAIL)
            CATEGORY_FAILED[$category]=$((${CATEGORY_FAILED[$category]:-0} + 1))
            ;;
        SKIP|WARN)
            CATEGORY_SKIPPED[$category]=$((${CATEGORY_SKIPPED[$category]:-0} + 1))
            ;;
    esac
}

#######################################
# Utility functions
#######################################

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

file_exists() {
    [[ -f "$1" ]]
}

dir_exists() {
    [[ -d "$1" ]]
}

run_command() {
    if [[ "$VERBOSE" == "true" ]]; then
        "$@"
    else
        "$@" >/dev/null 2>&1
    fi
}

#######################################
# Category 1: Environment & Dependencies
#######################################

test_environment() {
    print_header "CATEGORY 1: Environment & Dependencies"
    
    # Test 1: Required tools
    print_test "Checking required build tools"
    local required_tools=("git" "cmake" "ninja" "gcc" "g++")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command_exists "$tool"; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -eq 0 ]]; then
        print_pass
        log_result "Environment" "Required build tools" "PASS"
    else
        print_fail
        echo -e "    ${RED}Missing tools: ${missing_tools[*]}${RESET}"
        log_result "Environment" "Required build tools" "FAIL"
    fi
    
    # Test 2: Optional tools
    print_test "Checking optional analysis tools"
    local optional_tools=("shellcheck" "cppcheck" "jq" "clang-format")
    local found_optional=0
    
    for tool in "${optional_tools[@]}"; do
        if command_exists "$tool"; then
            ((found_optional++))
        fi
    done
    
    if [[ $found_optional -ge 2 ]]; then
        print_pass
        log_result "Environment" "Optional tools" "PASS"
    else
        print_warn
        echo -e "    ${YELLOW}Only $found_optional/4 optional tools found${RESET}"
        log_result "Environment" "Optional tools" "WARN"
    fi
    
    # Test 3: Git repository
    print_test "Checking git repository status"
    if [[ -d "${PROJECT_ROOT}/.git" ]] && git -C "${PROJECT_ROOT}" rev-parse --git-dir >/dev/null 2>&1; then
        print_pass
        log_result "Environment" "Git repository" "PASS"
    else
        print_fail
        log_result "Environment" "Git repository" "FAIL"
    fi
    
    # Test 4: Submodules
    print_test "Checking git submodules"
    if [[ -f "${PROJECT_ROOT}/.gitmodules" ]]; then
        # .git can be either a directory or a file (gitdir reference)
        if [[ -e "${PROJECT_ROOT}/third_party/spirv-cross/.git" ]] && \
           [[ -e "${PROJECT_ROOT}/third_party/glslang/.git" ]]; then
            print_pass
            log_result "Environment" "Git submodules" "PASS"
        else
            print_fail
            echo -e "    ${RED}Submodules not initialized. Run: git submodule update --init --recursive${RESET}"
            log_result "Environment" "Git submodules" "FAIL"
        fi
    else
        print_skip
        log_result "Environment" "Git submodules" "SKIP"
    fi
}

#######################################
# Category 2: File Structure Validation
#######################################

test_file_structure() {
    print_header "CATEGORY 2: File Structure Validation"
    
    # Test 1: Core source files
    print_test "Checking core source files"
    local core_files=(
        "layer/pyroveil.cpp"
        "layer/pyroveil_autodetect.cpp"
        "layer/pyroveil_autodetect.hpp"
        "compiler/compiler.cpp"
        "compiler/compiler.hpp"
        "CMakeLists.txt"
    )
    
    local missing_files=()
    for file in "${core_files[@]}"; do
        if ! file_exists "${PROJECT_ROOT}/${file}"; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -eq 0 ]]; then
        print_pass
        log_result "FileStructure" "Core source files" "PASS"
    else
        print_fail
        echo -e "    ${RED}Missing files: ${missing_files[*]}${RESET}"
        log_result "FileStructure" "Core source files" "FAIL"
    fi
    
    # Test 2: Scripts directory
    print_test "Checking scripts directory"
    local scripts=(
        "scripts/auto_install.sh"
        "scripts/run-full-validation.sh"
        "scripts/test-modules.sh"
        "scripts/test-logging.sh"
        "scripts/steam-game-scanner.sh"
        "scripts/pyroveil-auto-detect.sh"
    )
    
    local missing_scripts=()
    for script in "${scripts[@]}"; do
        if ! file_exists "${PROJECT_ROOT}/${script}"; then
            missing_scripts+=("$script")
        fi
    done
    
    if [[ ${#missing_scripts[@]} -eq 0 ]]; then
        print_pass
        log_result "FileStructure" "Scripts directory" "PASS"
    else
        print_fail
        log_result "FileStructure" "Scripts directory" "FAIL"
    fi
    
    # Test 3: Configuration files
    print_test "Checking configuration files"
    if file_exists "${PROJECT_ROOT}/database.json"; then
        print_pass
        log_result "FileStructure" "Configuration files" "PASS"
    else
        print_fail
        log_result "FileStructure" "Configuration files" "FAIL"
    fi
    
    # Test 4: Documentation
    print_test "Checking documentation files"
    local docs=("README.md" "LICENSE" "QUICKSTART.md")
    local missing_docs=()
    
    for doc in "${docs[@]}"; do
        if ! file_exists "${PROJECT_ROOT}/${doc}"; then
            missing_docs+=("$doc")
        fi
    done
    
    if [[ ${#missing_docs[@]} -eq 0 ]]; then
        print_pass
        log_result "FileStructure" "Documentation" "PASS"
    else
        print_warn
        log_result "FileStructure" "Documentation" "WARN"
    fi
}

#######################################
# Category 3: Shell Script Validation
#######################################

test_shell_scripts() {
    print_header "CATEGORY 3: Shell Script Validation"
    
    if ! command_exists shellcheck; then
        print_test "shellcheck not installed"
        print_skip
        log_result "ShellScripts" "shellcheck validation" "SKIP"
        return 0
    fi
    
    local scripts=(
        "scripts/auto_install.sh"
        "scripts/auto_rebuild.sh"
        "scripts/auto_uninstall.sh"
        "scripts/uninstall_pyroveil.sh"
        "scripts/common.sh"
        "scripts/pyroveil-auto-detect.sh"
        "scripts/pyroveil-update-database.sh"
        "scripts/steam-game-scanner.sh"
        "install-pyroveil.sh"
    )
    
    for script in "${scripts[@]}"; do
        local script_path="${PROJECT_ROOT}/${script}"
        
        if ! file_exists "$script_path"; then
            continue
        fi
        
        print_test "Validating $(basename "$script")"
        
        if shellcheck -x -S warning "$script_path" >/dev/null 2>&1; then
            print_pass
            log_result "ShellScripts" "$(basename "$script")" "PASS"
        else
            if [[ "$CI_MODE" == "true" ]]; then
                print_fail
                log_result "ShellScripts" "$(basename "$script")" "FAIL"
            else
                print_warn
                log_result "ShellScripts" "$(basename "$script")" "WARN"
            fi
        fi
    done
}

#######################################
# Category 4: JSON Validation
#######################################

test_json_files() {
    print_header "CATEGORY 4: JSON Configuration Validation"
    
    if ! command_exists jq; then
        print_test "jq not installed"
        print_skip
        log_result "JSON" "jq validation" "SKIP"
        return 0
    fi
    
    # Test 1: database.json
    print_test "Validating database.json"
    if jq empty "${PROJECT_ROOT}/database.json" >/dev/null 2>&1; then
        print_pass
        log_result "JSON" "database.json syntax" "PASS"
    else
        print_fail
        log_result "JSON" "database.json syntax" "FAIL"
    fi
    
    # Test 2: database.json structure
    print_test "Checking database.json structure"
    if jq -e '.version and .games and .metadata' "${PROJECT_ROOT}/database.json" >/dev/null 2>&1; then
        print_pass
        log_result "JSON" "database.json structure" "PASS"
    else
        print_fail
        log_result "JSON" "database.json structure" "FAIL"
    fi
    
    # Test 3: Game configurations
    print_test "Validating game configuration files"
    local config_errors=0
    
    while IFS= read -r -d '' config_file; do
        if ! jq empty "$config_file" >/dev/null 2>&1; then
            ((config_errors++))
        fi
    done < <(find "${PROJECT_ROOT}/hacks" -type f -name "*.json" -print0 2>/dev/null)
    
    if [[ $config_errors -eq 0 ]]; then
        print_pass
        log_result "JSON" "Game configs" "PASS"
    else
        print_fail
        echo -e "    ${RED}$config_errors invalid JSON files found${RESET}"
        log_result "JSON" "Game configs" "FAIL"
    fi
    
    # Test 4: Database game count
    print_test "Checking database game count"
    local game_count
    game_count=$(jq -r '.metadata.total_games' "${PROJECT_ROOT}/database.json" 2>/dev/null || echo "0")
    
    if [[ $game_count -ge 50 ]]; then
        print_pass
        echo -e "    ${GREEN}Found $game_count games in database${RESET}"
        log_result "JSON" "Game count validation" "PASS"
    else
        print_warn
        echo -e "    ${YELLOW}Only $game_count games in database (expected 50+)${RESET}"
        log_result "JSON" "Game count validation" "WARN"
    fi
}

#######################################
# Category 5: Build System Tests
#######################################

test_build_system() {
    print_header "CATEGORY 5: Build System Tests"
    
    if [[ "$SKIP_BUILD" == "true" ]]; then
        print_test "Build tests skipped (--skip-build)"
        print_skip
        log_result "Build" "CMake configuration" "SKIP"
        return 0
    fi
    
    # Test 1: CMake configuration
    print_test "Testing CMake configuration"
    
    rm -rf "${BUILD_DIR}"
    
    if run_command cmake -B "${BUILD_DIR}" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${HOME}/.local" \
        -S "${PROJECT_ROOT}"; then
        print_pass
        log_result "Build" "CMake configuration" "PASS"
    else
        print_fail
        log_result "Build" "CMake configuration" "FAIL"
        return 1
    fi
    
    # Test 2: Compilation
    print_test "Testing compilation (this may take a while)"
    
    if run_command ninja -C "${BUILD_DIR}" -j"$(nproc)"; then
        print_pass
        log_result "Build" "Compilation" "PASS"
    else
        print_fail
        log_result "Build" "Compilation" "FAIL"
        return 1
    fi
    
    # Test 3: Library file generated
    print_test "Checking generated library"
    
    if file_exists "${BUILD_DIR}/layer/libVkLayer_pyroveil_64.so"; then
        local lib_size
        lib_size=$(stat -c%s "${BUILD_DIR}/layer/libVkLayer_pyroveil_64.so")
        
        if [[ $lib_size -gt 1000000 ]]; then  # > 1 MB
            print_pass
            echo -e "    ${GREEN}Library size: $((lib_size / 1024 / 1024)) MB${RESET}"
            log_result "Build" "Library generation" "PASS"
        else
            print_warn
            echo -e "    ${YELLOW}Library size unusually small: $((lib_size / 1024)) KB${RESET}"
            log_result "Build" "Library generation" "WARN"
        fi
    else
        print_fail
        log_result "Build" "Library generation" "FAIL"
    fi
    
    # Test 4: Symbols check
    print_test "Checking library symbols"
    
    local lib_path="${BUILD_DIR}/layer/libVkLayer_pyroveil_64.so"
    
    if command_exists readelf && file_exists "${lib_path}"; then
        # Check for Vulkan layer negotiate function (modern layer interface)
        # Force English locale to avoid localization issues
        local symbol_output=$(LANG=C readelf --dyn-syms --wide "${lib_path}" 2>/dev/null | grep "Negotiate" || true)
        if [[ -n "$symbol_output" ]]; then
            print_pass
            log_result "Build" "Library symbols" "PASS"
        else
            print_fail
            log_result "Build" "Library symbols" "FAIL"
        fi
    else
        print_skip
        log_result "Build" "Library symbols" "SKIP"
    fi
}

#######################################
# Category 6: Module Tests
#######################################

test_modules() {
    print_header "CATEGORY 6: Module Tests"
    
    if file_exists "${SCRIPT_DIR}/test-modules.sh"; then
        print_test "Running module test suite"
        
        if run_command bash "${SCRIPT_DIR}/test-modules.sh"; then
            print_pass
            log_result "Modules" "Module test suite" "PASS"
        else
            print_warn
            log_result "Modules" "Module test suite" "WARN"
        fi
    else
        print_skip
        log_result "Modules" "Module test suite" "SKIP"
    fi
    
    # Test RapidJSON integration
    print_test "Checking RapidJSON integration"
    
    if grep -q '#include "rapidjson/document.h"' "${PROJECT_ROOT}/layer/pyroveil_autodetect.cpp"; then
        print_pass
        log_result "Modules" "RapidJSON integration" "PASS"
    else
        print_fail
        log_result "Modules" "RapidJSON integration" "FAIL"
    fi
    
    # Test Flatpak support
    print_test "Checking Flatpak Steam support"
    
    if grep -q "PRESSURE_VESSEL_APP_ID" "${PROJECT_ROOT}/layer/pyroveil_autodetect.cpp"; then
        print_pass
        log_result "Modules" "Flatpak support" "PASS"
    else
        print_fail
        log_result "Modules" "Flatpak support" "FAIL"
    fi
}

#######################################
# Category 7: Logging Tests
#######################################

test_logging() {
    print_header "CATEGORY 7: Logging Infrastructure"
    
    if file_exists "${SCRIPT_DIR}/test-logging.sh"; then
        print_test "Running logging test suite"
        
        if run_command bash "${SCRIPT_DIR}/test-logging.sh"; then
            print_pass
            log_result "Logging" "Logging test suite" "PASS"
        else
            print_warn
            log_result "Logging" "Logging test suite" "WARN"
        fi
    else
        print_skip
        log_result "Logging" "Logging test suite" "SKIP"
    fi
    
    # Test stderr logging
    print_test "Checking stderr logging calls"
    
    local log_count
    log_count=$(grep -r "fprintf(stderr" "${PROJECT_ROOT}/layer"/*.cpp | wc -l)
    
    if [[ $log_count -ge 20 ]]; then
        print_pass
        echo -e "    ${GREEN}Found $log_count logging calls${RESET}"
        log_result "Logging" "Logging calls" "PASS"
    else
        print_warn
        echo -e "    ${YELLOW}Only $log_count logging calls found${RESET}"
        log_result "Logging" "Logging calls" "WARN"
    fi
}

#######################################
# Category 8: Steam Detection Tests
#######################################

test_steam_detection() {
    print_header "CATEGORY 8: Steam Detection & Scanner"
    
    # Test 1: Steam scanner script
    print_test "Checking steam-game-scanner.sh"
    
    if file_exists "${SCRIPT_DIR}/steam-game-scanner.sh" && \
       [[ -x "${SCRIPT_DIR}/steam-game-scanner.sh" ]]; then
        print_pass
        log_result "Steam" "Scanner script" "PASS"
    else
        print_fail
        log_result "Steam" "Scanner script" "FAIL"
    fi
    
    # Test 2: Scanner help output
    print_test "Testing scanner help output"
    
    if bash "${SCRIPT_DIR}/steam-game-scanner.sh" --help >/dev/null 2>&1; then
        print_pass
        log_result "Steam" "Scanner help" "PASS"
    else
        print_fail
        log_result "Steam" "Scanner help" "FAIL"
    fi
    
    # Test 3: Auto-detect script
    print_test "Checking pyroveil-auto-detect.sh"
    
    if file_exists "${SCRIPT_DIR}/pyroveil-auto-detect.sh" && \
       [[ -x "${SCRIPT_DIR}/pyroveil-auto-detect.sh" ]]; then
        print_pass
        log_result "Steam" "Auto-detect script" "PASS"
    else
        print_fail
        log_result "Steam" "Auto-detect script" "FAIL"
    fi
    
    # Test 4: Database update script
    print_test "Checking pyroveil-update-database.sh"
    
    if file_exists "${SCRIPT_DIR}/pyroveil-update-database.sh" && \
       [[ -x "${SCRIPT_DIR}/pyroveil-update-database.sh" ]]; then
        print_pass
        log_result "Steam" "Update database script" "PASS"
    else
        print_fail
        log_result "Steam" "Update database script" "FAIL"
    fi
}

#######################################
# Category 9: Documentation Tests
#######################################

test_documentation() {
    print_header "CATEGORY 9: Documentation Validation"
    
    # Test 1: README completeness
    print_test "Checking README.md completeness"
    
    local required_sections=("Installation" "Usage" "Features" "Supported Games")
    local missing_sections=()
    
    for section in "${required_sections[@]}"; do
        if ! grep -qi "$section" "${PROJECT_ROOT}/README.md"; then
            missing_sections+=("$section")
        fi
    done
    
    if [[ ${#missing_sections[@]} -eq 0 ]]; then
        print_pass
        log_result "Documentation" "README sections" "PASS"
    else
        print_warn
        log_result "Documentation" "README sections" "WARN"
    fi
    
    # Test 2: IMPROVEMENTS.md
    print_test "Checking IMPROVEMENTS.md"
    
    if file_exists "${PROJECT_ROOT}/IMPROVEMENTS.md"; then
        print_pass
        log_result "Documentation" "IMPROVEMENTS.md" "PASS"
    else
        print_warn
        log_result "Documentation" "IMPROVEMENTS.md" "WARN"
    fi
    
    # Test 3: License file
    print_test "Checking LICENSE file"
    
    if file_exists "${PROJECT_ROOT}/LICENSE"; then
        print_pass
        log_result "Documentation" "LICENSE" "PASS"
    else
        print_fail
        log_result "Documentation" "LICENSE" "FAIL"
    fi
}

#######################################
# Category 10: Integration Tests
#######################################

test_integration() {
    print_header "CATEGORY 10: Integration Tests"
    
    # Test 1: Full validation script
    print_test "Checking run-full-validation.sh"
    
    if file_exists "${SCRIPT_DIR}/run-full-validation.sh"; then
        print_pass
        log_result "Integration" "Full validation script" "PASS"
    else
        print_fail
        log_result "Integration" "Full validation script" "FAIL"
    fi
    
    # Test 2: CI validation
    print_test "Checking ci-validate.sh"
    
    if file_exists "${SCRIPT_DIR}/ci-validate.sh"; then
        print_pass
        log_result "Integration" "CI validation script" "PASS"
    else
        print_warn
        log_result "Integration" "CI validation script" "WARN"
    fi
    
    # Test 3: Installation script
    print_test "Checking install-pyroveil.sh"
    
    if file_exists "${PROJECT_ROOT}/install-pyroveil.sh" && \
       [[ -x "${PROJECT_ROOT}/install-pyroveil.sh" ]]; then
        print_pass
        log_result "Integration" "Installation script" "PASS"
    else
        print_fail
        log_result "Integration" "Installation script" "FAIL"
    fi
}

#######################################
# Generate Report
#######################################

generate_report() {
    local end_time
    local duration
    
    end_time=$(date +%s)
    duration=$((end_time - START_TIME))
    
    print_header "TEST SUMMARY"
    
    echo -e "${BOLD}Test Execution Summary:${RESET}"
    echo -e "  Total Tests:    ${BOLD}$TOTAL_TESTS${RESET}"
    echo -e "  ${GREEN}✓ Passed:${RESET}       ${GREEN}$PASSED_TESTS${RESET}"
    echo -e "  ${RED}✗ Failed:${RESET}       ${RED}$FAILED_TESTS${RESET}"
    echo -e "  ${YELLOW}⚠ Warnings:${RESET}     ${YELLOW}$WARNED_TESTS${RESET}"
    echo -e "  ${YELLOW}○ Skipped:${RESET}      ${YELLOW}$SKIPPED_TESTS${RESET}"
    echo ""
    echo -e "${BOLD}Duration:${RESET} ${duration}s"
    echo ""
    
    # Category breakdown
    echo -e "${BOLD}Results by Category:${RESET}"
    for category in Environment FileStructure ShellScripts JSON Build Modules Logging Steam Documentation Integration; do
        local passed=${CATEGORY_PASSED[$category]:-0}
        local failed=${CATEGORY_FAILED[$category]:-0}
        local skipped=${CATEGORY_SKIPPED[$category]:-0}
        local total=$((passed + failed + skipped))
        
        if [[ $total -gt 0 ]]; then
            printf "  %-20s ${GREEN}%2d${RESET} / ${RED}%2d${RESET} / ${YELLOW}%2d${RESET} (P/F/S)\n" \
                   "$category:" "$passed" "$failed" "$skipped"
        fi
    done
    echo ""
    
    # Failed tests details
    if [[ $FAILED_TESTS -gt 0 ]]; then
        echo -e "${BOLD}${RED}Failed Tests:${RESET}"
        for failed_test in "${FAILED_TEST_DETAILS[@]}"; do
            echo -e "  ${RED}✗${RESET} $failed_test"
        done
        echo ""
    fi
    
    # Final verdict
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${BOLD}${GREEN}╔═══════════════════════════════════════════════════════════════╗"
        echo -e "║                                                               ║"
        echo -e "║              ✓✓✓ ALL TESTS PASSED ✓✓✓                        ║"
        echo -e "║                                                               ║"
        echo -e "╚═══════════════════════════════════════════════════════════════╝${RESET}"
    else
        echo -e "${BOLD}${RED}╔═══════════════════════════════════════════════════════════════╗"
        echo -e "║                                                               ║"
        echo -e "║              ✗✗✗ TESTS FAILED ✗✗✗                            ║"
        echo -e "║                                                               ║"
        echo -e "╚═══════════════════════════════════════════════════════════════╝${RESET}"
    fi
    
    # Save report to file if requested
    if [[ -n "$REPORT_FILE" ]]; then
        {
            echo "PyroVeil Comprehensive Test Report"
            echo "Generated: $(date)"
            echo ""
            echo "Summary:"
            echo "  Total: $TOTAL_TESTS, Passed: $PASSED_TESTS, Failed: $FAILED_TESTS, Warned: $WARNED_TESTS, Skipped: $SKIPPED_TESTS"
            echo ""
            echo "Test Results:"
            printf '%s\n' "${TEST_RESULTS[@]}"
        } > "$REPORT_FILE"
        
        echo -e "\n${GREEN}Report saved to: $REPORT_FILE${RESET}"
    fi
}

#######################################
# Parse command-line arguments
#######################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --quick)
                QUICK_MODE=true
                SKIP_BUILD=true
                shift
                ;;
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --ci)
                CI_MODE=true
                shift
                ;;
            --report)
                REPORT_FILE="$2"
                shift 2
                ;;
            --auto-fix)
                AUTO_FIX=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                AUTO_FIX=true
                shift
                ;;
            --help|-h)
                cat <<EOF
Usage: $0 [options]

Options:
  --quick         Fast checks only (skip build, static analysis)
  --skip-build    Skip compilation tests
  --verbose       Enable verbose output
  --ci            CI mode (strict error checking)
  --report FILE   Save detailed report to FILE
  --auto-fix      Automatically fix common issues
  --dry-run       Show what would be fixed (implies --auto-fix)
  --help, -h      Show this help message

EOF
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${RESET}"
                exit 1
                ;;
        esac
    done
}

#######################################
# Self-Test & Unit Tests
#######################################

run_self_tests() {
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
        # Script is being sourced, run unit tests
        echo "Running unit tests for comprehensive-test.sh..."
        
        local test_count=0
        local test_passed=0
        
        # Test 1: command_exists function
        ((test_count++))
        if command_exists bash; then
            echo "✓ Test $test_count: command_exists works for existing command"
            ((test_passed++))
        else
            echo "✗ Test $test_count: command_exists failed"
        fi
        
        # Test 2: file_exists function
        ((test_count++))
        if file_exists "${BASH_SOURCE[0]}"; then
            echo "✓ Test $test_count: file_exists works for existing file"
            ((test_passed++))
        else
            echo "✗ Test $test_count: file_exists failed"
        fi
        
        # Test 3: dir_exists function
        ((test_count++))
        if dir_exists "${SCRIPT_DIR}"; then
            echo "✓ Test $test_count: dir_exists works for existing directory"
            ((test_passed++))
        else
            echo "✗ Test $test_count: dir_exists failed"
        fi
        
        # Test 4: Test counter functions
        ((test_count++))
        local old_total=$TOTAL_TESTS
        print_pass >/dev/null
        if [[ $TOTAL_TESTS -eq $((old_total + 1)) ]]; then
            echo "✓ Test $test_count: print_pass increments counters"
            ((test_passed++))
            ((TOTAL_TESTS--))  # Restore
            ((PASSED_TESTS--))
        else
            echo "✗ Test $test_count: print_pass counter failed"
        fi
        
        # Test 5: Auto-fix dry-run mode
        ((test_count++))
        local old_dry_run=$DRY_RUN
        DRY_RUN=true
        if auto_fix_shebang "/nonexistent/file" >/dev/null 2>&1; then
            echo "✓ Test $test_count: auto_fix_shebang handles missing files"
            ((test_passed++))
        else
            echo "✓ Test $test_count: auto_fix_shebang handles missing files (expected failure)"
            ((test_passed++))
        fi
        DRY_RUN=$old_dry_run
        
        echo ""
        echo "Unit Tests: $test_passed/$test_count passed"
        
        if [[ $test_passed -eq $test_count ]]; then
            echo "✓✓✓ ALL UNIT TESTS PASSED ✓✓✓"
            return 0
        else
            echo "✗✗✗ SOME UNIT TESTS FAILED ✗✗✗"
            return 1
        fi
    fi
    return 0
}

#######################################
# Performance Optimization
#######################################

# Cache for expensive operations
declare -A CACHE

cache_get() {
    local key="$1"
    echo "${CACHE[$key]:-}"
}

cache_set() {
    local key="$1"
    local value="$2"
    CACHE[$key]="$value"
}

# Optimized command check with caching
command_exists_cached() {
    local cmd="$1"
    local cached
    cached=$(cache_get "cmd_$cmd")
    
    if [[ -n "$cached" ]]; then
        [[ "$cached" == "1" ]]
        return $?
    fi
    
    if command -v "$cmd" >/dev/null 2>&1; then
        cache_set "cmd_$cmd" "1"
        return 0
    else
        cache_set "cmd_$cmd" "0"
        return 1
    fi
}

# Parallel test execution helper
run_parallel_tests() {
    local -a test_functions=("$@")
    local -a pids=()
    
    for test_func in "${test_functions[@]}"; do
        if command -v "$test_func" >/dev/null 2>&1; then
            $test_func &
            pids+=($!)
        fi
    done
    
    # Wait for all parallel tests
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
}

#######################################
# Main execution
#######################################

main() {
    parse_arguments "$@"
    
    print_banner
    
    # Run auto-fixes if requested
    run_auto_fixes
    
    # Run all test categories
    test_environment
    test_file_structure
    test_shell_scripts
    test_json_files
    
    if [[ "$QUICK_MODE" != "true" ]]; then
        test_build_system
    fi
    
    test_modules
    test_logging
    test_steam_detection
    test_documentation
    test_integration
    
    # Generate summary report
    generate_report
    
    # Exit with appropriate code
    if [[ $FAILED_TESTS -gt 0 ]]; then
        exit 1
    elif [[ "$CI_MODE" == "true" ]] && [[ $WARNED_TESTS -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

main "$@"
