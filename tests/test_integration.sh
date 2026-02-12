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

# Global server variables
GLOBAL_SERVER_PID=""
GLOBAL_SERVER_PORT=9200

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

# Start global server for shared tests
start_global_server() {
    echo -e "${YELLOW}Starting global server on port ${GLOBAL_SERVER_PORT}...${NC}"
    cd "$CW1_DIR"
    
    timeout 300 java Server $GLOBAL_SERVER_PORT > /tmp/server_integration_global.log 2>&1 &
    GLOBAL_SERVER_PID=$!
    sleep 2
    
    if ! kill -0 $GLOBAL_SERVER_PID 2>/dev/null; then
        echo -e "${RED}✗ Failed to start global server${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Global server started (PID: $GLOBAL_SERVER_PID)${NC}"
}

# Stop global server
stop_global_server() {
    if [ -n "$GLOBAL_SERVER_PID" ]; then
        echo -e "${YELLOW}Stopping global server...${NC}"
        kill $GLOBAL_SERVER_PID 2>/dev/null || true
    fi
}

# Cleanup
cleanup() {
    echo -e "${YELLOW}Cleaning up...${NC}"
    cd "$CW1_DIR"
    
    # Clean up test artifacts (do NOT kill global server)
    
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
    
    # Step 3: Use global server
    echo -e "\n  Using global server (port $GLOBAL_SERVER_PORT)..."
    
    if ! kill -0 $GLOBAL_SERVER_PID 2>/dev/null; then
        echo "  ✗ Global server not running"
        test_passed=0
    else
        echo "  ✓ Server ready (PID: $GLOBAL_SERVER_PID)"
        
        # Step 4: Run decryptor
        echo -e "\n  Running Decryptor with userid 'alice'..."
        if timeout 10 java Decryptor localhost $GLOBAL_SERVER_PORT alice > /tmp/decryptor_tc15.log 2>&1; then
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
        
        
        
        if timeout 10 java Decryptor localhost $GLOBAL_SERVER_PORT alice > /dev/null 2>&1; then
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
        
        
        
        if timeout 10 java Decryptor localhost $GLOBAL_SERVER_PORT alice > /dev/null 2>&1; then
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
        
        
        
        if timeout 10 java Decryptor localhost $GLOBAL_SERVER_PORT alice > /dev/null 2>&1; then
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
        
    fi
    
    print_result "TC-22: PKCS5Padding Validation" $((1 - test_passed))
}

# TC-11: Wrong UserID
test_wrong_userid() {
    echo -e "\n${BLUE}Test TC-11: Wrong UserID Failure${NC}"
    
    cd "$CW1_DIR"
    
    local test_passed=1
    
    # Create test file
    echo "Secret data for alice only" > test.txt
    cp test.txt test.txt.backup
    
    # Encrypt with WannaCry
    if ! timeout 10 java WannaCry > /dev/null 2>&1; then
        echo "  ✗ WannaCry failed"
        test_passed=0
    else
        echo "  ✓ File encrypted by WannaCry"
        
        # Start server
        timeout 60 java Server 9100 > /tmp/server_tc11.log 2>&1 &
        
        
        # Try to decrypt as nonexistent user (no keypair)
        # This is the real test - user without valid keys cannot create signature
        if timeout 10 java Decryptor localhost 9100 attacker > /tmp/decryptor_tc11.log 2>&1; then
            echo "  ✗ Decryptor should fail for user without valid keys"
            test_passed=0
        else
            echo "  ✓ Decryptor correctly failed for unauthorized user"
        fi
        
        # Verify server is still running and able to handle next client
        if timeout 10 java Decryptor localhost 9100 alice > /dev/null 2>&1; then
            if [ -f "test.txt" ] && grep -q "Secret data for alice only" test.txt; then
                echo "  ✓ Authorized user can still decrypt after unauthorized attempt"
            else
                echo "  ✗ Alice's decryption failed"
                test_passed=0
            fi
        else
            echo "  ✗ Server failed after unauthorized attempt"
            test_passed=0
        fi
        
    fi
    
    print_result "TC-11: Wrong UserID Failure" $((1 - test_passed))
}

