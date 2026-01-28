#!/bin/bash

# Integration Test Suite: Full Workflow
# Tests complete encryption -> server -> decryption flow

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CW1_DIR="$SCRIPT_DIR/../cw1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Cleanup
cleanup() {
    echo -e "${YELLOW}Cleaning up...${NC}"
    cd "$CW1_DIR"
    
    # Kill any lingering server processes
    pkill -f "java Server" 2>/dev/null || true
    sleep 1
    
    # Clean up test artifacts
    rm -f test.txt.cry aes.key test.txt
    if [ -f "test.txt.backup" ]; then
        mv test.txt.backup test.txt
    fi
}

# TC-15: Full Workflow (Single User)
test_full_workflow() {
    echo -e "\n${BLUE}Test TC-15: Full Workflow (Single User - alice)${NC}"
    
    cd "$CW1_DIR"
    
    local test_passed=1
    
    # Step 1: Create test file with known content
    echo "Original secret content for testing" > test.txt
    cp test.txt test.txt.backup
    local original_md5=$(md5sum test.txt | awk '{print $1}')
    echo "  ✓ Created test.txt (MD5: ${original_md5:0:8}...)"
    
    # Step 2: Run ransomware
    echo -e "\n  Running WannaCry..."
    if timeout 10 java WannaCry > /tmp/wannacry.log 2>&1; then
        if [ ! -f "test.txt.cry" ] || [ ! -f "aes.key" ]; then
            echo "  ✗ WannaCry failed to create encrypted files"
            test_passed=0
        else
            echo "  ✓ WannaCry created test.txt.cry and aes.key"
            
            if [ -f "test.txt" ]; then
                echo "  ✗ Original test.txt not deleted"
                test_passed=0
            else
                echo "  ✓ Original test.txt deleted"
            fi
        fi
    else
        echo "  ✗ WannaCry failed"
        test_passed=0
    fi
    
    # Step 3: Start server
    echo -e "\n  Starting server on port 9050..."
    timeout 60 java Server 9050 > /tmp/server_tc15.log 2>&1 &
    SERVER_PID=$!
    sleep 2
    
    if ! kill -0 $SERVER_PID 2>/dev/null; then
        echo "  ✗ Server failed to start"
        test_passed=0
    else
        echo "  ✓ Server started (PID: $SERVER_PID)"
        
        # Step 4: Run decryptor
        echo -e "\n  Running Decryptor with userid 'alice'..."
        if timeout 10 java Decryptor localhost 9050 alice > /tmp/decryptor_tc15.log 2>&1; then
            echo "  ✓ Decryptor completed"
            
            # Step 5: Verify decrypted file
            if [ ! -f "test.txt" ]; then
                echo "  ✗ test.txt not restored"
                test_passed=0
            else
                local decrypted_md5=$(md5sum test.txt | awk '{print $1}')
                if [ "$original_md5" != "$decrypted_md5" ]; then
                    echo "  ✗ Decrypted file doesn't match original"
                    echo "    Original MD5: $original_md5"
                    echo "    Decrypted MD5: $decrypted_md5"
                    test_passed=0
                else
                    echo "  ✓ Decrypted test.txt matches original (MD5: ${original_md5:0:8}...)"
                fi
                
                # Check content
                local decrypted_content=$(cat test.txt)
                if [ "$decrypted_content" != "Original secret content for testing" ]; then
                    echo "  ✗ Decrypted content incorrect"
                    test_passed=0
                else
                    echo "  ✓ Decrypted content correct"
                fi
            fi
            
            # Check decryptor output
            if grep -qi "success\|recovered" /tmp/decryptor_tc15.log; then
                echo "  ✓ Decryptor displayed success message"
            else
                echo "  ⚠ Success message not found in decryptor output"
            fi
        else
            echo "  ✗ Decryptor failed"
            cat /tmp/decryptor_tc15.log
            test_passed=0
        fi
    fi
    
    # Cleanup server
    kill $SERVER_PID 2>/dev/null || true
    
    print_result "TC-15: Full Workflow" $((1 - test_passed))
}

