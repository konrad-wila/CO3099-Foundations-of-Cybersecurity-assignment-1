import javax.crypto.Cipher;
import java.io.*;
import java.net.ServerSocket;
import java.net.Socket;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.PublicKey;
import java.security.Signature;
import java.security.spec.PKCS8EncodedKeySpec;
import java.security.spec.X509EncodedKeySpec;
import java.util.Base64;

public class Server {
    
    private static int port;
    private static PrivateKey masterPrivateKey;
    
    public static void main(String[] args) throws Exception {
        if (args.length < 1) {
            System.err.println("Usage: java Server <port>");
            System.exit(1);
        }
        
        port = Integer.parseInt(args[0]);
        
        // Load master RSA private key from server-b64.prv
        loadMasterPrivateKey();
        
        // Start listening for client connections
        startServer();
    }
    
    /**
     * Load master RSA private key from Base64-encoded file
     */
    private static void loadMasterPrivateKey() throws Exception {
        // Read the Base64-encoded private key from file
        String keyContent = Files.readString(Paths.get("server-b64.prv")).trim();
        
        // Decode Base64
        byte[] decodedKey = Base64.getDecoder().decode(keyContent);
        
        // Create key spec and generate private key
        PKCS8EncodedKeySpec keySpec = new PKCS8EncodedKeySpec(decodedKey);
        KeyFactory keyFactory = KeyFactory.getInstance("RSA");
        masterPrivateKey = keyFactory.generatePrivate(keySpec);
    }
    
    /**
     * Start server and listen for client connections
     */
    private static void startServer() throws Exception {
        ServerSocket serverSocket = new ServerSocket(port);
        System.out.println("Server started on port " + port);
        
        while (true) {
            Socket clientSocket = serverSocket.accept();
            handleClient(clientSocket);
        }
    }
    
    /**
     * Handle a single client connection
     */
    private static void handleClient(Socket clientSocket) throws Exception {
        try {
            DataInputStream dis = new DataInputStream(clientSocket.getInputStream());
            DataOutputStream dos = new DataOutputStream(clientSocket.getOutputStream());
            
            // Read userid
            String userid = dis.readUTF();
            
            // Read encrypted AES key
            int aesKeyLength = dis.readInt();
            byte[] encryptedAesKey = new byte[aesKeyLength];
            dis.readFully(encryptedAesKey);
            
            // Read signature
            int signatureLength = dis.readInt();
            byte[] signature = new byte[signatureLength];
            dis.readFully(signature);
            
            // Verify signature
            if (verifySignature(userid, encryptedAesKey, signature)) {
                System.out.println("User " + userid + " connected.");
                System.out.println("Signature verified. Key decrypted and sent.");
                
                // Decrypt AES key using master private key
                byte[] decryptedAesKey = decryptAesKey(encryptedAesKey);
                
                // Send decrypted AES key to client
                dos.writeInt(decryptedAesKey.length);
                dos.write(decryptedAesKey);
                dos.flush();
                
            } else {
                System.out.println("User " + userid + " connected.");
                System.out.println("Signature not verified.");
                
                // Send error response
                dos.writeInt(-1);
                dos.flush();
            }
            
            clientSocket.close();
            
        } catch (Exception e) {
            System.err.println("Error handling client: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    /**
     * Verify signature using user's public key
     * The signature is over the userid and encrypted AES key
     */
    private static boolean verifySignature(String userid, byte[] encryptedAesKey, byte[] signature) throws Exception {
        try {
            // Load user's public key
            PublicKey userPublicKey = loadUserPublicKey(userid);
            
            if (userPublicKey == null) {
                return false;
            }
            
            // Create the data that was signed: userid + encryptedAesKey
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            DataOutputStream dos = new DataOutputStream(baos);
            dos.writeUTF(userid);
            dos.write(encryptedAesKey);
            byte[] signedData = baos.toByteArray();
            
            // Verify signature
            Signature sig = Signature.getInstance("SHA256withRSA");
            sig.initVerify(userPublicKey);
            sig.update(signedData);
            
            return sig.verify(signature);
            
        } catch (Exception e) {
            return false;
        }
    }
    
    /**
     * Load user's public key from userid.pub file (binary X.509 format)
     */
    private static PublicKey loadUserPublicKey(String userid) throws Exception {
        String keyFileName = userid + ".pub";
        
        // Read binary X.509 encoded key
        byte[] keyBytes = Files.readAllBytes(Paths.get(keyFileName));
        X509EncodedKeySpec keySpec = new X509EncodedKeySpec(keyBytes);
        KeyFactory keyFactory = KeyFactory.getInstance("RSA");
        
        return keyFactory.generatePublic(keySpec);
    }
    
    /**
     * Decrypt AES key using master RSA private key
     */
    private static byte[] decryptAesKey(byte[] encryptedAesKey) throws Exception {
        Cipher cipher = Cipher.getInstance("RSA/ECB/PKCS1Padding");
        cipher.init(Cipher.DECRYPT_MODE, masterPrivateKey);
        return cipher.doFinal(encryptedAesKey);
    }
}