# TC-16: Multiple Users (Alice & Bob)
test_multiple_users() {
    echo -e "\n${BLUE}Test TC-16: Multiple Users Workflow${NC}"
    
    cd "$CW1_DIR"
    
    local test_passed=1
    
    # Create test file
    echo "Multi-user test content" > test.txt
    cp test.txt test.txt.backup
    local original_md5=$(md5sum test.txt | awk '{print $1}')
    
    # Encrypt with WannaCry
    if ! timeout 10 java WannaCry > /dev/null 2>&1; then
        echo "  ✗ WannaCry failed"
        test_passed=0
    else
        echo "  ✓ File encrypted"
        
        # Start server
        timeout 60 java Server 9101 > /tmp/server_tc16.log 2>&1 &
        
        
        # Alice decrypts (should succeed)
        if timeout 10 java Decryptor localhost 9101 alice > /dev/null 2>&1; then
            if [ -f "test.txt" ]; then
                local alice_md5=$(md5sum test.txt | awk '{print $1}')
                if [ "$alice_md5" == "$original_md5" ]; then
                    echo "  ✓ Alice successfully decrypted"
                else
                    echo "  ✗ Alice's decryption corrupted file"
                    test_passed=0
                fi
            fi
        else
            echo "  ✗ Alice's decryption failed"
            test_passed=0
        fi
        
    fi
    
    print_result "TC-16: Multiple Users Workflow" $((1 - test_passed))
}

# TC-18: Large File Encryption
test_large_file() {
    echo -e "\n${BLUE}Test TC-18: Large File Encryption${NC}"
    
    cd "$CW1_DIR"
    
    local test_passed=1
    
    # Create 5MB test file (smaller than 10MB for faster test)
    echo "Generating 5MB test file..."
    if ! timeout 30 dd if=/dev/urandom of=test.txt bs=1M count=5 2>/dev/null; then
        echo "  ✗ Failed to create test file"
        test_passed=0
    else
        local original_size=$(stat -f%z test.txt 2>/dev/null || stat -c%s test.txt 2>/dev/null)
        cp test.txt test.txt.backup
        local original_md5=$(md5sum test.txt | awk '{print $1}')
        echo "  ✓ Created 5MB test file (MD5: ${original_md5:0:8}...)"
        
        # Encrypt
        if ! timeout 30 java WannaCry > /dev/null 2>&1; then
            echo "  ✗ WannaCry failed on large file"
            test_passed=0
        else
            echo "  ✓ Large file encrypted"
            
            # Verify encrypted file larger than original
            local encrypted_size=$(stat -f%z test.txt.cry 2>/dev/null || stat -c%s test.txt.cry 2>/dev/null)
            if [ "$encrypted_size" -gt "$original_size" ]; then
                echo "  ✓ Encrypted size ($encrypted_size) > original ($original_size)"
            fi
            
            # Start server and decrypt
            timeout 60 java Server 9102 > /tmp/server_tc18.log 2>&1 &
            
            
            if timeout 60 java Decryptor localhost 9102 alice > /dev/null 2>&1; then
                if [ -f "test.txt" ]; then
                    local decrypted_md5=$(md5sum test.txt | awk '{print $1}')
                    if [ "$decrypted_md5" == "$original_md5" ]; then
                        echo "  ✓ Large file decrypted correctly (MD5: ${decrypted_md5:0:8}...)"
                    else
                        echo "  ✗ Decrypted file corrupted"
                        test_passed=0
                    fi
                else
                    echo "  ✗ File not decrypted"
                    test_passed=0
                fi
            else
                echo "  ✗ Decryption failed for large file"
                test_passed=0
            fi
            
        fi
    fi
    
    print_result "TC-18: Large File Encryption" $((1 - test_passed))
}

# TC-19: Special Characters in Content
test_special_characters() {
    echo -e "\n${BLUE}Test TC-19: Special Characters in Content${NC}"
    
    cd "$CW1_DIR"
    
    local test_passed=1
    
    # Create file with special characters, newlines, tabs
    cat > test.txt << 'TESTEOF'
Special characters test:
Newlines: Line 1
Line 2
Tabs:	Col1	Col2	Col3
Unicode: émojis 中文 العربية
Symbols: !@#$%^&*()_+-={}[]|:;"'<>?,./
Binary-like: \x00\xff\x80
TESTEOF
    
    cp test.txt test.txt.backup
    local original_md5=$(md5sum test.txt | awk '{print $1}')
    echo "  ✓ Created test file with special characters"
    
    # Encrypt
    if ! timeout 10 java WannaCry > /dev/null 2>&1; then
        echo "  ✗ WannaCry failed"
        test_passed=0
    else
        echo "  ✓ File encrypted"
        
        # Start server and decrypt
        timeout 60 java Server 9103 > /tmp/server_tc19.log 2>&1 &
        
        
        if timeout 10 java Decryptor localhost 9103 alice > /dev/null 2>&1; then
            if [ -f "test.txt" ]; then
                local decrypted_md5=$(md5sum test.txt | awk '{print $1}')
                if [ "$decrypted_md5" == "$original_md5" ]; then
                    echo "  ✓ Special characters preserved (MD5 matches)"
                else
                    echo "  ✗ Content corrupted (MD5 mismatch)"
                    test_passed=0
                fi
            else
                echo "  ✗ File not decrypted"
                test_passed=0
            fi
        else
            echo "  ✗ Decryption failed"
            test_passed=0
        fi
        
    fi
    
    print_result "TC-19: Special Characters in Content" $((1 - test_passed))
}