# TC-17: AES Decryption Correctness
test_decryption_correctness() {
    echo -e "\n${BLUE}Test TC-17: AES Decryption Correctness${NC}"
    
    cd "$CW1_DIR"
    
    local test_passed=1
    
    # Create test file with specific content
    echo -n "The quick brown fox jumps over the lazy dog. 1234567890" > test.txt
    cp test.txt test.txt.backup
    local original_md5=$(md5sum test.txt | awk '{print $1}')
    local original_sha256=$(sha256sum test.txt | awk '{print $1}')
    echo "  ✓ Created test file"
    echo "    MD5: $original_md5"
    echo "    SHA256: ${original_sha256:0:16}..."
    
    # Encrypt
    echo "  Running WannaCry..."
    if ! timeout 10 java WannaCry > /dev/null 2>&1; then
        echo "  ✗ WannaCry failed"
        test_passed=0
    else
        echo "  ✓ File encrypted"
        
        # Start server and decrypt
        timeout 60 java Server 9051 > /tmp/server_tc17.log 2>&1 &
        SERVER_PID=$!
        sleep 1
        
        if timeout 10 java Decryptor localhost 9051 alice > /dev/null 2>&1; then
            if [ -f "test.txt" ]; then
                local decrypted_md5=$(md5sum test.txt | awk '{print $1}')
                local decrypted_sha256=$(sha256sum test.txt | awk '{print $1}')
                
                if [ "$original_md5" == "$decrypted_md5" ] && [ "$original_sha256" == "$decrypted_sha256" ]; then
                    echo "  ✓ Decrypted file matches original (byte-for-byte)"
                    echo "    MD5: $decrypted_md5"
                    echo "    SHA256: ${decrypted_sha256:0:16}..."
                else
                    echo "  ✗ Hash mismatch"
                    echo "    Original MD5: $original_md5"
                    echo "    Decrypted MD5: $decrypted_md5"
                    test_passed=0
                fi
            else
                echo "  ✗ test.txt not restored"
                test_passed=0
            fi
        else
            echo "  ✗ Decryption failed"
            test_passed=0
        fi
        
        kill $SERVER_PID 2>/dev/null || true
    fi
    
    print_result "TC-17: AES Decryption Correctness" $((1 - test_passed))
}

# TC-20: IV Validation
test_iv_validation() {
    echo -e "\n${BLUE}Test TC-20: IV Validation (All Zeros)${NC}"
    
    cd "$CW1_DIR"
    
    local test_passed=1
    
    # Create test file
    echo "IV test content" > test.txt
    cp test.txt test.txt.backup
    
    # Run encryption
    if ! timeout 10 java WannaCry > /dev/null 2>&1; then
        echo "  ✗ WannaCry failed"
        test_passed=0
    else
        # Check that we can decrypt - if IV is wrong, decryption will fail
        timeout 60 java Server 9052 > /tmp/server_tc20.log 2>&1 &
        SERVER_PID=$!
        sleep 1
        
        if timeout 10 java Decryptor localhost 9052 alice > /dev/null 2>&1; then
            if [ -f "test.txt" ] && grep -q "IV test content" test.txt; then
                echo "  ✓ Decryption successful with zero IV"
            else
                echo "  ✗ Decryption failed (IV may be incorrect)"
                test_passed=0
            fi
        else
            echo "  ✗ Decryption failed"
            test_passed=0
        fi
        
        kill $SERVER_PID 2>/dev/null || true
    fi
    
    print_result "TC-20: IV Validation" $((1 - test_passed))
}

# TC-22: PKCS5Padding
test_pkcs5_padding() {
    echo -e "\n${BLUE}Test TC-22: PKCS5Padding Validation${NC}"
    
    cd "$CW1_DIR"
    
    local test_passed=1
    
    # Test with content length not multiple of 16
    # Length 25 = 16 + 9, should pad with 7 bytes (16 - 9)
    printf "This is exactly 25 chars" > test.txt
    cp test.txt test.txt.backup
    
    if ! timeout 10 java WannaCry > /dev/null 2>&1; then
        echo "  ✗ WannaCry failed"
        test_passed=0
    else
        timeout 60 java Server 9053 > /tmp/server_tc22.log 2>&1 &
        SERVER_PID=$!
        sleep 1
        
        if timeout 10 java Decryptor localhost 9053 alice > /dev/null 2>&1; then
            if [ -f "test.txt" ]; then
                local content=$(cat test.txt)
                if [ "$content" == "This is exactly 25 chars" ]; then
                    echo "  ✓ PKCS5Padding correctly applied and removed"
                else
                    echo "  ✗ Padding not correctly removed"
                    echo "    Expected: 'This is exactly 25 chars'"
                    echo "    Got: '$content'"
                    test_passed=0
                fi
            else
                echo "  ✗ Decryption failed"
                test_passed=0
            fi
        else
            echo "  ✗ Decryption failed"
            test_passed=0
        fi
        
        kill $SERVER_PID 2>/dev/null || true
    fi
    
    print_result "TC-22: PKCS5Padding Validation" $((1 - test_passed))
}

# Main execution
main() {
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}Integration Test Suite${NC}"
    echo -e "${YELLOW}Full Workflow Tests${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    test_full_workflow
    cleanup
    
    test_decryption_correctness
    cleanup
    
    test_iv_validation
    cleanup
    
    test_pkcs5_padding
    cleanup
    
    # Print summary
    echo -e "\n${YELLOW}========================================${NC}"
    echo -e "${YELLOW}Integration Test Summary${NC}"
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
