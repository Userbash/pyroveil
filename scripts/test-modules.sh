#!/usr/bin/env bash
#
# test-modules.sh - Test individual PyroVeil modules
#
# This script performs targeted testing of specific modules:
# - Auto-detection module
# - JSON parser
# - Configuration loader
# - Shader compiler
# - Layer utilities

set -uo pipefail  # Removed -e to allow test failures without script exit

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly BUILD_DIR="${PROJECT_ROOT}/build"

# ANSI colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly RESET='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

print_module() {
    echo -e "\n${BLUE}========================================${RESET}"
    echo -e "${BLUE}Testing Module: $1${RESET}"
    echo -e "${BLUE}========================================${RESET}\n"
}

print_test() {
    echo -e "${YELLOW}[TEST]${RESET} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${RESET} $1"
    ((TESTS_PASSED++))
}

print_fail() {
    echo -e "${RED}[FAIL]${RESET} $1"
    ((TESTS_FAILED++))
}

# ============================================================================
# Module 1: Auto-Detection Module
# ============================================================================
test_autodetect_module() {
    print_module "Auto-Detection Module"
    
    local autodetect_cpp="${PROJECT_ROOT}/layer/pyroveil_autodetect.cpp"
    local autodetect_hpp="${PROJECT_ROOT}/layer/pyroveil_autodetect.hpp"
    
    # Test 1: File existence
    print_test "Checking module files exist"
    if [[ -f "${autodetect_cpp}" ]] && [[ -f "${autodetect_hpp}" ]]; then
        print_pass "Module files found"
    else
        print_fail "Module files missing"
        return 1
    fi
    
    # Test 2: Function declarations
    print_test "Checking function declarations"
    if grep -q "autoDetectConfigPath()" "${autodetect_hpp}"; then
        print_pass "autoDetectConfigPath() declared"
    else
        print_fail "autoDetectConfigPath() not found"
    fi
    
    # Test 3: Required functions present
    print_test "Checking helper functions"
    local functions=(
        "getSteamAppId"
        "getProcessName"
        "getExecutablePath"
        "getDatabasePath"
        "findConfigByAppId"
    )
    
    for func in "${functions[@]}"; do
        if grep -q "${func}" "${autodetect_cpp}"; then
            print_pass "Function found: ${func}()"
        else
            print_fail "Function missing: ${func}()"
        fi
    done
    
    # Test 4: Namespace structure
    print_test "Checking namespace structure"
    if grep -q "namespace PyroVeil" "${autodetect_cpp}" && \
       grep -q "namespace AutoDetect" "${autodetect_cpp}"; then
        print_pass "Correct namespace structure"
    else
        print_fail "Namespace structure incorrect"
    fi
    
    return 0
}

# ============================================================================
# Module 2: Configuration Loader (JSON Parser)
# ============================================================================
test_json_parser_module() {
    print_module "JSON Configuration Parser"
    
    # Test 1: Check JSON files validity
    print_test "Validating game configuration files"
    
    local json_files=(
        "hacks/ac-shadows-nvidia-570-stable/pyroveil.json"
        "hacks/ffvii-rebirth-nvidia/pyroveil.json"
        "database.json"
    )
    
    if command -v jq >/dev/null 2>&1; then
        for json_file in "${json_files[@]}"; do
            local full_path="${PROJECT_ROOT}/${json_file}"
            if [[ -f "${full_path}" ]]; then
                if jq empty "${full_path}" 2>/dev/null; then
                    print_pass "Valid JSON: ${json_file}"
                else
                    print_fail "Invalid JSON: ${json_file}"
                fi
            fi
        done
    else
        print_fail "jq not installed, skipping JSON validation"
    fi
    
    # Test 2: Check for RapidJSON usage in code
    print_test "Checking RapidJSON integration"
    if grep -r "#include.*rapidjson" "${PROJECT_ROOT}/layer/" >/dev/null 2>&1; then
        print_pass "RapidJSON headers included"
    else
        print_fail "RapidJSON not used"
    fi
    
    return 0
}

# ============================================================================
# Module 3: Shader Compiler Module
# ============================================================================
test_shader_compiler_module() {
    print_module "Shader Compiler Module"
    
    local compiler_cpp="${PROJECT_ROOT}/compiler/compiler.cpp"
    local compiler_hpp="${PROJECT_ROOT}/compiler/compiler.hpp"
    
    # Test 1: Module files exist
    print_test "Checking compiler module files"
    if [[ -f "${compiler_cpp}" ]] && [[ -f "${compiler_hpp}" ]]; then
        print_pass "Compiler module files found"
    else
        print_fail "Compiler module files missing"
        return 1
    fi
    
    # Test 2: Check for compiler library build
    print_test "Checking compiler library build"
    if [[ -f "${BUILD_DIR}/compiler/libglsl-compiler.a" ]]; then
        print_pass "Compiler library built"
    else
        print_fail "Compiler library not built"
    fi
    
    # Test 3: Check GLSL/SPIRV includes
    print_test "Checking GLSL/SPIRV support"
    if grep -q "glslang" "${compiler_cpp}" && \
       grep -q "spirv" "${compiler_cpp}"; then
        print_pass "GLSL/SPIRV support detected"
    else
        print_fail "GLSL/SPIRV support missing"
    fi
    
    return 0
}