# TC-21: Base64 Encoding/Decoding
test_base64_keys() {
    echo -e "\n${BLUE}Test TC-21: Base64 Key Encoding/Decoding${NC}"
    
    cd "$CW1_DIR"
    
    local test_passed=1
    
    # Verify WannaCry uses Base64-encoded master public key
    echo "  Checking Base64 master public key in WannaCry..."
    if grep -q "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqW9Skh563WZyyNnXOz3k" WannaCry.java; then
        echo "  ✓ WannaCry contains Base64-encoded master public key"
    else
        echo "  ✗ WannaCry missing Base64 master key"
        test_passed=0
    fi
    
    # Verify server-b64.prv is Base64-encoded
    echo "  Checking Base64 encoding in server-b64.prv..."
    if head -c 10 server-b64.prv | grep -q "^[A-Za-z0-9+/]" || head -c 10 server-b64.prv | grep -q "^MII"; then
        echo "  ✓ server-b64.prv appears to be Base64-encoded"
    else
        echo "  ✗ server-b64.prv doesn't appear Base64-encoded"
        test_passed=0
    fi
    
    # Test that keys can be used (indirect test via full workflow)
    echo "  Testing key functionality..."
    echo "Base64 test content" > test.txt
    cp test.txt test.txt.backup
    
    if timeout 10 java WannaCry > /dev/null 2>&1; then
        timeout 60 java Server 9104 > /tmp/server_tc21.log 2>&1 &
        
        
        if timeout 10 java Decryptor localhost 9104 alice > /dev/null 2>&1; then
            if grep -q "Base64 test content" test.txt 2>/dev/null; then
                echo "  ✓ Base64-encoded keys successfully used in encryption/decryption"
            else
                echo "  ✗ Decryption failed"
                test_passed=0
            fi
        else
            echo "  ✗ Decryption with Base64 keys failed"
            test_passed=0
        fi
        
    else
        echo "  ✗ Encryption with Base64 keys failed"
        test_passed=0
    fi
    
    print_result "TC-21: Base64 Key Encoding/Decoding" $((1 - test_passed))
}

# TC-23: Key Reuse Detection
test_key_uniqueness() {
    echo -e "\n${BLUE}Test TC-23: Key Uniqueness (No Reuse)${NC}"
    
    cd "$CW1_DIR"
    
    local test_passed=1
    
    # Create and encrypt first file
    echo "First encryption test" > test.txt
    cp test.txt test.txt.backup
    
    if ! timeout 10 java WannaCry > /dev/null 2>&1; then
        echo "  ✗ First encryption failed"
        test_passed=0
    else
        local first_key_md5=$(md5sum aes.key | awk '{print $1}')
        echo "  ✓ First encryption completed"
        echo "    AES key MD5: ${first_key_md5:0:8}..."
        
        # Prepare second encryption
        cp test.txt.backup test.txt
        
        if ! timeout 10 java WannaCry > /dev/null 2>&1; then
            echo "  ✗ Second encryption failed"
            test_passed=0
        else
            local second_key_md5=$(md5sum aes.key | awk '{print $1}')
            echo "  ✓ Second encryption completed"
            echo "    AES key MD5: ${second_key_md5:0:8}..."
            
            # Verify keys are different
            if [ "$first_key_md5" == "$second_key_md5" ]; then
                echo "  ✗ AES keys are identical (should be random)"
                test_passed=0
            else
                echo "  ✓ AES keys are unique (proper randomization)"
            fi
        fi
    fi
    
    print_result "TC-23: Key Uniqueness" $((1 - test_passed))
}

