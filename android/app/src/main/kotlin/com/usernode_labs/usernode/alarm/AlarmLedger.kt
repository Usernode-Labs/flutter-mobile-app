package com.usernode_labs.usernode.alarm

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject

class AlarmLedger(context: Context) {
    companion object {
        private const val PREFS_NAME = "alarm_prefs"
        private const val LEDGER_PREFIX = "alarm_ledger_"
        private const val LEDGER_IDS_KEY = "alarm_ledger_ids"
        private const val MAX_LEDGER_ENTRIES = 128
    }

    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun recordScheduled(
        alarmId: String,
        globalSlot: Int,
        triggerAtMs: Long,
        scheduledAtMs: Long,
        scheduledElapsedRealtimeMs: Long,
        triggerElapsedRealtimeMs: Long,
        requestedDelayMs: Long,
        effectiveDelayMs: Long,
        data: Map<String, Any>
    ) {
        val json = JSONObject()
        json.put("alarmId", alarmId)
        json.put("globalSlot", globalSlot)
        json.put("scheduledAtMs", scheduledAtMs)
        json.put("triggerAtMs", triggerAtMs)
        json.put("nativeTriggerAtMs", triggerAtMs)
        json.put("scheduledElapsedRealtimeMs", scheduledElapsedRealtimeMs)
        json.put("triggerElapsedRealtimeMs", triggerElapsedRealtimeMs)
        json.put("requestedDelayMs", requestedDelayMs)
        json.put("effectiveDelayMs", effectiveDelayMs)
        json.put("alarmTimeMs", triggerAtMs)
        json.put("scheduleStatus", "scheduled")
        putData(json, data)
        save(alarmId, json)
    }

    fun recordScheduleFailed(
        alarmId: String,
        globalSlot: Int,
        triggerAtMs: Long,
        scheduledAtMs: Long,
        scheduledElapsedRealtimeMs: Long,
        triggerElapsedRealtimeMs: Long,
        requestedDelayMs: Long,
        effectiveDelayMs: Long,
        data: Map<String, Any>,
        failureReason: String
    ) {
        val json = JSONObject()
        json.put("alarmId", alarmId)
        json.put("globalSlot", globalSlot)
        json.put("scheduledAtMs", scheduledAtMs)
        json.put("triggerAtMs", triggerAtMs)
        json.put("nativeTriggerAtMs", triggerAtMs)
        json.put("scheduledElapsedRealtimeMs", scheduledElapsedRealtimeMs)
        json.put("triggerElapsedRealtimeMs", triggerElapsedRealtimeMs)
        json.put("requestedDelayMs", requestedDelayMs)
        json.put("effectiveDelayMs", effectiveDelayMs)
        json.put("alarmTimeMs", triggerAtMs)
        json.put("scheduleStatus", "failed")
        json.put("scheduleFailureReason", failureReason)
        putData(json, data)
        save(alarmId, json)
    }

    fun recordReceiverEntered(
        alarmId: String,
        globalSlot: Int,
        alarmTimeMs: Long,
        nativeTriggerAtMs: Long?,
        receiverEnteredAtMs: Long,
        receiverElapsedRealtimeMs: Long,
        receiverLatencyMs: Long,
        nativeDeliveryLatencyMs: Long?,
        elapsedDeliveryLatencyMs: Long?,
        triggerElapsedRealtimeMs: Long?,
        purpose: String?,
        schedulerReason: String?,
        nodeRunning: Boolean
    ) {
        val json = read(alarmId)
        json.put("alarmId", alarmId)
        json.put("globalSlot", globalSlot)
        if (alarmTimeMs > 0) {
            json.put("alarmTimeMs", alarmTimeMs)
            if (!json.has("triggerAtMs")) {
                json.put("triggerAtMs", alarmTimeMs)
            }
        }
        nativeTriggerAtMs?.takeIf { it > 0 }?.let {
            json.put("nativeTriggerAtMs", it)
            json.put("triggerAtMs", it)
        }
        triggerElapsedRealtimeMs?.takeIf { it > 0 }?.let {
            json.put("triggerElapsedRealtimeMs", it)
        }
        json.put("receiverEnteredAtMs", receiverEnteredAtMs)
        json.put("receiverSystemTimeMs", receiverEnteredAtMs)
        json.put("receiverElapsedRealtimeMs", receiverElapsedRealtimeMs)
        json.put("receiverLatencyMs", receiverLatencyMs)
        nativeDeliveryLatencyMs?.let { json.put("nativeDeliveryLatencyMs", it) }
        elapsedDeliveryLatencyMs?.let { json.put("elapsedDeliveryLatencyMs", it) }
        json.put("nodeRunning", nodeRunning)
        purpose?.let { json.put("purpose", it) }
        schedulerReason?.let { json.put("schedulerReason", it) }
        save(alarmId, json)
    }

