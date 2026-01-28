# Test Cases for Ransomware Assignment

## WannaCry Tests

### TC-1: Basic Encryption
**Objective:** Verify WannaCry correctly encrypts test.txt and generates aes.key
**Setup:** Create test.txt with sample content
**Steps:**
1. Run `java WannaCry`
2. Verify test.txt is deleted
3. Verify test.txt.cry exists and contains encrypted data
4. Verify aes.key exists and contains RSA-encrypted AES key
**Expected Result:** Ransom message displays, all three files in correct state

### TC-2: Output Format
**Objective:** Verify ransom message is displayed and program exits cleanly
**Steps:**
1. Run `java WannaCry`
2. Observe console output
**Expected Result:** Message containing ransom demand displays, program terminates without error

### TC-3: File Overwrite
**Objective:** Test running WannaCry twice in succession
**Steps:**
1. Run WannaCry first time
2. Note aes.key content/size
3. Run WannaCry second time (with new test.txt)
4. Verify aes.key is overwritten (different content)
**Expected Result:** Second run successfully overwrites aes.key

---

## Server Tests

### TC-4: Valid Signature Verification
**Objective:** Server accepts valid signature and returns decrypted AES key
**Setup:** 
- Start Server on port 9999
- Have valid userid with .pub and .prv keys
- Have valid encrypted AES key and signature
**Steps:**
1. Connect client with correct userid, encrypted key, valid signature
2. Observe server output
3. Verify server sends decrypted AES key
**Expected Result:** Server displays "Signature verified. Key decrypted and sent.", client receives AES key

### TC-5: Invalid Signature
**Objective:** Server rejects invalid signature and disconnects
**Setup:** Same as TC-4 but with tampered signature
**Steps:**
1. Connect client with tampered signature (modify 1-2 bytes)
2. Observe server output
**Expected Result:** Server displays "Signature not verified.", disconnects client

### TC-6: Wrong UserID
**Objective:** Server rejects request from non-existent user
**Setup:** Start Server, prepare client request with non-existent userid
**Steps:**
1. Connect with userid "fake_user" that has no .pub/.prv keys
2. Attempt verification
**Expected Result:** Server rejects signature and disconnects

### TC-7: Multiple Sequential Clients
**Objective:** Server handles multiple clients without crashing
**Setup:** Start Server on port 9999
**Steps:**
1. Connect client 1 (alice) with valid signature
2. Wait for server message
3. Connect client 2 (bob) with valid signature
4. Wait for server message
5. Connect client 3 with invalid signature
6. Wait for server message
**Expected Result:** Server handles all three connections sequentially, doesn't crash

### TC-8: Port Binding
**Objective:** Server successfully binds to specified port and persists
**Steps:**
1. Start `java Server 8888`
2. Verify no error messages on startup
3. Wait 5 seconds
4. Check server still listening (attempt telnet or connection)
**Expected Result:** Server successfully starts and continues listening

### TC-9: Server Restart
**Objective:** Server can be stopped and restarted on same port
**Steps:**
1. Start Server on port 9000
2. Let it run briefly
3. Stop Server (Ctrl+C)
4. Immediately restart Server on same port
**Expected Result:** Server restarts without "port already in use" error

---

## Decryptor Tests

### TC-10: Successful Decryption
**Objective:** Decryptor successfully decrypts test.txt.cry with valid credentials
**Setup:**
- Run WannaCry to generate test.txt.cry and aes.key
- Start Server on known port
- Prepare Decryptor with valid userid
**Steps:**
1. Run `java Decryptor localhost 9999 alice`
2. Observe output
3. Verify test.txt exists and matches original content
**Expected Result:** "Success! Your files have now been recovered!" displays, test.txt is decrypted and correct

### TC-11: Wrong UserID
**Objective:** Decryptor fails gracefully when userid doesn't match
**Setup:** 
- WannaCry has encrypted files
- Server running
- Decryptor runs with userid that has valid keys but didn't pay
**Steps:**
1. Run `java Decryptor localhost 9999 bob` (where alice encrypted)
2. Observe output
**Expected Result:** "Unfortunately we cannot verify your identity" message displays

### TC-12: Server Unavailable
**Objective:** Decryptor handles connection errors gracefully
**Setup:** No Server running
**Steps:**
1. Run `java Decryptor localhost 9999 alice`
2. Observe error handling
**Expected Result:** Program terminates gracefully with connection error message (no crash)

