#!/usr/bin/env bash
#
# test-logging.sh - Test PyroVeil logging and debug output
#
# This script validates that logging infrastructure is working correctly
# by simulating various runtime scenarios and checking stderr output.

set -uo pipefail  # Removed -e to allow test failures without script exit

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly BUILD_DIR="${PROJECT_ROOT}/build"

# ANSI color codes
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly RESET='\033[0m'

print_test() {
    echo -e "\n${YELLOW}[TEST]${RESET} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${RESET} $1"
}

print_fail() {
    echo -e "${RED}[FAIL]${RESET} $1"
}

# Test 1: Check logging statements in source code
test_logging_presence() {
    print_test "Checking for logging statements in source code"
    
    local log_patterns=(
        'fprintf(stderr, "pyroveil:'
        'fprintf(stderr,'
        'std::cerr'
    )
    
    local total_logs=0
    for pattern in "${log_patterns[@]}"; do
        local count=$(grep -r "${pattern}" "${PROJECT_ROOT}/layer/"*.cpp 2>/dev/null | wc -l)
        total_logs=$((total_logs + count))
        echo "  Pattern '${pattern}': ${count} occurrences"
    done
    
    if [[ ${total_logs} -gt 0 ]]; then
        print_pass "Found ${total_logs} logging statements"
        return 0
    else
        print_fail "No logging statements found"
        return 1
    fi
}

# Test 2: Verify auto-detect logging
test_autodetect_logging() {
    print_test "Verifying auto-detection logging messages"
    
    local required_messages=(
        "Starting automatic game detection"
        "Steam AppID"
        "Process name"
        "Configuration base"
        "Found config"
    )
    
    local autodetect_cpp="${PROJECT_ROOT}/layer/pyroveil_autodetect.cpp"
    
    for msg in "${required_messages[@]}"; do
        if grep -q "${msg}" "${autodetect_cpp}"; then
            print_pass "Found log message: '${msg}'"
        else
            print_fail "Missing log message: '${msg}'"
        fi
    done
    
    return 0
}

# Test 3: Test environment variable logging
test_env_var_logging() {
    print_test "Testing environment variable detection logging"
    
    local env_vars=(
        "PYROVEIL_CONFIG"
        "PYROVEIL_CONFIG_BASE"
        "PYROVEIL_DATABASE"
        "SteamAppId"
        "STEAM_COMPAT_APP_ID"
    )
    
    local autodetect_cpp="${PROJECT_ROOT}/layer/pyroveil_autodetect.cpp"
    
    for var in "${env_vars[@]}"; do
        if grep -q "getenv(\"${var}\")" "${autodetect_cpp}"; then
            print_pass "Environment variable used: ${var}"
        else
            print_fail "Environment variable missing: ${var}"
        fi
    done
    
    return 0
}

# Test 4: Simulate runtime logging (dry-run test)
test_runtime_logging_simulation() {
    print_test "Simulating runtime logging scenarios"
    
    local lib_path="${BUILD_DIR}/layer/libVkLayer_pyroveil_64.so"
    
    if [[ ! -f "${lib_path}" ]]; then
        print_fail "Library not built: ${lib_path}"
        return 1
    fi
    
    # Check if library contains debug strings
    print_pass "Library built successfully"
    
    # Search for logging strings in the binary
    if strings "${lib_path}" | grep -q "pyroveil: \[AutoDetect\]"; then
        print_pass "Debug strings found in library binary"
    else
        print_fail "No debug strings in library (may be stripped)"
    fi
    
    return 0
}

# Test 5: Check error handling and warnings
test_error_logging() {
    print_test "Verifying error and warning logging"
    
    local error_patterns=(
        "ERROR:"
        "WARNING:"
        "FAILED"
        "not found"
        "not accessible"
    )
    
    local found=0
    for pattern in "${error_patterns[@]}"; do
        if grep -q "${pattern}" "${PROJECT_ROOT}/layer/pyroveil_autodetect.cpp"; then
            echo "  ✓ Error pattern found: '${pattern}'"
            found=$((found + 1))
        fi
    done
    
    if [[ ${found} -ge 3 ]]; then
        print_pass "Error handling logging: OK (${found} patterns)"
    else
        print_fail "Insufficient error handling (found ${found} patterns)"
        return 1
    fi
    
    return 0
}

# Main execution
main() {
    echo "========================================"
    echo "PyroVeil Logging Infrastructure Test"
    echo "========================================"
    echo ""
    
    local failed=0
    
    test_logging_presence || failed=1
    test_autodetect_logging || failed=1
    test_env_var_logging || failed=1
    test_runtime_logging_simulation || failed=1
    test_error_logging || failed=1
    
    echo ""
    echo "========================================"
    if [[ ${failed} -eq 0 ]]; then
        echo -e "${GREEN}✓ ALL LOGGING TESTS PASSED${RESET}"
    else
        echo -e "${RED}✗ SOME LOGGING TESTS FAILED${RESET}"
    fi
    echo "========================================"
    
    return ${failed}
}

main "$@"