    fun recordFlutterEventSent(alarmId: String, sentAtMs: Long) {
        val json = read(alarmId)
        json.put("alarmId", alarmId)
        json.put("flutterEventSentAtMs", sentAtMs)
        save(alarmId, json)
    }

    fun recordCancelled(alarmId: String, reason: String, cancelledAtMs: Long) {
        val json = read(alarmId)
        json.put("alarmId", alarmId)
        json.put("cancelledAtMs", cancelledAtMs)
        json.put("cancelReason", reason)
        save(alarmId, json)
    }

    fun getState(
        alarmId: String,
        pendingIntentExists: Boolean,
        canScheduleExactAlarms: Boolean
    ): Map<String, Any?> {
        val map = jsonToMap(read(alarmId))
        map["alarmId"] = alarmId
        map["pendingIntentExists"] = pendingIntentExists
        map["canScheduleExactAlarms"] = canScheduleExactAlarms
        return map
    }

    private fun putData(json: JSONObject, data: Map<String, Any>) {
        putIfSupported(json, "epoch", data["epoch"])
        putIfSupported(json, "slotTimeMs", data["slotTimeMs"])
        putIfSupported(json, "alarmTimeMs", data["alarmTimeMs"])
        putIfSupported(json, "rustSlotTimeMs", data["rustSlotTimeMs"])
        putIfSupported(json, "localSlotTimeMs", data["localSlotTimeMs"])
        putIfSupported(json, "rustWakeTimeMs", data["rustWakeTimeMs"])
        putIfSupported(json, "localWakeTimeMs", data["localWakeTimeMs"])
        putIfSupported(json, "clockDriftMs", data["clockDriftMs"])
        putIfSupported(json, "nodeTimeMsAtSchedule", data["nodeTimeMsAtSchedule"])
        putIfSupported(json, "systemTimeMsAtSchedule", data["systemTimeMsAtSchedule"])
        putIfSupported(json, "clockDriftSampleAgeMs", data["clockDriftSampleAgeMs"])
        putIfSupported(json, "globalSlot", data["globalSlot"] ?: data["global_slot"])
        putIfSupported(json, "purpose", data["purpose"])
        putIfSupported(json, "schedulerReason", data["reason"])
        putIfSupported(json, "nodeRunning", data["nodeRunning"])
    }

    private fun putIfSupported(json: JSONObject, key: String, value: Any?) {
        when (value) {
            is String -> json.put(key, value)
            is Int -> json.put(key, value)
            is Long -> json.put(key, value)
            is Boolean -> json.put(key, value)
            is Double -> json.put(key, value)
            is Float -> json.put(key, value.toDouble())
        }
    }

    private fun read(alarmId: String): JSONObject {
        val raw = prefs.getString(ledgerKey(alarmId), null) ?: return JSONObject()
        return try {
            JSONObject(raw)
        } catch (_: Exception) {
            JSONObject()
        }
    }

    private fun save(alarmId: String, json: JSONObject) {
        val ids = ledgerIds().toMutableList()
        ids.remove(alarmId)
        ids.add(0, alarmId)

        val editor = prefs.edit()
            .putString(ledgerKey(alarmId), json.toString())
            .putString(LEDGER_IDS_KEY, ids.take(MAX_LEDGER_ENTRIES).joinToString(","))

        ids.drop(MAX_LEDGER_ENTRIES).forEach { editor.remove(ledgerKey(it)) }
        editor.commit()
    }

    private fun ledgerIds(): List<String> {
        val raw = prefs.getString(LEDGER_IDS_KEY, "") ?: ""
        if (raw.isEmpty()) return emptyList()
        return raw.split(",").filter { it.isNotEmpty() }
    }

    private fun jsonToMap(json: JSONObject): MutableMap<String, Any?> {
        val map = mutableMapOf<String, Any?>()
        val keys = json.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            val value = json.opt(key)
            if (value != JSONObject.NULL) {
                map[key] = value
            }
        }
        return map
    }

    private fun ledgerKey(alarmId: String): String = "$LEDGER_PREFIX$alarmId"
}
