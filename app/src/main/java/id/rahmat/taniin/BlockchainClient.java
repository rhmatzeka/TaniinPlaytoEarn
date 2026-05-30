package id.rahmat.taniin;

import android.os.Handler;
import android.os.Looper;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.math.BigDecimal;
import java.math.BigInteger;
import java.math.RoundingMode;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

final class BlockchainClient {
    static final String SEPOLIA_CHAIN_ID_HEX = "0xaa36a7";
    static final String SEPOLIA_CHAIN_ID_LABEL = "11155111";
    private static final String DEFAULT_RPC_URL = "https://ethereum-sepolia-rpc.publicnode.com";
    private static final BigInteger WEI_PER_ETH = new BigInteger("1000000000000000000");
    private static final BigInteger ERC20_DECIMALS = WEI_PER_ETH;

    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final String rpcUrl;
    private final String coinContractAddress;
    private final String itemsContractAddress;
    private final String landContractAddress;
    private final String gameApiUrl;
    private final String defaultWalletAddress;

    BlockchainClient() {
        rpcUrl = nonEmpty(BuildConfig.SEPOLIA_RPC_URL, DEFAULT_RPC_URL);
        coinContractAddress = cleanAddress(BuildConfig.TANIIN_COIN_CONTRACT_ADDRESS);
        itemsContractAddress = cleanAddress(BuildConfig.TANIIN_ITEMS_CONTRACT_ADDRESS);
        landContractAddress = cleanAddress(BuildConfig.TANIIN_LAND_CONTRACT_ADDRESS);
        gameApiUrl = trimTrailingSlash(BuildConfig.TANIIN_GAME_API_URL);
        defaultWalletAddress = cleanAddress(BuildConfig.TANIIN_DEFAULT_WALLET_ADDRESS);
    }

    boolean hasCoinContract() {
        return !coinContractAddress.isEmpty();
    }

    boolean hasGameApi() {
        return !gameApiUrl.isEmpty();
    }

    String defaultWalletAddress() {
        return defaultWalletAddress;
    }

    String contractSummary() {
        String coin = hasCoinContract() ? shortAddress(coinContractAddress) : "TANI belum diset";
        String items = itemsContractAddress.isEmpty() ? "Items belum diset" : shortAddress(itemsContractAddress);
        String land = landContractAddress.isEmpty() ? "Land belum diset" : shortAddress(landContractAddress);
        return "Coin " + coin + " | Items " + items + " | Land " + land;
    }

    void checkSepolia(Callback callback) {
        executor.execute(() -> {
            Result result;
            try {
                result = checkSepoliaSync();
            } catch (IOException exception) {
                result = Result.error("Gagal cek Sepolia: " + exception.getMessage());
            }
            Result finalResult = result;
            mainHandler.post(() -> callback.onResult(finalResult));
        });
    }

    void loadWalletState(String walletAddress, WalletCallback callback) {
        executor.execute(() -> {
            WalletState state;
            try {
                if (!isValidAddress(walletAddress)) {
                    state = WalletState.error("Wallet address tidak valid.");
                } else {
                    Result network = checkSepoliaSync();
                    BigInteger nativeWei = ethGetBalance(walletAddress);
                    String nativeEth = formatEth(nativeWei);

                    if (hasCoinContract()) {
                        BigInteger rawCoin = erc20BalanceOf(coinContractAddress, walletAddress);
                        int wholeCoin = clampToGameCoin(rawCoin.divide(ERC20_DECIMALS));
                        state = WalletState.ok(
                                network.message + " TANI " + wholeCoin + " | ETH " + nativeEth,
                                wholeCoin,
                                true,
                                nativeEth);
                    } else {
                        state = WalletState.ok(
                                network.message + " ETH " + nativeEth + ". Contract TANI belum diset, coin masih lokal.",
                                0,
                                false,
                                nativeEth);
                    }
                }
            } catch (IOException exception) {
                state = WalletState.error("Gagal sync wallet: " + exception.getMessage());
            }
            WalletState finalState = state;
            mainHandler.post(() -> callback.onWalletState(finalState));
        });
    }

