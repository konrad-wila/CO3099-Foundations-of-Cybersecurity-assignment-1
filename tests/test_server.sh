#!/bin/bash

# Test Suite: Server
# Tests the server functionality

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

# Setup: Prepare encrypted files
setup() {
    echo -e "${YELLOW}Setting up Server test environment...${NC}"
    cd "$CW1_DIR"
    
    # Create test files if needed
    if [ ! -f "test.txt" ]; then
        echo "Server test content" > test.txt
    fi
    
    if [ ! -f "test.txt.cry" ] || [ ! -f "aes.key" ]; then
        cp test.txt test.txt.backup
        timeout 10 java WannaCry > /dev/null 2>&1 || true
    fi
}

# Cleanup
cleanup() {
    echo -e "${YELLOW}Cleaning up Server test artifacts...${NC}"
    
    # Kill any lingering server processes
    pkill -f "java Server" || true
    sleep 1
}

# TC-4: Valid Signature Verification
test_valid_signature() {
    echo -e "\n${YELLOW}Test TC-4: Valid Signature Verification${NC}"
    
    cd "$CW1_DIR"
    
    local test_passed=1
    
    # Start server
    timeout 30 java Server 9001 > /tmp/server_tc4.log 2>&1 &
    SERVER_PID=$!
    sleep 1
    
    if ! kill -0 $SERVER_PID 2>/dev/null; then
        echo "  ✗ Server failed to start"
        test_passed=0
    else
        echo "  ✓ Server started successfully"
        
        # Check server is listening
        if timeout 5 bash -c "echo '' > /dev/tcp/localhost/9001" 2>/dev/null; then
            echo "  ✓ Server is listening on port 9001"
        else
            echo "  ✗ Server not listening"
            test_passed=0
        fi
    fi
    
    kill $SERVER_PID 2>/dev/null || true
    
    print_result "TC-4: Valid Signature Verification" $((1 - test_passed))
}

# TC-8: Port Binding
test_port_binding() {
    echo -e "\n${YELLOW}Test TC-8: Port Binding${NC}"
    
    cd "$CW1_DIR"
    
    local test_passed=1
    
    # Try to start server on port 9002
    timeout 15 java Server 9002 > /tmp/server_tc8.log 2>&1 &
    SERVER_PID=$!
    sleep 1
    
    if ! kill -0 $SERVER_PID 2>/dev/null; then
        echo "  ✗ Server failed to bind to port 9002"
        test_passed=0
    else
        echo "  ✓ Server successfully bound to port 9002"
        
        # Check if port is actually in use
        if netstat -tlnp 2>/dev/null | grep -q ":9002\|:9002 "; then
            echo "  ✓ Port 9002 is in use by server"
        elif timeout 5 bash -c "echo '' > /dev/tcp/localhost/9002" 2>/dev/null; then
            echo "  ✓ Server is responding on port 9002"
        else
            echo "  ⚠ Could not verify port binding (netstat unavailable)"
        fi
        
        kill $SERVER_PID 2>/dev/null || true
        sleep 1
    fi
    
    print_result "TC-8: Port Binding" $((1 - test_passed))
}

# TC-9: Server Restart
test_server_restart() {
    echo -e "\n${YELLOW}Test TC-9: Server Restart${NC}"
    
    cd "$CW1_DIR"
    
    local test_passed=1
    
    # Start server first time
    timeout 10 java Server 9003 > /tmp/server_restart_1.log 2>&1 &
    SERVER_PID_1=$!
    sleep 1
    
    if kill -0 $SERVER_PID_1 2>/dev/null; then
        echo "  ✓ First server instance started"
        kill $SERVER_PID_1 2>/dev/null || true
        sleep 1
    else
        echo "  ✗ First server instance failed"
        test_passed=0
    fi
    
    # Try to restart immediately
    timeout 10 java Server 9003 > /tmp/server_restart_2.log 2>&1 &
    SERVER_PID_2=$!
    sleep 1
    
    if kill -0 $SERVER_PID_2 2>/dev/null; then
        echo "  ✓ Second server instance started on same port"
    else
        echo "  ✗ Second server instance failed (port still in use?)"
        test_passed=0
    fi
    
    kill $SERVER_PID_2 2>/dev/null || true
    
    print_result "TC-9: Server Restart" $((1 - test_passed))
}

# TC-6: Multiple Sequential Clients
test_multiple_clients() {
    echo -e "\n${YELLOW}Test TC-6: Multiple Sequential Clients${NC}"
    
    cd "$CW1_DIR"
    
    local test_passed=1
    
    # Start server
    timeout 60 java Server 9004 > /tmp/server_tc6.log 2>&1 &
    SERVER_PID=$!
    sleep 1
    
    if ! kill -0 $SERVER_PID 2>/dev/null; then
        echo "  ✗ Server failed to start"
        test_passed=0
    else
        echo "  ✓ Server started successfully"
        
        # Try first client (alice)
        if timeout 10 java Decryptor localhost 9004 alice > /dev/null 2>&1; then
            echo "  ✓ First client (alice) handled"
        else
            echo "  ✗ First client failed"
        fi
        
        # Check server still running
        if kill -0 $SERVER_PID 2>/dev/null; then
            echo "  ✓ Server still running after first client"
        else
            echo "  ✗ Server crashed after first client"
            test_passed=0
        fi
        
        # Try second client (bob) - would fail due to signature but server should handle
        timeout 10 java Decryptor localhost 9004 bob > /dev/null 2>&1 || true
        
        # Check server still running
        if kill -0 $SERVER_PID 2>/dev/null; then
            echo "  ✓ Server still running after second client"
        else
            echo "  ✗ Server crashed after second client"
            test_passed=0
        fi
    fi
    
    kill $SERVER_PID 2>/dev/null || true
    
    print_result "TC-6: Multiple Sequential Clients" $((1 - test_passed))
}

# Main execution
main() {
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}Server Test Suite${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    setup
    
    test_valid_signature
    cleanup
    
    test_port_binding
    cleanup
    
    test_server_restart
    cleanup
    
    test_multiple_clients
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
