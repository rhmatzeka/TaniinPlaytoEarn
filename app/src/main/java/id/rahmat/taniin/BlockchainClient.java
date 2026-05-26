package id.rahmat.taniin;

import android.os.Handler;
import android.os.Looper;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

final class BlockchainClient {
    static final String SEPOLIA_CHAIN_ID_HEX = "0xaa36a7";
    static final String SEPOLIA_CHAIN_ID_LABEL = "11155111";
    static final String RPC_URL = "https://ethereum-sepolia-rpc.publicnode.com";

    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    void checkSepolia(Callback callback) {
        executor.execute(() -> {
            Result result;
            try {
                String response = postRpc("{\"jsonrpc\":\"2.0\",\"method\":\"eth_chainId\",\"params\":[],\"id\":1}");
                boolean sepolia = response.toLowerCase(Locale.US).contains(SEPOLIA_CHAIN_ID_HEX);
                result = sepolia
                        ? Result.ok("Sepolia RPC online. Chain ID " + SEPOLIA_CHAIN_ID_LABEL + ".")
                        : Result.error("RPC online, tapi chain ID bukan Sepolia.");
            } catch (IOException exception) {
                result = Result.error("Gagal cek Sepolia: " + exception.getMessage());
            }
            Result finalResult = result;
            mainHandler.post(() -> callback.onResult(finalResult));
        });
    }

    private String postRpc(String payload) throws IOException {
        HttpURLConnection connection = (HttpURLConnection) new URL(RPC_URL).openConnection();
        connection.setConnectTimeout(9000);
        connection.setReadTimeout(9000);
        connection.setRequestMethod("POST");
        connection.setDoOutput(true);
        connection.setRequestProperty("Content-Type", "application/json");
        byte[] body = payload.getBytes(StandardCharsets.UTF_8);
        connection.setFixedLengthStreamingMode(body.length);
        try (OutputStream outputStream = connection.getOutputStream()) {
            outputStream.write(body);
        }

        int status = connection.getResponseCode();
        InputStream inputStream = status >= 200 && status < 300
                ? connection.getInputStream()
                : connection.getErrorStream();
        StringBuilder response = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(inputStream, StandardCharsets.UTF_8))) {
            String line;
            while ((line = reader.readLine()) != null) {
                response.append(line);
            }
        } finally {
            connection.disconnect();
        }
        if (status < 200 || status >= 300) {
            throw new IOException("HTTP " + status + " " + response);
        }
        return response.toString();
    }

    interface Callback {
        void onResult(Result result);
    }

    static final class Result {
        final boolean success;
        final String message;

        private Result(boolean success, String message) {
            this.success = success;
            this.message = message;
        }

        static Result ok(String message) {
            return new Result(true, message);
        }

        static Result error(String message) {
            return new Result(false, message);
        }
    }
}
