import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.io.*;
import java.net.Socket;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.Signature;
import java.security.spec.PKCS8EncodedKeySpec;
import java.util.Base64;

public class Decryptor {
    
    private static String userid;
    private static String hostname;
    private static int port;
    
    public static void main(String[] args) throws Exception {
        if (args.length < 3) {
            System.err.println("Usage: java Decryptor <hostname> <port> <userid>");
            System.exit(1);
        }
        
        hostname = args[0];
        port = Integer.parseInt(args[1]);
        userid = args[2];
        
        try {
            // Display greeting message
            System.out.println("Dear customer, thank you for purchasing this software.");
            System.out.println("We are here to help you recover your files from this horrible attack.");
            System.out.println("Trying to decrypt files...");
            
            // Step 1: Read encrypted AES key from aes.key
            byte[] encryptedAesKey = Files.readAllBytes(Paths.get("aes.key"));
            
            // Step 2: Generate signature using userid and encrypted AES key
            PrivateKey userPrivateKey = loadUserPrivateKey(userid);
            byte[] signature = generateSignature(userid, encryptedAesKey, userPrivateKey);
            
            // Step 3: Connect to server and send request
            byte[] decryptedAesKey = connectToServerAndGetKey(hostname, port, userid, encryptedAesKey, signature);
            
            if (decryptedAesKey == null || decryptedAesKey.length == 0) {
                System.out.println("Unfortunately we cannot verify your identity.");
                System.out.println("Please try again, making sure that you have the correct signature");
                System.out.println("key in place and have entered the correct userid.");
                System.exit(1);
            }
            
            // Step 4: Decrypt test.txt.cry with received AES key
            decryptFile("test.txt.cry", "test.txt", decryptedAesKey);
            
            // Step 5: Display success message
            System.out.println("Success! Your files have now been recovered!");
            
        } catch (Exception e) {
            System.out.println("Unfortunately we cannot verify your identity.");
            System.out.println("Please try again, making sure that you have the correct signature");
            System.out.println("key in place and have entered the correct userid.");
            System.exit(1);
        }
    }
    
    /**
     * Load user's private key from userid.prv file (binary PKCS8 format)
     */
    private static PrivateKey loadUserPrivateKey(String userid) throws Exception {
        String keyFileName = userid + ".prv";
        
        // Read binary PKCS8 encoded key
        byte[] keyBytes = Files.readAllBytes(Paths.get(keyFileName));
        PKCS8EncodedKeySpec keySpec = new PKCS8EncodedKeySpec(keyBytes);
        KeyFactory keyFactory = KeyFactory.getInstance("RSA");
        
        return keyFactory.generatePrivate(keySpec);
    }
    
    /**
     * Generate signature using userid and encrypted AES key
     */
    private static byte[] generateSignature(String userid, byte[] encryptedAesKey, PrivateKey privateKey) throws Exception {
        // Create the data to sign: userid + encryptedAesKey
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        DataOutputStream dos = new DataOutputStream(baos);
        dos.writeUTF(userid);
        dos.write(encryptedAesKey);
        byte[] dataToSign = baos.toByteArray();
        
        // Sign using SHA256withRSA
        Signature sig = Signature.getInstance("SHA256withRSA");
        sig.initSign(privateKey);
        sig.update(dataToSign);
        
        return sig.sign();
    }
    
    /**
     * Connect to server and request decrypted AES key
     */
    private static byte[] connectToServerAndGetKey(String hostname, int port, String userid, 
                                                     byte[] encryptedAesKey, byte[] signature) throws Exception {
        Socket socket = new Socket(hostname, port);
        DataOutputStream dos = new DataOutputStream(socket.getOutputStream());
        DataInputStream dis = new DataInputStream(socket.getInputStream());
        
        try {
            // Send userid
            dos.writeUTF(userid);
            
            // Send encrypted AES key
            dos.writeInt(encryptedAesKey.length);
            dos.write(encryptedAesKey);
            
            // Send signature
            dos.writeInt(signature.length);
            dos.write(signature);
            dos.flush();
            
            // Read response
            int decryptedKeyLength = dis.readInt();
            
            if (decryptedKeyLength < 0) {
                return null;
            }
            
            byte[] decryptedAesKey = new byte[decryptedKeyLength];
            dis.readFully(decryptedAesKey);
            
            return decryptedAesKey;
            
        } finally {
            socket.close();
        }
    }
    
    /**
     * Decrypt file using AES key (256-bit, CBC mode, PKCS5Padding, zero IV)
     */
    private static void decryptFile(String inputFile, String outputFile, byte[] aesKeyBytes) throws Exception {
        // Create AES secret key from bytes
        SecretKey aesKey = new SecretKeySpec(aesKeyBytes, 0, aesKeyBytes.length, "AES");
        
        Cipher cipher = Cipher.getInstance("AES/CBC/PKCS5Padding");
        
        // Create IV with 16 zero bytes (same as encryption)
        byte[] iv = new byte[16];
        IvParameterSpec ivSpec = new IvParameterSpec(iv);
        
        cipher.init(Cipher.DECRYPT_MODE, aesKey, ivSpec);
        
        // Read encrypted file
        byte[] encryptedData = Files.readAllBytes(Paths.get(inputFile));
        
        // Decrypt data
        byte[] decryptedData = cipher.doFinal(encryptedData);
        
        // Write to output file
        try (FileOutputStream fos = new FileOutputStream(outputFile)) {
            fos.write(decryptedData);
        }
    }
}
