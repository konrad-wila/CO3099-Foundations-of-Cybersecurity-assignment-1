# Automated Test Suite

This directory contains automated test cases for the Ransomware Assignment.

## Quick Start

```bash
# Run all tests
cd tests
./run_all_tests.sh

# Run a specific test suite
./run_all_tests.sh --suite wannacry
./run_all_tests.sh --suite server
./run_all_tests.sh --suite decryptor
./run_all_tests.sh --suite integration

# Check prerequisites and compile only
./run_all_tests.sh --check
```

## Test Files

- **run_all_tests.sh** — Master test runner (entry point)
- **test_wannacry.sh** — Tests for WannaCry ransomware (TC-1, TC-2, TC-3)
- **test_server.sh** — Tests for Server (TC-4, TC-6, TC-8, TC-9)
- **test_decryptor.sh** — Tests for Decryptor client (TC-10, TC-12, TC-13, TC-14)
- **test_integration.sh** — Full workflow integration tests (TC-15, TC-17, TC-20, TC-22)

## Test Coverage

### WannaCry Tests (test_wannacry.sh)
- **TC-1**: Basic Encryption — Verifies file encryption and key generation
- **TC-2**: Output Format — Verifies ransom message displays
- **TC-3**: File Overwrite — Tests repeated encryption runs

### Server Tests (test_server.sh)
- **TC-4**: Valid Signature Verification — Server accepts valid signatures
- **TC-6**: Multiple Sequential Clients — Server handles multiple connections
- **TC-8**: Port Binding — Server successfully binds to port
- **TC-9**: Server Restart — Server can restart on same port

### Decryptor Tests (test_decryptor.sh)
- **TC-10**: Successful Decryption — Valid client decrypts file
- **TC-12**: Server Unavailable — Graceful error handling
- **TC-13**: Missing UserID Keys — Handles missing key files
- **TC-14**: Tampered aes.key — Handles corrupted encrypted key

### Integration Tests (test_integration.sh)
- **TC-15**: Full Workflow — Complete encryption → server → decryption flow
- **TC-17**: AES Decryption Correctness — Byte-for-byte file verification
- **TC-20**: IV Validation — Confirms zero-byte IV usage
- **TC-22**: PKCS5Padding — Validates padding correctness

## Prerequisites

The test runner automatically:
1. Checks for required files (`RSAKeyGen.java`, `server-b64.prv`)
2. Generates user keypairs (alice, bob) if missing
3. Compiles Java source files

To manually generate keypairs:
```bash
cd cw1
java RSAKeyGen alice
java RSAKeyGen bob
```

## Test Execution Flow

```
run_all_tests.sh
├── Check Prerequisites
├── Compile Java Files
├── test_wannacry.sh
│   ├── TC-1: Basic Encryption
│   ├── TC-2: Output Format
│   └── TC-3: File Overwrite
├── test_server.sh
│   ├── TC-4: Valid Signature Verification
│   ├── TC-6: Multiple Sequential Clients
│   ├── TC-8: Port Binding
│   └── TC-9: Server Restart
├── test_decryptor.sh
│   ├── TC-10: Successful Decryption
│   ├── TC-12: Server Unavailable
│   ├── TC-13: Missing UserID Keys
│   └── TC-14: Tampered aes.key
└── test_integration.sh
    ├── TC-15: Full Workflow
    ├── TC-17: AES Decryption Correctness
    ├── TC-20: IV Validation
    └── TC-22: PKCS5Padding
```

## Output Format

### Individual Test Runs
```
Test TC-1: Basic Encryption
  ✓ test.txt.cry created
  ✓ aes.key created
  ✓ Original test.txt deleted
✓ PASS: TC-1: Basic Encryption
```

### Master Test Runner Summary
```
========================================
TEST EXECUTION SUMMARY
========================================

✓ WannaCry Tests (1234ms)
✓ Server Tests (2567ms)
✓ Decryptor Tests (1890ms)
✓ Integration Tests (3456ms)

----------------------------------------
Total: 4 | Passed: 4 | Failed: 0
----------------------------------------

All test suites passed!
```

## Debugging Failed Tests

If a test fails:

1. **Check individual test output**: Run specific test suite
   ```bash
   ./test_wannacry.sh
   ```

2. **Check log files**: Tests create logs in `/tmp/`
   - `/tmp/server.log` — Server output
   - `/tmp/decryptor.log` — Decryptor output
   - `/tmp/compile.log` — Compilation errors

3. **Verify Java implementation**: Ensure programs compile without errors
   ```bash
   cd cw1
   javac *.java
   ```

4. **Check file states**: Manually verify files exist and have expected content
   ```bash
   cd cw1
   ls -lah test.txt* aes.key
   ```

## Test Data

Tests use sample content for consistency:
- Short files: "This is a test file for encryption"
- Special characters and variable-length content tested in integration tests
- Original content is backed up before encryption for verification

## Limitations

- Tests assume single-threaded client connections (as per assignment spec)
- Tests don't verify exact console message formatting (only keywords)
- IV validation (TC-20) is indirect (verifies successful decryption with zero IV)
- Signature validation tests are indirect (signature generation verified through successful decryption)

## Extending Tests

To add new tests:

1. Create new test function in appropriate script:
   ```bash
   test_new_feature() {
       echo -e "\n${YELLOW}Test TC-XX: New Feature${NC}"
       # Test code here
       print_result "TC-XX: New Feature" $((1 - test_passed))
   }
   ```

2. Add test function call to main():
   ```bash
   test_new_feature
   cleanup
   ```

3. Run tests:
   ```bash
   ./run_all_tests.sh
   ```

## Environment

Tests are designed to run on:
- Linux/Unix-based systems (Ubuntu 24.04 used for development)
- Java 11 or later
- Bash 4.0 or later

## Troubleshooting

### "Server already in use" error
Kill lingering server processes:
```bash
pkill -f "java Server"
```

### "Connection refused" error
Ensure server has time to start:
- Increase `sleep` duration in test scripts
- Check firewall blocking port

### File permission errors
Make scripts executable:
```bash
chmod +x tests/*.sh
```

### Compilation errors
Verify Java files are in `cw1/` directory and compile individually:
```bash
cd cw1
javac WannaCry.java
javac Server.java
javac Decryptor.java
```
