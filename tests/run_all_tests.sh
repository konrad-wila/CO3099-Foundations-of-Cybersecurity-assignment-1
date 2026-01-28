#!/bin/bash

# Master Test Runner
# Executes all test suites and generates a summary report

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CW1_DIR="$SCRIPT_DIR/../cw1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Test results
declare -A SUITE_RESULTS
declare -A SUITE_TIMES

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    if [ ! -f "$CW1_DIR/RSAKeyGen.java" ]; then
        echo -e "${RED}✗ RSAKeyGen.java not found${NC}"
        return 1
    fi
    
    if [ ! -f "$CW1_DIR/server-b64.prv" ]; then
        echo -e "${RED}✗ server-b64.prv not found${NC}"
        return 1
    fi
    
    # Check if user keys exist, if not offer to generate them
    if [ ! -f "$CW1_DIR/alice.pub" ] || [ ! -f "$CW1_DIR/alice.prv" ]; then
        echo -e "${YELLOW}Alice keypair not found. Generating...${NC}"
        cd "$CW1_DIR"
        if timeout 30 java RSAKeyGen alice > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Alice keypair generated${NC}"
        else
            echo -e "${RED}✗ Failed to generate alice keypair${NC}"
            return 1
        fi
    fi
    
    if [ ! -f "$CW1_DIR/bob.pub" ] || [ ! -f "$CW1_DIR/bob.prv" ]; then
        echo -e "${YELLOW}Bob keypair not found. Generating...${NC}"
        cd "$CW1_DIR"
        if timeout 30 java RSAKeyGen bob > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Bob keypair generated${NC}"
        else
            echo -e "${RED}✗ Failed to generate bob keypair${NC}"
            return 1
        fi
    fi
    
    echo -e "${GREEN}✓ All prerequisites met${NC}\n"
    return 0
}

# Compile Java files
compile_java() {
    echo -e "${YELLOW}Compiling Java files...${NC}"
    
    cd "$CW1_DIR"
    
    # Check if .class files exist
    if [ -f "WannaCry.class" ] && [ -f "Server.class" ] && [ -f "Decryptor.class" ]; then
        echo -e "${YELLOW}Java files already compiled${NC}\n"
        return 0
    fi
    
    # Compile all Java files
    if javac *.java > /tmp/compile.log 2>&1; then
        echo -e "${GREEN}✓ Java files compiled successfully${NC}\n"
        return 0
    else
        echo -e "${RED}✗ Java compilation failed${NC}"
        echo "Error log:"
        cat /tmp/compile.log
        return 1
    fi
}

# Run a test suite
run_test_suite() {
    local suite_name=$1
    local script_path=$2
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Running $suite_name${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    local start_time=$(date +%s%N)
    
    if bash "$script_path"; then
        local end_time=$(date +%s%N)
        local duration=$(( (end_time - start_time) / 1000000 ))
        SUITE_RESULTS[$suite_name]="PASS"
        SUITE_TIMES[$suite_name]=$duration
        echo -e "${GREEN}$suite_name: PASS (${duration}ms)${NC}\n"
        return 0
    else
        local end_time=$(date +%s%N)
        local duration=$(( (end_time - start_time) / 1000000 ))
        SUITE_RESULTS[$suite_name]="FAIL"
        SUITE_TIMES[$suite_name]=$duration
        echo -e "${RED}$suite_name: FAIL (${duration}ms)${NC}\n"
        return 1
    fi
}

# Print summary report
print_summary() {
    echo -e "\n${MAGENTA}========================================${NC}"
    echo -e "${MAGENTA}TEST EXECUTION SUMMARY${NC}"
    echo -e "${MAGENTA}========================================${NC}\n"
    
    local passed=0
    local failed=0
    local total=0
    
    for suite in "${!SUITE_RESULTS[@]}"; do
        local result=${SUITE_RESULTS[$suite]}
        local time=${SUITE_TIMES[$suite]}
        
        if [ "$result" == "PASS" ]; then
            echo -e "${GREEN}✓ $suite${NC} (${time}ms)"
            ((passed++))
        else
            echo -e "${RED}✗ $suite${NC} (${time}ms)"
            ((failed++))
        fi
        ((total++))
    done
    
    echo ""
    echo -e "${MAGENTA}----------------------------------------${NC}"
    echo -e "Total: $total | ${GREEN}Passed: $passed${NC} | ${RED}Failed: $failed${NC}"
    echo -e "${MAGENTA}----------------------------------------${NC}\n"
    
    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}All test suites passed!${NC}\n"
        return 0
    else
        echo -e "${RED}Some test suites failed!${NC}\n"
        return 1
    fi
}

# Main execution
main() {
    echo -e "${MAGENTA}========================================${NC}"
    echo -e "${MAGENTA}Ransomware Assignment - Master Test Runner${NC}"
    echo -e "${MAGENTA}========================================${NC}\n"
    
    # Check prerequisites
    if ! check_prerequisites; then
        echo -e "${RED}Prerequisites check failed!${NC}"
        exit 1
    fi
    
    # Compile Java
    if ! compile_java; then
        echo -e "${RED}Java compilation failed!${NC}"
        exit 1
    fi
    
    # Run test suites
    run_test_suite "WannaCry Tests" "$SCRIPT_DIR/test_wannacry.sh"
    run_test_suite "Server Tests" "$SCRIPT_DIR/test_server.sh"
    run_test_suite "Decryptor Tests" "$SCRIPT_DIR/test_decryptor.sh"
    run_test_suite "Integration Tests" "$SCRIPT_DIR/test_integration.sh"
    
    # Print summary
    print_summary
    
    if [ ${#SUITE_RESULTS[@]} -gt 0 ] && [ $(echo "${SUITE_RESULTS[@]}" | grep -o "FAIL" | wc -l) -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTION]

Automated test runner for the Ransomware assignment

Options:
    -h, --help              Show this help message
    -s, --suite SUITE       Run a specific test suite
                            Options: wannacry, server, decryptor, integration
    -c, --check             Only check prerequisites and compile
    -v, --verbose           Show detailed test output

Examples:
    $0                      Run all tests
    $0 --suite wannacry     Run only WannaCry tests
    $0 --check              Check prerequisites and compile only

EOF
}

# Parse command-line arguments
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    show_usage
    exit 0
elif [ "$1" == "-c" ] || [ "$1" == "--check" ]; then
    check_prerequisites && compile_java
    exit $?
elif [ "$1" == "-s" ] || [ "$1" == "--suite" ]; then
    if [ -z "$2" ]; then
        echo "Error: Suite name required"
        show_usage
        exit 1
    fi
    check_prerequisites && compile_java
    case "$2" in
        wannacry)
            bash "$SCRIPT_DIR/test_wannacry.sh"
            ;;
        server)
            bash "$SCRIPT_DIR/test_server.sh"
            ;;
        decryptor)
            bash "$SCRIPT_DIR/test_decryptor.sh"
            ;;
        integration)
            bash "$SCRIPT_DIR/test_integration.sh"
            ;;
        *)
            echo "Unknown suite: $2"
            exit 1
            ;;
    esac
    exit $?
fi

# Run all tests by default
main "$@"
