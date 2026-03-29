#!/usr/bin/env bash
#
# final-check.sh - Final verification before release
#
# This script performs a quick final check of the project
# to ensure everything is ready for public release.

set -euo pipefail

readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly RESET='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${BLUE}║     PyroVeil Final Pre-Release Check                ║${RESET}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""

# Check 1: Required documentation files
echo -e "${YELLOW}[1/8]${RESET} Checking documentation files..."
required_docs=(
    "README.md"
    "QUICKSTART.md"
    "LICENSE"
    "PRE-RELEASE-CHECKLIST.md"
    "CI-CD-EXAMPLES.md"
)

all_docs_present=true
for doc in "${required_docs[@]}"; do
    if [[ -f "${doc}" ]]; then
        echo -e "  ${GREEN}✓${RESET} ${doc}"
    else
        echo -e "  ${RED}✗${RESET} ${doc} MISSING"
        all_docs_present=false
    fi
done

# Check 2: No build artifacts
echo -e "\n${YELLOW}[2/8]${RESET} Checking for build artifacts..."
if [[ -d "build" ]] || [[ -d "cmake-build-debug" ]] || [[ -d "cmake-build-release" ]]; then
    echo -e "  ${RED}✗${RESET} Build directories present (run ./scripts/clean-all.sh)"
else
    echo -e "  ${GREEN}✓${RESET} No build directories"
fi

# Check 3: Source code files present
echo -e "\n${YELLOW}[3/8]${RESET} Checking source code..."
required_sources=(
    "layer/pyroveil.cpp"
    "layer/pyroveil_autodetect.cpp"
    "layer/pyroveil_autodetect.hpp"
    "compiler/compiler.cpp"
    "compiler/compiler.hpp"
)

all_sources_present=true
for src in "${required_sources[@]}"; do
    if [[ -f "${src}" ]]; then
        echo -e "  ${GREEN}✓${RESET} ${src}"
    else
        echo -e "  ${RED}✗${RESET} ${src} MISSING"
        all_sources_present=false
    fi
done

# Check 4: Scripts are executable
echo -e "\n${YELLOW}[4/8]${RESET} Checking scripts..."
required_scripts=(
    "scripts/clean-all.sh"
    "scripts/prepare-release.sh"
    "scripts/run-full-validation.sh"
    "scripts/test-modules.sh"
    "scripts/test-logging.sh"
    "install-pyroveil.sh"
)

all_scripts_ok=true
for script in "${required_scripts[@]}"; do
    if [[ -x "${script}" ]]; then
        echo -e "  ${GREEN}✓${RESET} ${script}"
    else
        echo -e "  ${RED}✗${RESET} ${script} (not executable or missing)"
        all_scripts_ok=false
    fi
done

# Check 5: Game configurations
echo -e "\n${YELLOW}[5/8]${RESET} Checking game configurations..."
if [[ -f "database.json" ]]; then
    if command -v jq >/dev/null 2>&1; then
        game_count=$(jq '.games | length' database.json 2>/dev/null || echo "0")
        echo -e "  ${GREEN}✓${RESET} database.json (${game_count} games)"
    else
        echo -e "  ${GREEN}✓${RESET} database.json (jq not available for count)"
    fi
else
    echo -e "  ${RED}✗${RESET} database.json MISSING"
fi

# Check 6: .gitignore comprehensive
echo -e "\n${YELLOW}[6/8]${RESET} Checking .gitignore..."
if [[ -f ".gitignore" ]]; then
    lines=$(wc -l < .gitignore)
    if [[ ${lines} -gt 50 ]]; then
        echo -e "  ${GREEN}✓${RESET} .gitignore (${lines} lines, comprehensive)"
    else
        echo -e "  ${YELLOW}!${RESET} .gitignore (${lines} lines, may need updating)"
    fi
else
    echo -e "  ${RED}✗${RESET} .gitignore MISSING"
fi

# Check 7: No Russian language in code
echo -e "\n${YELLOW}[7/8]${RESET} Checking code language..."
if grep -r --include="*.cpp" --include="*.hpp" -l '[а-яА-ЯёЁ]' layer/ compiler/ 2>/dev/null | head -1 > /dev/null; then
    echo -e "  ${YELLOW}!${RESET} Russian characters found in code"
    grep -r --include="*.cpp" --include="*.hpp" -l '[а-яА-ЯёЁ]' layer/ compiler/ 2>/dev/null || true
else
    echo -e "  ${GREEN}✓${RESET} Code is English-only"
fi

# Check 8: CMakeLists.txt valid
echo -e "\n${YELLOW}[8/8]${RESET} Checking build configuration..."
if [[ -f "CMakeLists.txt" ]]; then
    if grep -q "pyroveil_autodetect.cpp" layer/CMakeLists.txt 2>/dev/null; then
        echo -e "  ${GREEN}✓${RESET} CMakeLists.txt includes auto-detection module"
    else
        echo -e "  ${YELLOW}!${RESET} CMakeLists.txt may need auto-detection module"
    fi
else
    echo -e "  ${RED}✗${RESET} CMakeLists.txt MISSING"
fi

# Final summary
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${BLUE}║     Final Check Summary                              ║${RESET}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""

if ${all_docs_present} && ${all_sources_present} && ${all_scripts_ok}; then
    echo -e "${GREEN}✓ All critical checks passed!${RESET}"
    echo ""
    echo -e "${GREEN}Next steps:${RESET}"
    echo "  1. Run: ./scripts/run-full-validation.sh"
    echo "  2. Run: ./scripts/prepare-release.sh VERSION"
    echo "  3. Test the release package"
    echo "  4. Commit and push to GitHub"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some checks failed${RESET}"
    echo ""
    echo -e "${YELLOW}Please fix the issues above before releasing.${RESET}"
    echo ""
    exit 1
fi