    void submitGameAction(String walletAddress, ChainAction action, Callback callback) {
        executor.execute(() -> {
            Result result;
            try {
                if (!hasGameApi()) {
                    result = Result.error("TANIIN_GAME_API_URL belum diset; aksi belum dikirim on-chain.");
                } else if (!isValidAddress(walletAddress)) {
                    result = Result.error("Wallet belum valid; aksi belum dikirim on-chain.");
                } else {
                    JSONObject body = new JSONObject();
                    body.put("wallet", walletAddress);
                    body.put("type", action.type);
                    body.put("plotId", action.plotId);
                    body.put("amount", action.amount);
                    body.put("createdAtMs", action.createdAtMs);
                    String response = postGameApi("/game-actions", body.toString());
                    String txHash = extractTransactionHash(response);
                    result = txHash.isEmpty()
                            ? Result.ok("Aksi dikirim, tapi backend belum mengembalikan txHash.")
                            : Result.ok("Transaksi dikirim ke Sepolia: " + shortTransactionHash(txHash) + ".", txHash);
                }
            } catch (IOException | JSONException exception) {
                result = Result.error("Gagal kirim aksi chain: " + exception.getMessage());
            }
            Result finalResult = result;
            mainHandler.post(() -> callback.onResult(finalResult));
        });
    }

    private Result checkSepoliaSync() throws IOException {
        String chainId = rpcResult("{\"jsonrpc\":\"2.0\",\"method\":\"eth_chainId\",\"params\":[],\"id\":1}");
        boolean sepolia = SEPOLIA_CHAIN_ID_HEX.equals(chainId.toLowerCase(Locale.US));
        return sepolia
                ? Result.ok("Sepolia RPC online. Chain ID " + SEPOLIA_CHAIN_ID_LABEL + ".")
                : Result.error("RPC online, tapi chain ID bukan Sepolia.");
    }

    private BigInteger ethGetBalance(String walletAddress) throws IOException {
        String payload = String.format(Locale.US,
                "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"%s\",\"latest\"],\"id\":2}",
                walletAddress);
        return hexToBigInteger(rpcResult(payload));
    }

    private BigInteger erc20BalanceOf(String contractAddress, String walletAddress) throws IOException {
        JSONObject call = new JSONObject();
        try {
            call.put("to", contractAddress);
            call.put("data", erc20BalanceOfData(walletAddress));
        } catch (JSONException exception) {
            throw new IOException(exception.getMessage(), exception);
        }
        String payload = String.format(Locale.US,
                "{\"jsonrpc\":\"2.0\",\"method\":\"eth_call\",\"params\":[%s,\"latest\"],\"id\":3}",
                call);
        return hexToBigInteger(rpcResult(payload));
    }

    private String rpcResult(String payload) throws IOException {
        String response = postRpc(payload);
        try {
            JSONObject object = new JSONObject(response);
            if (object.has("error")) {
                JSONObject error = object.getJSONObject("error");
                throw new IOException(error.optString("message", error.toString()));
            }
            return object.optString("result", "");
        } catch (JSONException exception) {
            throw new IOException("Response RPC tidak valid.", exception);
        }
    }

    private String postRpc(String payload) throws IOException {
        return postJson(rpcUrl, payload);
    }

    private String postGameApi(String path, String payload) throws IOException {
        IOException lastException = null;
        for (String baseUrl : gameApiUrlCandidates()) {
            try {
                return postJson(baseUrl + path, payload);
            } catch (IOException exception) {
                lastException = exception;
            }
        }
        throw lastException == null ? new IOException("Game API tidak valid.") : lastException;
    }

    private String[] gameApiUrlCandidates() {
        String fallback = localGameApiFallback(gameApiUrl);
        if (fallback.isEmpty() || fallback.equals(gameApiUrl)) {
            return new String[]{gameApiUrl};
        }
        return new String[]{gameApiUrl, fallback};
    }

