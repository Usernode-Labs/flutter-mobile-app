package com.usernode_labs.usernode.alarm

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject

class AlarmAuditStore(context: Context) {
    companion object {
        private const val PREFS_NAME = "alarm_prefs"
        private const val ACTIVE_SLOT_WAKE_RECORD_PREFIX = "active_slot_wake_alarm_"
        private const val ACTIVE_SLOT_WAKE_IDS_KEY = "active_slot_wake_alarm_ids"
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
        if (!isSlotWakeAlarm(alarmId, data["purpose"] as? String)) {
            removeActiveSlotWakeAlarm(alarmId)
            return
        }

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
        saveActiveSlotWakeAlarm(alarmId, json)
    }

    fun recordScheduleFailed(
        alarmId: String,
        data: Map<String, Any>
    ) {
        if (isSlotWakeAlarm(alarmId, data["purpose"] as? String)) {
            removeActiveSlotWakeAlarm(alarmId)
        }
    }

    fun recordReceiverEntered(
        alarmId: String,
        purpose: String?
    ) {
        if (isSlotWakeAlarm(alarmId, purpose)) {
            removeActiveSlotWakeAlarm(alarmId)
        }
    }

    fun recordCancelled(alarmId: String) {
        removeActiveSlotWakeAlarm(alarmId)
    }

    fun getState(
        alarmId: String,
        pendingIntentExists: Boolean,
        canScheduleExactAlarms: Boolean
    ): Map<String, Any?> {
        val map = jsonToMap(readActiveSlotWakeAlarm(alarmId))
        map["alarmId"] = alarmId
        map["pendingIntentExists"] = pendingIntentExists
        map["canScheduleExactAlarms"] = canScheduleExactAlarms
        return map
    }

    fun listActiveSlotWakeStates(
        pendingIntentExists: (String) -> Boolean,
        canScheduleExactAlarms: Boolean,
        nowMs: Long
    ): List<Map<String, Any?>> {
        val states = mutableListOf<Map<String, Any?>>()
        val retainedIds = mutableListOf<String>()
        val candidateIds = activeSlotWakeIds().distinct()

        for (alarmId in candidateIds) {
            val json = readActiveSlotWakeAlarm(alarmId)
            if (activeSlotWakePruneReason(alarmId, json, nowMs) != null) {
                removeActiveSlotWakeRecord(alarmId)
                continue
            }

            val map = jsonToMap(json)
            map["alarmId"] = alarmId
            map["pendingIntentExists"] = pendingIntentExists(alarmId)
            map["canScheduleExactAlarms"] = canScheduleExactAlarms
            states.add(map)
            retainedIds.add(alarmId)
        }

        if (retainedIds != activeSlotWakeIds()) {
            writeActiveSlotWakeIds(retainedIds)
        }

        return states
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

    private fun readActiveSlotWakeAlarm(alarmId: String): JSONObject {
        val raw = prefs.getString(activeSlotWakeRecordKey(alarmId), null)
            ?: return JSONObject()
        return try {
            JSONObject(raw)
        } catch (_: Exception) {
            JSONObject()
        }
    }

    private fun saveActiveSlotWakeAlarm(alarmId: String, json: JSONObject) {
        val ids = activeSlotWakeIds().toMutableList()
        ids.remove(alarmId)
        ids.add(0, alarmId)

        val editor = prefs.edit()
            .putString(activeSlotWakeRecordKey(alarmId), json.toString())
            .putString(ACTIVE_SLOT_WAKE_IDS_KEY, ids.distinct().joinToString(","))
        editor.commit()
    }

    private fun activeSlotWakeIds(): List<String> {
        val raw = prefs.getString(ACTIVE_SLOT_WAKE_IDS_KEY, "") ?: ""
        if (raw.isEmpty()) return emptyList()
        return raw.split(",").filter { it.isNotEmpty() }
    }

    private fun writeActiveSlotWakeIds(ids: List<String>) {
        val editor = prefs.edit()
        if (ids.isEmpty()) {
            editor.remove(ACTIVE_SLOT_WAKE_IDS_KEY)
        } else {
            editor.putString(ACTIVE_SLOT_WAKE_IDS_KEY, ids.distinct().joinToString(","))
        }
        editor.commit()
    }

    private fun removeActiveSlotWakeAlarm(alarmId: String) {
        val ids = activeSlotWakeIds().filterNot { it == alarmId }
        removeActiveSlotWakeRecord(alarmId)
        writeActiveSlotWakeIds(ids)
    }

    private fun removeActiveSlotWakeRecord(alarmId: String) {
        prefs.edit()
            .remove(activeSlotWakeRecordKey(alarmId))
            .apply()
    }

    private fun activeSlotWakePruneReason(
        alarmId: String,
        json: JSONObject,
        nowMs: Long
    ): String? {
        val purpose = json.opt("purpose") as? String
        if (!isSlotWakeAlarm(alarmId, purpose)) {
            return "not_slot_wake"
        }

        val scheduleStatus = json.opt("scheduleStatus") as? String
        if (scheduleStatus != null && scheduleStatus != "scheduled") {
            return "not_scheduled"
        }

        if (json.has("cancelledAtMs") || json.has("cancelReason")) {
            return "cancelled"
        }

        if (json.has("receiverEnteredAtMs")) {
            return "receiver_entered"
        }

        val slotTimeMs = longFromJson(json, "localSlotTimeMs")
            ?: longFromJson(json, "slotTimeMs")
        if (slotTimeMs == null || slotTimeMs <= 0L) {
            return "missing_slot_time"
        }

        if (slotTimeMs <= nowMs) {
            return "slot_time_past"
        }

        return null
    }

    private fun isSlotWakeAlarm(alarmId: String, purpose: String?): Boolean {
        return purpose == "slot_wake" || (purpose == null && alarmId.startsWith("slot_"))
    }

    private fun longFromJson(json: JSONObject, key: String): Long? {
        return when (val value = json.opt(key)) {
            is Number -> value.toLong()
            is String -> value.toLongOrNull()
            else -> null
        }
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

    private fun activeSlotWakeRecordKey(alarmId: String): String =
        "$ACTIVE_SLOT_WAKE_RECORD_PREFIX$alarmId"
}
