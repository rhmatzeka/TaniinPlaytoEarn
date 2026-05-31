package id.rahmat.taniin;

import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.List;

final class ChainHistoryStore {
    private final SharedPreferences preferences;
    private final String preferenceKey;
    private final int limit;

    ChainHistoryStore(SharedPreferences preferences, String preferenceKey, int limit) {
        this.preferences = preferences;
        this.preferenceKey = preferenceKey;
        this.limit = limit;
    }

    ChainHistoryEntry add(List<ChainHistoryEntry> history, ChainAction action, String status) {
        ChainHistoryEntry entry = new ChainHistoryEntry(action.label(), action.type, action.createdAtMs, status, "");
        history.add(0, entry);
        trim(history);
        save(history);
        return entry;
    }

    void update(List<ChainHistoryEntry> history, ChainHistoryEntry entry, String status, String txHash) {
        entry.status = ChainHistoryEntry.normalizeStatus(status);
        if (BlockchainClient.isValidTransactionHash(txHash)) {
            entry.txHash = txHash.trim();
        }
        save(history);
    }

    void load(List<ChainHistoryEntry> history) {
        history.clear();
        String raw = preferences.getString(preferenceKey, "");
        if (raw == null || raw.trim().isEmpty()) {
            return;
        }
        try {
            JSONArray array = new JSONArray(raw);
            for (int i = 0; i < array.length(); i++) {
                JSONObject object = array.optJSONObject(i);
                ChainHistoryEntry entry = ChainHistoryEntry.fromJson(object);
                if (entry != null) {
                    history.add(entry);
                }
            }
            trim(history);
            save(history);
        } catch (JSONException exception) {
            history.clear();
            preferences.edit().remove(preferenceKey).apply();
        }
    }

    void save(List<ChainHistoryEntry> history) {
        try {
            JSONArray array = new JSONArray();
            for (ChainHistoryEntry entry : history) {
                array.put(entry.toJson());
            }
            preferences.edit().putString(preferenceKey, array.toString()).apply();
        } catch (JSONException ignored) {
            // A malformed local history entry should not block gameplay saves.
        }
    }

    private void trim(List<ChainHistoryEntry> history) {
        while (history.size() > limit) {
            history.remove(history.size() - 1);
        }
    }
}
