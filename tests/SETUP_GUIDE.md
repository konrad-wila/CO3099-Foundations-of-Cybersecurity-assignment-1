# Test Setup Guide

## Prerequisites

### 1. Generate Test User Keys
Generate keypairs for test users (alice, bob, etc.) using RSAKeyGen.java:

```bash
cd cw1
java RSAKeyGen alice
java RSAKeyGen bob
```

This creates:
- `alice.pub`, `alice.prv`
- `bob.pub`, `bob.prv`

### 2. Create Test Files
In the `cw1` directory, create a test file:

```bash
echo "This is a test file for encryption." > test.txt
```

Or for large file testing:
```bash
dd if=/dev/urandom bs=1M count=10 of=test.txt
```

### 3. Verify Master Keys
Ensure these files exist in `cw1`:
- `server-b64.prv` (master RSA private key)
- Master public key is hardcoded in WannaCry.java and Decryptor.java

## Test Execution Workflow

### Quick Sanity Check (Manual)
```bash
cd cw1

# Terminal 1: Start server
java Server 9999

# Terminal 2: Create test file, run ransomware
echo "Original content" > test.txt
java WannaCry

# Terminal 3: Decrypt
java Decryptor localhost 9999 alice

# Verify test.txt is restored with original content
cat test.txt
```

### Automated Test Sequence
For TC-15 (Full Workflow):

1. Ensure `cw1/` contains:
   - test.txt (created with sample content)
   - alice.pub, alice.prv (generated keys)
   - server-b64.prv (master key)
   - WannaCry.java, Decryptor.java, Server.java (compiled)

2. Run test:
```bash
cd cw1

# Record original test.txt hash
md5sum test.txt > original.md5

# Run ransomware
java WannaCry
# Verify: test.txt deleted, test.txt.cry and aes.key created

# Start server (in background)
java Server 9999 &
SERVER_PID=$!

# Run decryptor
java Decryptor localhost 9999 alice

# Stop server
kill $SERVER_PID

# Verify decryption
md5sum test.txt
# Compare with original.md5
```

## Test Data Organization

```
tests/
├── TEST_CASES.md           # This file with all test case descriptions
├── SETUP_GUIDE.md          # Setup instructions (this file)
├── test-data/
│   ├── small.txt           # Small test file (~100 bytes)
│   ├── large.txt           # Large test file (~10MB)
│   ├── special-chars.txt   # File with special characters
│   └── binary.dat          # Binary test data
└── expected-results/
    └── tc-15-expected.txt  # Expected output for TC-15
```

## Variables to Monitor During Testing

### After WannaCry.java execution:
- [ ] `test.txt` is deleted
- [ ] `test.txt.cry` exists
- [ ] `aes.key` exists and is ~256 bytes (RSA-2048 encrypted)
- [ ] Console output shows ransom message

### During Server.java execution:
- [ ] Server binds to specified port
- [ ] For each client connection:
  - [ ] Server receives userid, encrypted key, signature
  - [ ] Signature verification succeeds or fails as expected
  - [ ] Console displays appropriate message
  - [ ] Decrypted AES key sent to client (if verified)

### After Decryptor.java execution:
- [ ] `test.txt` exists
- [ ] Content matches original (byte-for-byte)
- [ ] Console displays success or failure message appropriately

## Debugging Tips

### If WannaCry fails:
- Verify master public key string is correct
- Check AES key generation is working
- Verify RSA encryption is working (use test RSA implementation first)

### If Server fails:
- Verify port binding (check `netstat -tlnp | grep <port>`)
- Verify master private key decodes from Base64 correctly
- Add debug output for signature verification steps

### If Decryptor fails:
- Verify signature generation matches Server's verification
- Check userid keys (alice.pub, alice.prv) exist
- Verify encrypted AES key is being read correctly
- Check network connection to server

## Test Checklist

- [ ] All user keypairs generated
- [ ] Test files created in cw1/
- [ ] WannaCry, Decryptor, Server compiled
- [ ] TC-1 through TC-3 pass (WannaCry)
- [ ] TC-4 through TC-9 pass (Server)
- [ ] TC-10 through TC-14 pass (Decryptor)
- [ ] TC-15 through TC-17 pass (Integration)
- [ ] TC-18 through TC-22 pass (Edge cases)
