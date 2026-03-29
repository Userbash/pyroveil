#!/usr/bin/env bash
#
# run-full-validation.sh - Comprehensive validation suite for PyroVeil
#
# This script performs a complete health check of the PyroVeil project:
# - Shell script syntax validation (shellcheck)
# - C++ code compilation and linking
# - Static code analysis (cppcheck, clang-tidy if available)
# - Unit tests execution (if tests are built)
# - Configuration file validation (JSON syntax)
# - Documentation checks
# - Logging/debug output verification
#
# Exit codes:
#   0 - All checks passed
#   1 - One or more checks failed
#   2 - Critical dependency missing

set -euo pipefail

# ANSI color codes for output formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly RESET='\033[0m'

# Project root directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly BUILD_DIR="${PROJECT_ROOT}/build"

# Counters for test results
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# ============================================================================
# Utility Functions
# ============================================================================

print_header() {
    echo -e "\n${BOLD}${CYAN}========================================${RESET}"
    echo -e "${BOLD}${CYAN}$1${RESET}"
    echo -e "${BOLD}${CYAN}========================================${RESET}\n"
}

print_step() {
    echo -e "${BLUE}[STEP]${RESET} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${RESET} $1"
    ((PASSED_TESTS++))
}

print_failure() {
    echo -e "${RED}[✗]${RESET} $1"
    ((FAILED_TESTS++))
}

print_warning() {
    echo -e "${YELLOW}[!]${RESET} $1"
}

