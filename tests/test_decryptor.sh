#!/bin/bash

# Test Suite: Decryptor Client
# Tests the decryption client functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CW1_DIR="$SCRIPT_DIR/../cw1"

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

# Setup: Create encrypted test files
setup() {
    echo -e "${YELLOW}Setting up Decryptor test environment...${NC}"
    cd "$CW1_DIR"
    
    # Create test.txt if needed
    if [ ! -f "test.txt" ]; then
        echo "Original test content for decryption" > test.txt
    fi
    
    # Create encrypted files using WannaCry
    if [ ! -f "test.txt.cry" ] || [ ! -f "aes.key" ]; then
        cp test.txt test.txt.backup
        timeout 10 java WannaCry > /dev/null 2>&1 || true
    fi
}

# Cleanup
cleanup() {
    echo -e "${YELLOW}Cleaning up Decryptor test artifacts...${NC}"
    cd "$CW1_DIR"
    rm -f test.txt.cry aes.key test.txt
    if [ -f "test.txt.backup" ]; then
        mv test.txt.backup test.txt
    fi
}

# TC-10: Successful Decryption
test_successful_decryption() {
    echo -e "\n${YELLOW}Test TC-10: Successful Decryption${NC}"
    
    cd "$CW1_DIR"
    
    # Start server in background
    timeout 30 java Server 9999 > /tmp/server.log 2>&1 &
    SERVER_PID=$!
    sleep 1
    
    local test_passed=1
    
    # Check if server started
    if ! kill -0 $SERVER_PID 2>/dev/null; then
        echo "  ✗ Server failed to start"
        test_passed=0
    else
        # Run decryptor
        if timeout 10 java Decryptor localhost 9999 alice > /tmp/decryptor.log 2>&1; then
            # Check if test.txt exists
            if [ ! -f "test.txt" ]; then
                echo "  ✗ test.txt not decrypted"
                test_passed=0
            else
                echo "  ✓ test.txt successfully decrypted"
            fi
        else
            echo "  ✗ Decryptor failed"
            test_passed=0
        fi
        
        # Check output contains success message
        if grep -qi "success\|recovered" /tmp/decryptor.log; then
            echo "  ✓ Success message displayed"
        else
            echo "  ✗ Success message not found in output"
            test_passed=0
        fi
    fi
    
    # Cleanup server
    kill $SERVER_PID 2>/dev/null || true
    
    print_result "TC-10: Successful Decryption" $((1 - test_passed))
}

# TC-12: Server Unavailable
test_server_unavailable() {
    echo -e "\n${YELLOW}Test TC-12: Server Unavailable${NC}"
    
    cd "$CW1_DIR"
    
    local test_passed=1
    
    # Run decryptor without server
    if timeout 10 java Decryptor localhost 9998 alice > /tmp/decryptor.log 2>&1; then
        echo "  ✗ Decryptor should fail when server unavailable"
        test_passed=0
    else
        echo "  ✓ Decryptor fails gracefully when server unavailable"
    fi
    
    print_result "TC-12: Server Unavailable" $((1 - test_passed))
}

# TC-13: Missing UserID Keys
test_missing_keys() {
    echo -e "\n${YELLOW}Test TC-13: Missing UserID Keys${NC}"
    
    cd "$CW1_DIR"
    
    # Start server
    timeout 30 java Server 9996 > /tmp/server.log 2>&1 &
    SERVER_PID=$!
    sleep 1
    
    local test_passed=1
    
    if kill -0 $SERVER_PID 2>/dev/null; then
        # Try with non-existent userid
        if timeout 10 java Decryptor localhost 9996 nonexistent_user > /tmp/decryptor.log 2>&1; then
            echo "  ✗ Decryptor should fail with non-existent userid"
            test_passed=0
        else
            echo "  ✓ Decryptor fails gracefully with missing keys"
        fi
    else
        echo "  ✗ Server failed to start"
        test_passed=0
    fi
    
    kill $SERVER_PID 2>/dev/null || true
    
    print_result "TC-13: Missing UserID Keys" $((1 - test_passed))
}

# TC-14: Tampered aes.key
test_tampered_key() {
    echo -e "\n${YELLOW}Test TC-14: Tampered aes.key${NC}"
    
    cd "$CW1_DIR"
    
    # Backup aes.key
    if [ -f "aes.key" ]; then
        cp aes.key aes.key.backup
    fi
    
    # Tamper with aes.key
    if [ -f "aes.key" ]; then
        # Change first byte
        printf '\xFF' | dd of=aes.key bs=1 count=1 conv=notrunc 2>/dev/null || true
    fi
    
    # Start server
    timeout 30 java Server 9997 > /tmp/server.log 2>&1 &
    SERVER_PID=$!
    sleep 1
    
    local test_passed=1
    
    if kill -0 $SERVER_PID 2>/dev/null; then
        # Run decryptor with tampered key
        if timeout 10 java Decryptor localhost 9997 alice > /tmp/decryptor.log 2>&1; then
            echo "  ✗ Decryption should fail with tampered key"
            test_passed=0
        else
            echo "  ✓ Decryptor fails gracefully with tampered key"
        fi
    else
        echo "  ✗ Server failed to start"
        test_passed=0
    fi
    
    kill $SERVER_PID 2>/dev/null || true
    
    # Restore aes.key
    if [ -f "aes.key.backup" ]; then
        mv aes.key.backup aes.key
    fi
    
    print_result "TC-14: Tampered aes.key" $((1 - test_passed))
}

# Main execution
main() {
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}Decryptor Test Suite${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    setup
    
    test_successful_decryption
    cleanup
    setup
    
    test_server_unavailable
    cleanup
    setup
    
    test_missing_keys
    cleanup
    setup
    
    test_tampered_key
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