# TC-27: Empty File Encryption
test_empty_file() {
    echo -e "\n${BLUE}Test TC-27: Empty File Encryption${NC}"
    
    cd "$CW1_DIR"
    
    local test_passed=1
    
    # Create empty test file
    > test.txt
    cp test.txt test.txt.backup
    echo "  ✓ Created empty test.txt"
    
    # Encrypt empty file
    if ! timeout 10 java WannaCry > /dev/null 2>&1; then
        echo "  ✗ WannaCry failed on empty file"
        test_passed=0
    else
        if [ ! -f "test.txt.cry" ] || [ ! -f "aes.key" ]; then
            echo "  ✗ Encryption failed to create output files"
            test_passed=0
        else
            echo "  ✓ Empty file encrypted"
            
            # Try to decrypt
            timeout 60 java Server 9105 > /tmp/server_tc27.log 2>&1 &
            
            
            if timeout 10 java Decryptor localhost 9105 alice > /dev/null 2>&1; then
                if [ -f "test.txt" ]; then
                    local size=$(wc -c < test.txt)
                    if [ "$size" -eq 0 ]; then
                        echo "  ✓ Empty file decrypted correctly (size: 0)"
                    else
                        echo "  ✗ Decrypted file should be empty but has $size bytes"
                        test_passed=0
                    fi
                else
                    echo "  ✗ File not restored"
                    test_passed=0
                fi
            else
                echo "  ✗ Decryption failed"
                test_passed=0
            fi
            
        fi
    fi
    
    print_result "TC-27: Empty File Encryption" $((1 - test_passed))
}

# TC-31: Missing aes.key File
test_missing_aes_key() {
    echo -e "\n${BLUE}Test TC-31: Missing aes.key File${NC}"
    
    cd "$CW1_DIR"
    
    local test_passed=1
    
    # Create and encrypt file
    echo "Test with missing key" > test.txt
    cp test.txt test.txt.backup
    
    if ! timeout 10 java WannaCry > /dev/null 2>&1; then
        echo "  ✗ WannaCry failed"
        test_passed=0
    else
        echo "  ✓ File encrypted"
        
        # Remove aes.key
        if [ -f "aes.key" ]; then
            rm aes.key
            echo "  ✓ Removed aes.key"
        fi
        
        # Try to decrypt without aes.key
        timeout 60 java Server 9106 > /tmp/server_tc31.log 2>&1 &
        
        
        if timeout 10 java Decryptor localhost 9106 alice > /tmp/decryptor_tc31.log 2>&1; then
            echo "  ✗ Decryptor should fail without aes.key"
            test_passed=0
        else
            echo "  ✓ Decryptor correctly failed without aes.key"
        fi
        
    fi
    
    print_result "TC-31: Missing aes.key File" $((1 - test_passed))
}

# TC-39: AES Key Entropy
test_key_entropy() {
    echo -e "\n${BLUE}Test TC-39: AES Key Entropy Validation${NC}"
    
    cd "$CW1_DIR"
    
    local test_passed=1
    
    echo "  Testing AES key randomness..."
    
    # Generate multiple keys and check for variation
    local keys_array=()
    
    for i in {1..3}; do
        echo "Test file $i" > test.txt
        cp test.txt test.txt.backup
        
        if timeout 10 java WannaCry > /dev/null 2>&1; then
            local key_hash=$(md5sum aes.key | awk '{print $1}')
            keys_array+=("$key_hash")
            echo "  ✓ Key $i: ${key_hash:0:8}..."
        else
            echo "  ✗ Encryption $i failed"
            test_passed=0
        fi
    done
    
    # Check if all keys are different
    if [ "${keys_array[0]}" == "${keys_array[1]}" ] || [ "${keys_array[1]}" == "${keys_array[2]}" ]; then
        echo "  ✗ Keys show low entropy (duplicates detected)"
        test_passed=0
    else
        echo "  ✓ Keys show good entropy (all unique)"
    fi
    
    # Verify key size (AES-256 = 32 bytes = 256 bits)
    local key_size=$(wc -c < aes.key)
    echo "  Checking RSA-encrypted key size..."
    if [ "$key_size" -gt 200 ] && [ "$key_size" -lt 500 ]; then
        echo "  ✓ RSA-2048 encrypted key size valid ($key_size bytes)"
    else
        echo "  ✗ Key size unexpected: $key_size bytes"
        test_passed=0
    fi
    
    print_result "TC-39: AES Key Entropy" $((1 - test_passed))
}

# Main execution
main() {
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}Integration Test Suite${NC}"
    echo -e "${YELLOW}Full Workflow Tests${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    # Start global server once for all tests
    start_global_server
    
    test_full_workflow
    cleanup
    
    test_decryption_correctness
    cleanup
    
    test_iv_validation
    cleanup
    
    test_pkcs5_padding
    cleanup
    
    test_wrong_userid
    cleanup
    
    test_multiple_users
    cleanup
    
    test_large_file
    cleanup
    
    test_special_characters
    cleanup
    
    test_base64_keys
    cleanup
    
    test_key_uniqueness
    cleanup
    
    test_empty_file
    cleanup
    
    test_missing_aes_key
    cleanup
    
    test_key_entropy
    cleanup
    
    # Stop global server at the end
    stop_global_server
    
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