### TC-13: Missing Userid Keys
**Objective:** Decryptor fails gracefully when userid has no .pub/.prv files
**Steps:**
1. Run `java Decryptor localhost 9999 nonexistent_user`
**Expected Result:** Program handles missing key files gracefully (error message, no crash)

### TC-14: Tampered aes.key
**Objective:** Decryptor handles corrupted encrypted AES key
**Setup:** 
- Run WannaCry
- Modify aes.key by changing 1-2 bytes
- Start Server
**Steps:**
1. Run `java Decryptor localhost 9999 alice`
2. Observe error handling
**Expected Result:** Decryption fails gracefully, error message displayed

---

## Integration Tests

### TC-15: Full Workflow (Alice)
**Objective:** Complete workflow from encryption to decryption
**Steps:**
1. Create test.txt with known content
2. Run `java WannaCry`
3. Verify test.txt.cry created and original deleted
4. Start `java Server 9999` (in separate terminal)
5. Run `java Decryptor localhost 9999 alice`
6. Verify test.txt exists with original content
**Expected Result:** All steps succeed, file is recovered

### TC-16: Multiple Users (Alice & Bob)
**Objective:** Two different users can separately encrypt and decrypt
**Setup:** Create test.txt, have alice.prv, alice.pub, bob.prv, bob.pub
**Steps:**
1. Run `java WannaCry` (encrypts as "attacker")
2. Start Server
3. Run Decryptor as alice (should succeed)
4. Restore test.txt and run WannaCry again
5. Run Decryptor as bob (should fail - bob didn't "pay")
**Expected Result:** Alice succeeds, Bob fails with signature error

### TC-17: AES Decryption Correctness
**Objective:** Decrypted content is byte-for-byte identical to original
**Setup:** test.txt with specific known content (e.g., "Hello World!")
**Steps:**
1. Save test.txt MD5 hash
2. Run WannaCry
3. Run full decryption workflow
4. Compare decrypted test.txt MD5 hash
**Expected Result:** Hashes match exactly

---

## Edge Cases & Validation

### TC-18: Large File Encryption
**Objective:** WannaCry handles larger files correctly
**Setup:** Create test.txt with 10MB+ of random data
**Steps:**
1. Run WannaCry
2. Verify test.txt.cry exists and larger than test.txt
3. Run full decryption workflow
**Expected Result:** Large file encrypts/decrypts correctly

### TC-19: Special Characters in Content
**Objective:** test.txt with special chars, Unicode, binary data
**Setup:** Create test.txt with mixed content (special chars, newlines, tabs)
**Steps:**
1. Run WannaCry
2. Run full decryption workflow
3. Compare original and decrypted byte-for-byte
**Expected Result:** Decrypted content is identical, special chars preserved

### TC-20: IV is All Zeros
**Objective:** Verify CBC mode uses correct zero IV
**Setup:** Encrypt known plaintext with WannaCry
**Steps:**
1. Manually verify IV is all zeros in CBC implementation
2. Create another file with same content, encrypt differently
3. Compare first ciphertext blocks (should differ if IV differs)
**Expected Result:** IV confirmed to be 16 zero bytes

### TC-21: Base64 Encoding/Decoding
**Objective:** Master RSA keys decode from Base64 correctly
**Steps:**
1. In WannaCry, verify master public key decodes from Base64 string
2. In Server, verify master private key decodes from server-b64.prv
3. Verify both keys can be used for encryption/decryption
**Expected Result:** Both keys successfully used in cryptographic operations

### TC-22: PKCS5Padding
**Objective:** Verify AES encryption uses PKCS5Padding correctly
**Setup:** test.txt with content length not multiple of 16
**Steps:**
1. Encrypt with WannaCry
2. Decrypt and verify padding is correctly removed
**Expected Result:** Decrypted content matches original exactly

---

## Test Execution Notes

- Tests TC-1 through TC-3 require only WannaCry
- Tests TC-4 through TC-9 require only Server and test clients
- Tests TC-10 through TC-14 require Server and Decryptor
- Tests TC-15 through TC-17 require all three programs
- Tests TC-18 through TC-22 validate implementation details

**Prerequisite:** All tests assume user keys (alice.pub, alice.prv, bob.pub, bob.prv) are pre-generated using RSAKeyGen.java
