package id.rahmat.taniin;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.Locale;

final class ChainHistoryEntry {
    final String label;
    final String type;
    final long createdAtMs;
    String status;
    String txHash;

    ChainHistoryEntry(String label, String type, long createdAtMs, String status, String txHash) {
        this.label = label == null ? "Transaksi" : label;
        this.type = type == null ? "" : type;
        this.createdAtMs = createdAtMs;
        this.status = normalizeStatus(status);
        this.txHash = txHash == null ? "" : txHash;
    }

    static String normalizeStatus(String status) {
        String cleaned = status == null ? "" : status.trim();
        String lower = cleaned.toLowerCase(Locale.US);
        if (lower.contains("gagal kirim") || lower.contains("gagal sync")) {
            return "belum sync";
        }
        if ("pending signer".equals(lower) || "pending lokal".equals(lower)) {
            return "belum on-chain";
        }
        if ("pending wallet".equals(lower)) {
            return "butuh wallet";
        }
        if ("lokal".equals(lower)
                || "berhasil".equals(lower)) {
            return "lokal tersimpan";
        }
        if ("dikirim".equals(lower)) {
            return "terkirim signer";
        }
        return cleaned;
    }

    JSONObject toJson() throws JSONException {
        JSONObject object = new JSONObject();
        object.put("label", label);
        object.put("type", type);
        object.put("createdAtMs", createdAtMs);
        object.put("status", status);
        object.put("txHash", txHash);
        return object;
    }

    static ChainHistoryEntry fromJson(JSONObject object) {
        if (object == null) {
            return null;
        }
        String label = object.optString("label", "Transaksi");
        String type = object.optString("type", "");
        long createdAtMs = object.optLong("createdAtMs", System.currentTimeMillis());
        String status = object.optString("status", "");
        String txHash = object.optString("txHash", "");
        if (!BlockchainClient.isValidTransactionHash(txHash)) {
            txHash = "";
        }
        return new ChainHistoryEntry(label, type, createdAtMs, status, txHash);
    }
}