# ============================================================================
# Module 4: Layer Utilities
# ============================================================================
test_layer_utils_module() {
    print_module "Layer Utilities Module"
    
    local util_files=(
        "layer-util/dispatch_helper.cpp"
        "layer-util/path_utils.cpp"
        "layer-util/string_helpers.cpp"
    )
    
    # Test 1: Utility files exist
    print_test "Checking utility module files"
    local missing=0
    for util_file in "${util_files[@]}"; do
        if [[ -f "${PROJECT_ROOT}/${util_file}" ]]; then
            print_pass "Found: ${util_file}"
        else
            print_fail "Missing: ${util_file}"
            missing=1
        fi
    done
    
    # Test 2: Check utility library build
    print_test "Checking utility library build"
    if [[ -f "${BUILD_DIR}/layer-util/liblayer-util.a" ]]; then
        print_pass "Utility library built"
    else
        print_fail "Utility library not built"
    fi
    
    return 0
}

# ============================================================================
# Module 5: Main Vulkan Layer
# ============================================================================
test_vulkan_layer_module() {
    print_module "Vulkan Layer Module"
    
    local layer_cpp="${PROJECT_ROOT}/layer/pyroveil.cpp"
    local layer_so="${BUILD_DIR}/layer/libVkLayer_pyroveil_64.so"
    local layer_json="${BUILD_DIR}/layer/VkLayer_pyroveil_64.json"
    
    # Test 1: Main layer file exists
    print_test "Checking main layer source"
    if [[ -f "${layer_cpp}" ]]; then
        print_pass "Main layer source found"
    else
        print_fail "Main layer source missing"
        return 1
    fi
    
    # Test 2: Layer library built
    print_test "Checking layer library build"
    if [[ -f "${layer_so}" ]]; then
        local size=$(stat -c%s "${layer_so}" 2>/dev/null || stat -f%z "${layer_so}" 2>/dev/null)
        print_pass "Layer library built ($(numfmt --to=iec-i --suffix=B ${size}))"
    else
        print_fail "Layer library not built"
    fi
    
    # Test 3: Layer manifest exists
    print_test "Checking layer manifest (JSON)"
    if [[ -f "${layer_json}" ]]; then
        print_pass "Layer manifest found"
        if command -v jq >/dev/null 2>&1; then
            if jq empty "${layer_json}" 2>/dev/null; then
                print_pass "Layer manifest: valid JSON"
            else
                print_fail "Layer manifest: invalid JSON"
            fi
        fi
    else
        print_fail "Layer manifest missing"
    fi
    
    # Test 4: Check Vulkan exports
    print_test "Checking Vulkan API exports"
    if nm -D "${layer_so}" 2>/dev/null | grep -q "vkGetInstanceProcAddr"; then
        print_pass "vkGetInstanceProcAddr exported"
    else
        print_fail "vkGetInstanceProcAddr not found"
    fi
    
    return 0
}

# ============================================================================
# Module 6: Installation Scripts
# ============================================================================
test_installation_scripts() {
    print_module "Installation Scripts"
    
    local install_scripts=(
        "scripts/auto_install.sh"
        "install-pyroveil.sh"
        "install-pyroveil-acshadows.sh"
    )
    
    # Test 1: Scripts exist and are executable
    print_test "Checking installation scripts"
    for script in "${install_scripts[@]}"; do
        local full_path="${PROJECT_ROOT}/${script}"
        if [[ -f "${full_path}" ]]; then
            if [[ -x "${full_path}" ]]; then
                print_pass "Executable: ${script}"
            else
                print_fail "Not executable: ${script}"
            fi
        else
            print_fail "Missing: ${script}"
        fi
    done
    
    # Test 2: Check for proper shebang
    print_test "Checking script shebangs"
    for script in "${install_scripts[@]}"; do
        local full_path="${PROJECT_ROOT}/${script}"
        if [[ -f "${full_path}" ]]; then
            if head -n1 "${full_path}" | grep -q "^#!/"; then
                print_pass "Valid shebang: ${script}"
            else
                print_fail "Invalid shebang: ${script}"
            fi
        fi
    done
    
    return 0
}

# ============================================================================
# Main Execution
# ============================================================================
main() {
    echo "========================================"
    echo "PyroVeil Module Testing Suite"
    echo "========================================"
    echo ""
    
    # Run all module tests
    test_autodetect_module
    test_json_parser_module
    test_shader_compiler_module
    test_layer_utils_module
    test_vulkan_layer_module
    test_installation_scripts
    
    # Print summary
    echo ""
    echo "========================================"
    echo "Test Summary"
    echo "========================================"
    echo -e "${GREEN}Passed:${RESET} ${TESTS_PASSED}"
    echo -e "${RED}Failed:${RESET} ${TESTS_FAILED}"
    echo ""
    
    if [[ ${TESTS_FAILED} -eq 0 ]]; then
        echo -e "${GREEN}✓ ALL MODULE TESTS PASSED${RESET}"
        return 0
    else
        echo -e "${RED}✗ SOME MODULE TESTS FAILED${RESET}"
        return 1
    fi
}

main "$@"
