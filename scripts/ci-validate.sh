#!/usr/bin/env bash
#
# ci-validate.sh - Continuous Integration validation script
#
# This script is optimized for CI/CD environments and provides
# fast, reliable validation with proper exit codes.
#
# Usage in CI/CD:
#   - GitHub Actions: ./scripts/ci-validate.sh
#   - GitLab CI: ./scripts/ci-validate.sh
#   - Jenkins: bash scripts/ci-validate.sh

set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RESET='\033[0m'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

OVERALL_STATUS=0

log_step() {
    echo -e "${YELLOW}▶${RESET} $1"
}

log_success() {
    echo -e "${GREEN}✓${RESET} $1"
}

log_error() {
    echo -e "${RED}✗${RESET} $1"
    OVERALL_STATUS=1
}

# Quick validation - essential checks only
quick_validate() {
    log_step "Running quick validation (essential checks only)..."
    
    # 1. Syntax check critical scripts
    log_step "Checking shell script syntax..."
    if command -v bash >/dev/null 2>&1; then
        bash -n "${PROJECT_ROOT}/scripts/run-full-validation.sh" && log_success "Validation script: OK"
        bash -n "${PROJECT_ROOT}/install-pyroveil.sh" && log_success "Install script: OK"
    fi
    
    # 2. JSON validation
    log_step "Validating JSON configuration..."
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import json; json.load(open('${PROJECT_ROOT}/database.json'))" && \
            log_success "database.json: valid"
    fi
    
    # 3. Build test
    log_step "Testing build system..."
    cd "${PROJECT_ROOT}"
    rm -rf build-ci
    mkdir build-ci
    cd build-ci
    
    if cmake .. -DCMAKE_BUILD_TYPE=Release >/dev/null 2>&1; then
        log_success "CMake configuration: OK"
        if make -j"$(nproc)" >/dev/null 2>&1; then
            log_success "Build: OK"
        else
            log_error "Build: FAILED"
        fi
    else
        log_error "CMake configuration: FAILED"
    fi
    
    # Cleanup
    cd "${PROJECT_ROOT}"
    rm -rf build-ci
    
    return ${OVERALL_STATUS}
}

# Full validation - comprehensive checks
full_validate() {
    log_step "Running full validation suite..."
    
    if "${SCRIPT_DIR}/run-full-validation.sh"; then
        log_success "Full validation: PASSED"
    else
        log_error "Full validation: FAILED"
    fi
    
    return ${OVERALL_STATUS}
}

main() {
    echo "========================================="
    echo "PyroVeil CI Validation"
    echo "========================================="
    echo ""
    
    # Determine validation mode
    MODE="${1:-quick}"
    
    case "${MODE}" in
        quick)
            quick_validate
            ;;
        full)
            full_validate
            ;;
        *)
            echo "Usage: $0 [quick|full]"
            echo "  quick - Essential checks only (faster)"
            echo "  full  - Comprehensive validation (slower)"
            exit 1
            ;;
    esac
    
    echo ""
    if [[ ${OVERALL_STATUS} -eq 0 ]]; then
        echo -e "${GREEN}✓ CI VALIDATION PASSED${RESET}"
        exit 0
    else
        echo -e "${RED}✗ CI VALIDATION FAILED${RESET}"
        exit 1
    fi
}

main "$@"
