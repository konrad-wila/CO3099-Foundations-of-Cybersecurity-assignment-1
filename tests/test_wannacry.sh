#!/bin/bash

# Test Suite: WannaCry Ransomware
# Tests the encryption functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CW1_DIR="$SCRIPT_DIR/../cw1"
TESTS_DIR="$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
PASSED=0
FAILED=0

# Helper function to print test results
print_result() {
    local test_name=$1
    local result=$2
    if [ "$result" -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        ((FAILED++))
    fi
}

# Setup: Create test environment
setup() {
    echo -e "${YELLOW}Setting up test environment...${NC}"
    cd "$CW1_DIR"
    
    # Create test.txt if it doesn't exist
    if [ ! -f "test.txt" ]; then
        echo "This is a test file for encryption. Content: $(date)" > test.txt
    fi
    
    # Clean up from previous runs
    rm -f test.txt.cry aes.key
    
    echo "Test setup complete"
}

# Cleanup: Remove test artifacts
cleanup() {
    echo -e "${YELLOW}Cleaning up test artifacts...${NC}"
    cd "$CW1_DIR"
    rm -f test.txt.cry aes.key
    # Restore test.txt if it was backed up
    if [ -f "test.txt.backup" ]; then
        mv test.txt.backup test.txt
    fi
}

# TC-1: Basic Encryption
test_basic_encryption() {
    echo -e "\n${YELLOW}Test TC-1: Basic Encryption${NC}"
    cd "$CW1_DIR"
    
    # Backup original file
    cp test.txt test.txt.backup
    
    # Run WannaCry
    timeout 10 java WannaCry > /dev/null 2>&1 || true
    
    local test_passed=1
    
    # Check test.txt is deleted
    if [ -f "test.txt" ]; then
        echo "  ✗ test.txt should be deleted"
        test_passed=0
    fi
    
    # Check test.txt.cry exists
    if [ ! -f "test.txt.cry" ]; then
        echo "  ✗ test.txt.cry not created"
        test_passed=0
    fi
    
    # Check aes.key exists
    if [ ! -f "aes.key" ]; then
        echo "  ✗ aes.key not created"
        test_passed=0
    fi
    
    # Check aes.key size (RSA-2048 encrypted, should be ~256 bytes)
    if [ -f "aes.key" ]; then
        local aes_size=$(wc -c < aes.key)
        if [ "$aes_size" -lt 200 ] || [ "$aes_size" -gt 500 ]; then
            echo "  ✗ aes.key size unexpected: $aes_size bytes (expected ~256)"
            test_passed=0
        fi
    fi
    
    print_result "TC-1: Basic Encryption" $((1 - test_passed))
}

# TC-2: Output Format
test_output_format() {
    echo -e "\n${YELLOW}Test TC-2: Output Format${NC}"
    cd "$CW1_DIR"
    
    # Restore test.txt
    if [ -f "test.txt.backup" ]; then
        cp test.txt.backup test.txt
    else
        echo "This is a test file" > test.txt
    fi
    
    local test_passed=1
    
    # Run WannaCry and capture output
    local output=$(timeout 10 java WannaCry 2>&1 || true)
    
    # Check for ransom message keywords
    if echo "$output" | grep -qi "encrypt\|payment\|recover"; then
        echo "  ✓ Output contains ransom message"
    else
        echo "  ✗ Output missing ransom message keywords"
        test_passed=0
    fi
    
    print_result "TC-2: Output Format" $((1 - test_passed))
}

# TC-3: File Overwrite
test_file_overwrite() {
    echo -e "\n${YELLOW}Test TC-3: File Overwrite${NC}"
    cd "$CW1_DIR"
    
    local test_passed=1
    
    # First run of WannaCry
    if [ -f "test.txt.backup" ]; then
        cp test.txt.backup test.txt
    else
        echo "First encryption test" > test.txt
    fi
    timeout 10 java WannaCry > /dev/null 2>&1 || true
    
    if [ ! -f "aes.key" ]; then
        echo "  ✗ First run failed to create aes.key"
        test_passed=0
    else
        local first_aes_md5=$(md5sum aes.key | awk '{print $1}')
        
        # Prepare for second run
        if [ -f "test.txt.backup" ]; then
            cp test.txt.backup test.txt
        else
            echo "Second encryption test" > test.txt
        fi
        
        timeout 10 java WannaCry > /dev/null 2>&1 || true
        
        if [ ! -f "aes.key" ]; then
            echo "  ✗ Second run failed to create aes.key"
            test_passed=0
        else
            local second_aes_md5=$(md5sum aes.key | awk '{print $1}')
            
            # aes.key should be different (different AES keys generated)
            if [ "$first_aes_md5" == "$second_aes_md5" ]; then
                echo "  ✗ aes.key not overwritten (same MD5: $first_aes_md5)"
                test_passed=0
            else
                echo "  ✓ aes.key successfully overwritten"
            fi
        fi
    fi
    
    print_result "TC-3: File Overwrite" $((1 - test_passed))
}

# Main execution
main() {
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}WannaCry Test Suite${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    setup
    
    test_basic_encryption
    cleanup
    setup
    
    test_output_format
    cleanup
    setup
    
    test_file_overwrite
    cleanup
    
    # Print summary
    echo -e "\n${YELLOW}========================================${NC}"
    echo -e "${YELLOW}Test Summary${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${GREEN}Passed: $PASSED${NC}"
    echo -e "${RED}Failed: $FAILED${NC}"
    
    if [ $FAILED -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