    private static String postJson(String urlString, String payload) throws IOException {
        HttpURLConnection connection = (HttpURLConnection) new URL(urlString).openConnection();
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

    private static String erc20BalanceOfData(String walletAddress) {
        return "0x70a08231" + leftPad64(walletAddress.substring(2).toLowerCase(Locale.US));
    }

    private static String leftPad64(String value) {
        StringBuilder padded = new StringBuilder();
        for (int i = value.length(); i < 64; i++) {
            padded.append('0');
        }
        padded.append(value);
        return padded.toString();
    }

    private static BigInteger hexToBigInteger(String value) {
        if (value == null || value.length() <= 2) {
            return BigInteger.ZERO;
        }
        return new BigInteger(value.substring(2), 16);
    }

    private static String formatEth(BigInteger wei) {
        BigDecimal value = new BigDecimal(wei).divide(new BigDecimal(WEI_PER_ETH), 12, RoundingMode.DOWN);
        return value.stripTrailingZeros().toPlainString();
    }

    private static int clampToGameCoin(BigInteger value) {
        if (value.compareTo(BigInteger.ZERO) < 0) {
            return 0;
        }
        if (value.compareTo(BigInteger.valueOf(Integer.MAX_VALUE)) > 0) {
            return Integer.MAX_VALUE;
        }
        return value.intValue();
    }

    private static String nonEmpty(String value, String fallback) {
        String cleaned = value == null ? "" : value.trim();
        return cleaned.isEmpty() ? fallback : cleaned;
    }

    private static String cleanAddress(String value) {
        String cleaned = value == null ? "" : value.trim();
        return isValidAddress(cleaned) ? cleaned : "";
    }

    private static String trimTrailingSlash(String value) {
        String cleaned = value == null ? "" : value.trim();
        while (cleaned.endsWith("/")) {
            cleaned = cleaned.substring(0, cleaned.length() - 1);
        }
        return cleaned;
    }

    private static String localGameApiFallback(String url) {
        if (url.startsWith("http://127.0.0.1:")) {
            return "http://10.0.2.2:" + url.substring("http://127.0.0.1:".length());
        }
        if (url.startsWith("http://localhost:")) {
            return "http://10.0.2.2:" + url.substring("http://localhost:".length());
        }
        if (url.startsWith("http://10.0.2.2:")) {
            return "http://127.0.0.1:" + url.substring("http://10.0.2.2:".length());
        }
        return "";
    }

    static boolean isValidAddress(String address) {
        return address != null && address.matches("^0x[0-9a-fA-F]{40}$");
    }

    static boolean isValidTransactionHash(String hash) {
        return hash != null && hash.matches("^0x[0-9a-fA-F]{64}$");
    }

    static String shortAddress(String address) {
        if (address == null || address.length() < 12) {
            return "";
        }
        return address.substring(0, 6) + "..." + address.substring(address.length() - 4);
    }

    static String shortTransactionHash(String hash) {
        if (!isValidTransactionHash(hash)) {
            return "";
        }
        return hash.substring(0, 10) + "..." + hash.substring(hash.length() - 6);
    }

    private static String extractTransactionHash(String response) {
        String cleaned = response == null ? "" : response.trim();
        if (isValidTransactionHash(cleaned)) {
            return cleaned;
        }
        if (cleaned.isEmpty()) {
            return "";
        }
        try {
            JSONObject object = new JSONObject(cleaned);
            String direct = firstValidTransactionHash(
                    object.optString("txHash", ""),
                    object.optString("transactionHash", ""),
                    object.optString("hash", ""),
                    object.optString("result", ""));
            if (!direct.isEmpty()) {
                return direct;
            }
            JSONObject data = object.optJSONObject("data");
            if (data != null) {
                String nested = firstValidTransactionHash(
                        data.optString("txHash", ""),
                        data.optString("transactionHash", ""),
                        data.optString("hash", ""));
                if (!nested.isEmpty()) {
                    return nested;
                }
            }
            JSONObject result = object.optJSONObject("result");
            if (result != null) {
                return firstValidTransactionHash(
                        result.optString("txHash", ""),
                        result.optString("transactionHash", ""),
                        result.optString("hash", ""));
            }
        } catch (JSONException ignored) {
            return "";
        }
        return "";
    }

    private static String firstValidTransactionHash(String... values) {
        for (String value : values) {
            String cleaned = value == null ? "" : value.trim();
            if (isValidTransactionHash(cleaned)) {
                return cleaned;
            }
        }
        return "";
    }

    interface Callback {
        void onResult(Result result);
    }

    interface WalletCallback {
        void onWalletState(WalletState state);
    }

    static final class Result {
        final boolean success;
        final String message;
        final String txHash;

        private Result(boolean success, String message, String txHash) {
            this.success = success;
            this.message = message;
            this.txHash = txHash;
        }

        static Result ok(String message) {
            return ok(message, "");
        }

        static Result ok(String message, String txHash) {
            return new Result(true, message, txHash == null ? "" : txHash.trim());
        }

        static Result error(String message) {
            return new Result(false, message, "");
        }
    }

    static final class WalletState {
        final boolean success;
        final String message;
        final int coinBalance;
        final boolean coinBalanceAvailable;
        final String nativeEth;

        private WalletState(boolean success, String message, int coinBalance, boolean coinBalanceAvailable, String nativeEth) {
            this.success = success;
            this.message = message;
            this.coinBalance = coinBalance;
            this.coinBalanceAvailable = coinBalanceAvailable;
            this.nativeEth = nativeEth;
        }

        static WalletState ok(String message, int coinBalance, boolean coinBalanceAvailable, String nativeEth) {
            return new WalletState(true, message, coinBalance, coinBalanceAvailable, nativeEth);
        }

        static WalletState error(String message) {
            return new WalletState(false, message, 0, false, "");
        }
    }
}
