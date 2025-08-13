#!/bin/bash
# Test script for RaptorOS Build Improvements
# This script tests the new library files and enhanced functionality

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Test counter
test_count=0

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    test_count=$((test_count + 1))
    echo -e "${CYAN}[TEST $test_count] $test_name${NC}"
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAILED${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    echo ""
}

# Header
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           RaptorOS Build Improvements Test Suite          ║${NC}"
echo -e "${CYAN}║              Testing Enhanced Functionality               ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Test 1: Check if library files exist
run_test "Library Files Existence" "
    [ -f 'lib/colors.sh' ] && 
    [ -f 'lib/functions.sh' ] && 
    [ -f 'lib/iso_boot.sh' ] && 
    [ -f 'lib/build_validation.sh' ]
"

# Test 2: Check if library files are executable
run_test "Library Files Executable" "
    [ -x 'lib/colors.sh' ] && 
    [ -x 'lib/functions.sh' ] && 
    [ -x 'lib/iso_boot.sh' ] && 
    [ -x 'lib/build_validation.sh' ]
"

# Test 3: Test colors.sh functionality
run_test "Colors Library Functions" "
    source 'lib/colors.sh' && 
    command -v print_success >/dev/null && 
    command -v print_error >/dev/null && 
    command -v show_progress >/dev/null
"

# Test 4: Test functions.sh functionality
run_test "Functions Library Functions" "
    source 'lib/functions.sh' && 
    command -v log_info >/dev/null && 
    command -v validate_file >/dev/null && 
    command -v start_timer >/dev/null
"

# Test 5: Test iso_boot.sh functionality
run_test "ISO Boot Support Functions" "
    source 'lib/iso_boot.sh' && 
    command -v generate_initramfs >/dev/null && 
    command -v configure_grub >/dev/null && 
    command -v setup_complete_boot_support >/dev/null
"

# Test 6: Test build_validation.sh functionality
run_test "Build Validation Functions" "
    source 'lib/build_validation.sh' && 
    command -v validate_package_installations >/dev/null && 
    command -v run_complete_validation >/dev/null
"

# Test 7: Test main build script integration
run_test "Main Build Script Integration" "
    [ -f 'build.sh' ] && 
    grep -q 'source.*lib/colors.sh' 'build.sh' && 
    grep -q 'source.*lib/functions.sh' 'build.sh'
"

# Test 8: Test enhanced ISO creation function
run_test "Enhanced ISO Creation Function" "
    grep -q 'setup_complete_boot_support' 'build.sh' && 
    grep -q 'run_complete_validation' 'build.sh'
"

# Test 9: Test new build menu option
run_test "New Build Menu Option" "
    grep -q 'Validate Build' 'build.sh' && 
    grep -q 'validate_existing_build' 'build.sh'
"

# Test 10: Test fallback functionality
run_test "Fallback Functionality" "
    grep -q 'fallback.*colors' 'build.sh' && 
    grep -q 'fallback.*functions' 'build.sh'
"

# Test 11: Test error handling improvements
run_test "Error Handling Improvements" "
    grep -q 'trap.*cleanup_on_exit' 'build.sh' && 
    grep -q 'die.*FATAL ERROR' 'build.sh'
"

# Test 12: Test logging system
run_test "Logging System Integration" "
    grep -q 'log_info\|log_success\|log_warning\|log_error' 'build.sh'
"

# Test 13: Test validation system integration
run_test "Validation System Integration" "
    grep -q 'run_complete_validation' 'build.sh' && 
    grep -q 'setup_complete_boot_support' 'build.sh'
"

# Test 14: Test enhanced requirements checking
run_test "Enhanced Requirements Checking" "
    grep -q 'validate_system_requirements' 'build.sh' && 
    grep -q 'safe_mkdir' 'build.sh'
"

# Test 15: Test documentation
run_test "Documentation Files" "
    [ -f 'BUILD_IMPROVEMENTS.md' ] && 
    [ -s 'BUILD_IMPROVEMENTS.md' ]
"

# Results summary
echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}                    TEST RESULTS SUMMARY                    ${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "Total Tests: $test_count"
echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
echo ""

# Calculate success rate
if [ $test_count -gt 0 ]; then
    SUCCESS_RATE=$((TESTS_PASSED * 100 / test_count))
    echo -e "Success Rate: ${SUCCESS_RATE}%"
    
    if [ $SUCCESS_RATE -eq 100 ]; then
        echo -e "${GREEN}🎉 All tests passed! Build improvements are working correctly.${NC}"
    elif [ $SUCCESS_RATE -ge 80 ]; then
        echo -e "${YELLOW}⚠️  Most tests passed. Some improvements may need attention.${NC}"
    else
        echo -e "${RED}❌ Many tests failed. Build improvements need significant work.${NC}"
    fi
fi

echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"

# Exit with appropriate code
if [ $TESTS_FAILED -eq 0 ]; then
    exit 0
else
    exit 1
fi