print_skip() {
    echo -e "${YELLOW}[SKIP]${RESET} $1"
    ((SKIPPED_TESTS++))
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ============================================================================
# Validation Functions
# ============================================================================

# Check 1: Validate shell scripts with shellcheck
validate_shell_scripts() {
    print_header "Shell Script Validation (shellcheck)"
    
    if ! command_exists shellcheck; then
        print_skip "shellcheck not installed, skipping shell script validation"
        print_warning "Install: sudo dnf install shellcheck (Fedora/Bazzite)"
        return 0
    fi
    
    local shell_scripts=(
        "scripts/auto_install.sh"
        "scripts/auto_rebuild.sh"
        "scripts/auto_uninstall.sh"
        "scripts/uninstall_pyroveil.sh"
        "scripts/common.sh"
        "install-pyroveil.sh"
        "install-pyroveil-acshadows.sh"
    )
    
    local failed=0
    for script in "${shell_scripts[@]}"; do
        local full_path="${PROJECT_ROOT}/${script}"
        if [[ ! -f "${full_path}" ]]; then
            print_warning "Script not found: ${script}"
            continue
        fi
        
        print_step "Checking ${script}..."
        if shellcheck -x -S warning "${full_path}"; then
            print_success "${script}: syntax OK"
        else
            print_failure "${script}: shellcheck failed"
            failed=1
        fi
    done
    
    return ${failed}
}

# Check 2: Validate JSON configuration files
validate_json_configs() {
    print_header "JSON Configuration Validation"
    
    if ! command_exists jq; then
        print_skip "jq not installed, skipping JSON validation"
        print_warning "Install: sudo dnf install jq (Fedora/Bazzite)"
        return 0
    fi
    
    local json_files=(
        "hacks/ac-shadows-nvidia-570-stable/pyroveil.json"
        "hacks/ffvii-rebirth-nvidia/pyroveil.json"
        "hacks/monster-hunter-wilds-benchmark-nv/pyroveil.json"
        "hacks/roadcraft-nvidia-570-stable/pyroveil.json"
        "hacks/surviving-mars-relaunched-nv-580-stable/pyroveil.json"
        "database.json"
    )
    
    local failed=0
    for json_file in "${json_files[@]}"; do
        local full_path="${PROJECT_ROOT}/${json_file}"
        if [[ ! -f "${full_path}" ]]; then
            print_warning "JSON file not found: ${json_file}"
            continue
        fi
        
        print_step "Validating ${json_file}..."
        if jq empty "${full_path}" 2>/dev/null; then
            print_success "${json_file}: valid JSON"
        else
            print_failure "${json_file}: INVALID JSON"
            failed=1
        fi
    done
    
    return ${failed}
}

# Check 3: Build system validation
validate_build_system() {
    print_header "Build System Validation (CMake + Compilation)"
    
    if ! command_exists cmake; then
        print_failure "cmake not found - cannot validate build system"
        return 1
    fi
    
    # Clean build to ensure fresh compilation
    print_step "Cleaning previous build..."
    rm -rf "${BUILD_DIR}"
    mkdir -p "${BUILD_DIR}"
    
    # Configure with CMake
    print_step "Configuring with CMake..."
    cd "${BUILD_DIR}"
    if cmake "${PROJECT_ROOT}" -DCMAKE_BUILD_TYPE=Debug; then
        print_success "CMake configuration: OK"
    else
        print_failure "CMake configuration: FAILED"
        return 1
    fi
    
    # Build
    print_step "Compiling project..."
    if make -j"$(nproc)" 2>&1 | tee build.log; then
        print_success "Compilation: OK"
    else
        print_failure "Compilation: FAILED"
        echo -e "\n${RED}Build log (last 50 lines):${RESET}"
        tail -n 50 build.log
        return 1
    fi
    
    # Verify output files
    print_step "Verifying build artifacts..."
    if [[ -f "${BUILD_DIR}/layer/libVkLayer_pyroveil_64.so" ]]; then
        local size=$(stat -f%z "${BUILD_DIR}/layer/libVkLayer_pyroveil_64.so" 2>/dev/null || stat -c%s "${BUILD_DIR}/layer/libVkLayer_pyroveil_64.so")
        print_success "libVkLayer_pyroveil_64.so: $(numfmt --to=iec-i --suffix=B ${size})"
    else
        print_failure "libVkLayer_pyroveil_64.so: NOT FOUND"
        return 1
    fi
    
    return 0
}

# Check 4: Static code analysis with cppcheck
validate_static_analysis() {
    print_header "Static Code Analysis (cppcheck)"
    
    if ! command_exists cppcheck; then
        print_skip "cppcheck not installed, skipping static analysis"
        print_warning "Install: sudo dnf install cppcheck (Fedora/Bazzite)"
        return 0
    fi
    
    local cpp_files=(
        "layer/pyroveil.cpp"
        "layer/pyroveil_autodetect.cpp"
        "compiler/compiler.cpp"
        "layer-util/dispatch_helper.cpp"
        "layer-util/path_utils.cpp"
        "layer-util/string_helpers.cpp"
    )
    
    print_step "Running cppcheck on C++ sources..."
    
    local failed=0
    for cpp_file in "${cpp_files[@]}"; do
        local full_path="${PROJECT_ROOT}/${cpp_file}"
        if [[ ! -f "${full_path}" ]]; then
            print_warning "C++ file not found: ${cpp_file}"
            continue
        fi
        
        echo "  Analyzing ${cpp_file}..."
        if cppcheck --enable=warning,style,performance,portability \
                    --suppress=missingIncludeSystem \
                    --quiet \
                    --std=c++14 \
                    "${full_path}" 2>&1 | grep -v "^Checking"; then
            print_warning "${cpp_file}: has issues (see above)"
        else
            print_success "${cpp_file}: clean"
        fi
    done
    
    return 0  # Non-critical warnings don't fail the build
}

# Check 5: Verify documentation completeness
validate_documentation() {
    print_header "Documentation Validation"
    
    local required_docs=(
        "README.md"
        "QUICKSTART.md"
        "LICENSE"
        "CMakeLists.txt"
    )
    
    local failed=0
    for doc in "${required_docs[@]}"; do
        local full_path="${PROJECT_ROOT}/${doc}"
        if [[ -f "${full_path}" ]]; then
            local lines=$(wc -l < "${full_path}")
            print_success "${doc}: exists (${lines} lines)"
        else
            print_failure "${doc}: MISSING"
            failed=1
        fi
    done
    
    # Check for minimum README content
    print_step "Checking README.md content..."
    local readme="${PROJECT_ROOT}/README.md"
    local required_sections=(
        "## Features"
        "## Installation"
        "## Usage"
        "## Supported Games"
    )
    
    for section in "${required_sections[@]}"; do
        if grep -q "^${section}" "${readme}"; then
            print_success "README section found: ${section}"
        else
            print_warning "README section missing: ${section}"
        fi
    done
    
    return ${failed}
}

# Check 6: Test auto-detection module
validate_autodetect_module() {
    print_header "Auto-Detection Module Test"
    
    local lib_path="${BUILD_DIR}/layer/libVkLayer_pyroveil_64.so"
    if [[ ! -f "${lib_path}" ]]; then
        print_skip "Library not built, skipping auto-detect tests"
        return 0
    fi
    
    print_step "Checking for exported symbols..."
    if nm -D "${lib_path}" | grep -q "autoDetectConfigPath"; then
        print_success "autoDetectConfigPath symbol exported"
    else
        print_warning "autoDetectConfigPath symbol not found (may be optimized out)"
    fi
    
    print_step "Verifying library dependencies..."
    if ldd "${lib_path}" | grep -q "not found"; then
        print_failure "Missing library dependencies:"
        ldd "${lib_path}" | grep "not found"
        return 1
    else
        print_success "All library dependencies satisfied"
    fi
    
    return 0
}

# Check 7: Verify logging/debug infrastructure
validate_logging() {
    print_header "Logging Infrastructure Validation"
    
    local cpp_files=(
        "layer/pyroveil_autodetect.cpp"
        "layer/pyroveil.cpp"
    )
    
    print_step "Checking for logging statements..."
    local log_count=0
    for cpp_file in "${cpp_files[@]}"; do
        local full_path="${PROJECT_ROOT}/${cpp_file}"
        if [[ -f "${full_path}" ]]; then
            local count=$(grep -c 'fprintf(stderr, "pyroveil:' "${full_path}" || echo "0")
            log_count=$((log_count + count))
            print_success "${cpp_file}: ${count} logging statements"
        fi
    done
    
    if [[ ${log_count} -gt 0 ]]; then
        print_success "Total logging statements: ${log_count}"
    else
        print_warning "No logging statements found (may need debug output)"
    fi
    
    # Test environment variable handling
    print_step "Testing environment variable detection..."
    local test_vars=(
        "PYROVEIL_CONFIG"
        "PYROVEIL_CONFIG_BASE"
        "PYROVEIL_DATABASE"
        "SteamAppId"
        "STEAM_COMPAT_APP_ID"
    )
    
    for var in "${test_vars[@]}"; do
        if grep -q "getenv(\"${var}\")" "${PROJECT_ROOT}/layer/pyroveil_autodetect.cpp"; then
            print_success "Environment variable handled: ${var}"
        else
            print_warning "Environment variable not found in code: ${var}"
        fi
    done
    
    return 0
}

# Check 8: Unit tests (if available)
validate_unit_tests() {
    print_header "Unit Tests Execution"
    
    # Check if tests are built
    if [[ ! -d "${BUILD_DIR}/tests" ]]; then
        print_skip "No unit tests found (not yet implemented)"
        print_warning "Consider adding Google Test or Catch2 framework"
        return 0
    fi
    
    print_step "Running unit tests..."
    if ctest --test-dir "${BUILD_DIR}" --output-on-failure; then
        print_success "All unit tests passed"
    else
        print_failure "Some unit tests failed"
        return 1
    fi
    
    return 0
}

# Check 9: Installation procedure validation
validate_installation() {
    print_header "Installation Procedure Validation"
    
    print_step "Checking install targets..."
    cd "${BUILD_DIR}"
    
    # Dry-run installation to check for issues
    if make install DESTDIR="${BUILD_DIR}/install-test" >/dev/null 2>&1; then
        print_success "Installation target: OK"
        
        # Verify installed files
        local expected_files=(
            "usr/local/lib/libVkLayer_pyroveil_64.so"
            "usr/local/share/vulkan/implicit_layer.d/VkLayer_pyroveil_64.json"
        )
        
        for file in "${expected_files[@]}"; do
            if [[ -f "${BUILD_DIR}/install-test/${file}" ]]; then
                print_success "Installed file: ${file}"
            else
                print_warning "Expected file not installed: ${file}"
            fi
        done
        
        # Cleanup
        rm -rf "${BUILD_DIR}/install-test"
    else
        print_failure "Installation target: FAILED"
        return 1
    fi
    
    return 0
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    print_header "PyroVeil Comprehensive Validation Suite"
    echo -e "Project: ${BOLD}${PROJECT_ROOT}${RESET}"
    echo -e "Date: ${BOLD}$(date '+%Y-%m-%d %H:%M:%S')${RESET}"
    echo -e "User: ${BOLD}${USER}${RESET}"
    
    # Track overall result
    local overall_result=0
    
    # Run all validation checks
    validate_shell_scripts || overall_result=1
    validate_json_configs || overall_result=1
    validate_build_system || overall_result=1
    validate_static_analysis || overall_result=1
    validate_documentation || overall_result=1
    validate_autodetect_module || overall_result=1
    validate_logging || overall_result=1
    validate_unit_tests || overall_result=1
    validate_installation || overall_result=1
    
    # Print summary
    print_header "Validation Summary"
    echo -e "${GREEN}Passed:${RESET} ${PASSED_TESTS}"
    echo -e "${RED}Failed:${RESET} ${FAILED_TESTS}"
    echo -e "${YELLOW}Skipped:${RESET} ${SKIPPED_TESTS}"
    echo ""
    
    if [[ ${overall_result} -eq 0 ]]; then
        echo -e "${BOLD}${GREEN}✓ ALL VALIDATION CHECKS PASSED${RESET}"
        echo -e "${GREEN}PyroVeil is ready for deployment!${RESET}"
        return 0
    else
        echo -e "${BOLD}${RED}✗ VALIDATION FAILED${RESET}"
        echo -e "${RED}Please fix the issues above before deploying.${RESET}"
        return 1
    fi
}

# Run main function
main "$@"
