package com.usernode_labs.usernode.alarm

import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import android.app.NotificationManager
import android.app.NotificationChannel
import android.app.PendingIntent
import com.usernode_labs.usernode.MainActivity
import com.usernode_labs.usernode.R

class AlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "usernode/AlarmReceiver"
        private const val ACTION_EXACT_ALARM_PERMISSION_CHANGED =
            "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.i(TAG, "[AlarmReceiver] Broadcast received - Action: ${intent.action}, Time: ${System.currentTimeMillis()}")

        when (intent.action) {
            "com.usernode.app.SLOT_ALARM" -> {
                handleSlotAlarm(context, intent)
            }
            Intent.ACTION_BOOT_COMPLETED -> {
                handleBootCompleted(context)
            }
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                handlePackageReplaced(context)
            }
            ACTION_EXACT_ALARM_PERMISSION_CHANGED -> {
                handleExactAlarmPermissionStateChanged(context)
            }
            else -> {
                Log.w(TAG, "[AlarmReceiver] Unknown action received: ${intent.action}")
            }
        }
    }

    private fun handleSlotAlarm(context: Context, intent: Intent) {
        val alarmId = intent.getStringExtra("alarmId")
        val globalSlot = readGlobalSlotExtra(intent)
        val scheduledTimeMs = intent.getLongExtra("alarmTimeMs", -1L)
        val nativeScheduledAtMs = optionalLongExtra(intent, "nativeScheduledAtMs")
        val scheduledElapsedRealtimeMs = optionalLongExtra(intent, "scheduledElapsedRealtimeMs")
        val nativeTriggerAtMs = optionalLongExtra(intent, "nativeTriggerAtMs")
        val triggerElapsedRealtimeMs = optionalLongExtra(intent, "triggerElapsedRealtimeMs")
        val nodeRunning = intent.getBooleanExtra("nodeRunning", false)
        val reason = intent.getStringExtra("reason")
        val purpose = intent.getStringExtra("purpose")
        val recoveryGeneration = optionalLongExtra(intent, "recoveryGeneration")
        val bindingFingerprint = intent.getStringExtra("bindingFingerprint")

        Log.d(TAG, "[AlarmReceiver] Slot alarm details - ID: $alarmId, GlobalSlot: $globalSlot, Scheduled: $scheduledTimeMs")

        if (alarmId == null) {
            Log.e(TAG, "[AlarmReceiver] Missing alarmId in intent")
            return
        }
        if (globalSlot == null) {
            Log.e(TAG, "[AlarmReceiver] Missing or invalid globalSlot in intent")
            return
        }
        if (recoveryGeneration == null ||
            bindingFingerprint == null ||
            !NodeRecoveryLeaseStore.matches(
                context,
                recoveryGeneration,
                bindingFingerprint
            )
        ) {
            Log.i(TAG, "Ignoring stale slot alarm for recovery generation $recoveryGeneration")
            return
        }

        val currentTime = System.currentTimeMillis()
        val receiverElapsedRealtimeMs = SystemClock.elapsedRealtime()
        val latencyMs = if (scheduledTimeMs > 0) currentTime - scheduledTimeMs else 0L
        val nativeDeliveryLatencyMs = nativeTriggerAtMs?.let { currentTime - it }
        val elapsedDeliveryLatencyMs =
            triggerElapsedRealtimeMs?.let { receiverElapsedRealtimeMs - it }
        AlarmStateStore(context).recordReceiverEntered(
            alarmId = alarmId,
            globalSlot = globalSlot,
            alarmTimeMs = scheduledTimeMs,
            nativeTriggerAtMs = nativeTriggerAtMs,
            receiverEnteredAtMs = currentTime,
            receiverElapsedRealtimeMs = receiverElapsedRealtimeMs,
            receiverLatencyMs = latencyMs,
            nativeDeliveryLatencyMs = nativeDeliveryLatencyMs,
            elapsedDeliveryLatencyMs = elapsedDeliveryLatencyMs,
            triggerElapsedRealtimeMs = triggerElapsedRealtimeMs,
            purpose = purpose,
            schedulerReason = reason,
            nodeRunning = nodeRunning
        )
        Log.i(TAG, "[AlarmReceiver] ✓ Slot alarm FIRED for global slot $globalSlot (latency: ${latencyMs}ms)")

        // Enqueue native monitoring under the same lock as lease revocation.
        // SlotMonitoringService validates the captured lease again when the
        // start intent is delivered, closing both sides of the async handoff.
        val monitoringStarted = NodeRecoveryLeaseStore.runIfMatches(
            context,
            recoveryGeneration,
            bindingFingerprint
        ) {
            NativeWakeLockManager.acquire(context)
            val started = startMonitoringService(
                context = context,
                alarmId = alarmId,
                globalSlot = globalSlot,
                nodeRunning = nodeRunning,
                alarmTimeMs = scheduledTimeMs,
                recoveryGeneration = recoveryGeneration,
                bindingFingerprint = bindingFingerprint
            )
            if (!started) NativeWakeLockManager.release()
            started
        }
        if (!monitoringStarted) {
            Log.i(TAG, "Ignoring slot alarm superseded before native monitoring start")
            return
        }

        val eventData = mutableMapOf<String, Any?>(
            "alarmId" to alarmId,
            "globalSlot" to globalSlot,
            "alarmTimeMs" to scheduledTimeMs,
            "firedAtMs" to currentTime,
            "latencyMs" to latencyMs,
            "batteryLevel" to 0,
            "networkState" to "unknown",
            "nodeRunning" to nodeRunning
        )
        nativeScheduledAtMs?.let { eventData["nativeScheduledAtMs"] = it }
        scheduledElapsedRealtimeMs?.let { eventData["scheduledElapsedRealtimeMs"] = it }
        nativeTriggerAtMs?.let { eventData["nativeTriggerAtMs"] = it }
        triggerElapsedRealtimeMs?.let { eventData["triggerElapsedRealtimeMs"] = it }
        eventData["receiverElapsedRealtimeMs"] = receiverElapsedRealtimeMs
        nativeDeliveryLatencyMs?.let { eventData["nativeDeliveryLatencyMs"] = it }
        elapsedDeliveryLatencyMs?.let { eventData["elapsedDeliveryLatencyMs"] = it }
        reason?.let { eventData["reason"] = it }
        purpose?.let { eventData["purpose"] = it }
        eventData["recoveryGeneration"] = recoveryGeneration
        eventData["bindingFingerprint"] = bindingFingerprint

        val handler = AlarmMethodChannelHandler.getInstance()
        if (handler != null && handler.isActivityAttached()) {
            Log.d(TAG, "[AlarmReceiver] Sending android_alarm_fired event to attached Flutter activity")
            handler.sendEventToFlutter("android_alarm_fired", eventData)
        } else {
            Log.d(TAG, "[AlarmReceiver] Delivering android_alarm_fired via background engine")
            BackgroundAlarmEngine.sendAlarmEvent(
                context,
                "android_alarm_fired",
                eventData
            )
        }
        AlarmStateStore(context).recordFlutterEventSent(alarmId, System.currentTimeMillis())

    }

    private fun handleBootCompleted(context: Context) {
        if (!AlarmWatchdogScheduler.isEnabled(context)) {
            Log.i(TAG, "Ignoring boot recovery because block production watchdog is disabled")
            return
        }

        Log.i(TAG, "Device boot completed - starting monitoring")
        val lease = NodeRecoveryLeaseStore.load(context)
        val bindingFingerprint = lease.bindingFingerprint ?: return
        scheduleWatchdog(context, "boot_completed", lease)
        val monitoringStarted = NodeRecoveryLeaseStore.runIfMatches(
            context,
            lease.generation,
            bindingFingerprint
        ) {
            startMonitoringService(
                context = context,
                alarmId = "boot_completed",
                globalSlot = 0,
                nodeRunning = false,
                recoveryGeneration = lease.generation,
                bindingFingerprint = bindingFingerprint
            )
        }
        if (monitoringStarted) sendAuditRecoveryEvent(context, "boot_completed", lease)
    }

    private fun handlePackageReplaced(context: Context) {
        if (!AlarmWatchdogScheduler.isEnabled(context)) {
            Log.i(TAG, "Ignoring package update recovery because block production watchdog is disabled")
            return
        }

        Log.i(TAG, "App updated - starting monitoring")
        val lease = NodeRecoveryLeaseStore.load(context)
        val bindingFingerprint = lease.bindingFingerprint ?: return
        scheduleWatchdog(context, "package_replaced", lease)
        val monitoringStarted = NodeRecoveryLeaseStore.runIfMatches(
            context,
            lease.generation,
            bindingFingerprint
        ) {
            startMonitoringService(
                context = context,
                alarmId = "package_replaced",
                globalSlot = 0,
                nodeRunning = false,
                recoveryGeneration = lease.generation,
                bindingFingerprint = bindingFingerprint
            )
        }
        if (monitoringStarted) sendAuditRecoveryEvent(context, "package_replaced", lease)
    }

    private fun handleExactAlarmPermissionStateChanged(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }

        val eventType = if (granted) {
            "android_exact_alarm_permission_granted"
        } else {
            "android_exact_alarm_permission_denied"
        }
        if (granted && AlarmWatchdogScheduler.isEnabled(context)) {
            val lease = NodeRecoveryLeaseStore.load(context)
            scheduleWatchdog(context, "exact_alarm_permission_granted", lease)
        }
        sendFlutterEvent(
            context = context,
            eventType = eventType,
            eventData = mapOf(
                "source" to "permission_state_changed_broadcast",
                "stateChanged" to true
            )
        )
    }

    private fun scheduleWatchdog(
        context: Context,
        reason: String,
        lease: NodeRecoveryLeaseStore.Lease
    ) {
        AlarmWatchdogScheduler.ensurePeriodic(
            context,
            reason,
            lease.generation,
            lease.bindingFingerprint
        )
        AlarmWatchdogScheduler.enqueueOneTime(
            context,
            reason,
            lease.generation,
            lease.bindingFingerprint
        )
    }

    private fun sendAuditRecoveryEvent(
        context: Context,
        reason: String,
        lease: NodeRecoveryLeaseStore.Lease
    ) {
        val bindingFingerprint = lease.bindingFingerprint ?: return
        sendFlutterEvent(
            context = context,
            eventType = "android_alarm_recovery_requested",
            eventData = mapOf(
                "reason" to reason,
                "source" to "alarm_receiver",
                "recoveryGeneration" to lease.generation,
                "bindingFingerprint" to bindingFingerprint
            )
        )
    }

    private fun sendFlutterEvent(
        context: Context,
        eventType: String,
        eventData: Map<String, Any?>
    ) {
        val handler = AlarmMethodChannelHandler.getInstance()
        if (handler != null && handler.isActivityAttached()) {
            handler.sendEventToFlutter(eventType, eventData)
            return
        }

        BackgroundAlarmEngine.sendAlarmEvent(context, eventType, eventData)
    }

    private fun startMonitoringService(
        context: Context,
        alarmId: String,
        globalSlot: Int,
        nodeRunning: Boolean,
        alarmTimeMs: Long = -1L,
        recoveryGeneration: Long,
        bindingFingerprint: String
    ): Boolean {
        val serviceIntent = Intent(context, SlotMonitoringService::class.java).apply {
            action = SlotMonitoringService.ACTION_START_MONITORING
            putExtra("alarmId", alarmId)
            putExtra("globalSlot", globalSlot)
            putExtra("nodeRunning", nodeRunning)
            putExtra("alarmTimeMs", alarmTimeMs)
            putExtra(SlotMonitoringService.EXTRA_RECOVERY_GENERATION, recoveryGeneration)
            putExtra(SlotMonitoringService.EXTRA_BINDING_FINGERPRINT, bindingFingerprint)
        }

        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.i(TAG, "SlotMonitoringService started (alarmId=$alarmId, globalSlot=$globalSlot)")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start SlotMonitoringService", e)
            false
        }
    }

    private fun showFallbackNotification(
        context: Context,
        globalSlot: Int,
        scheduledTimeMs: Long
    ) {
        val channelId = "slot_alarm_fallback"
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Slot Alarm",
                NotificationManager.IMPORTANCE_HIGH
            )
            nm.createNotificationChannel(channel)
        }

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("globalSlot", globalSlot)
            putExtra("fromAlarm", true)
        }
        val piFlags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val pendingIntent = PendingIntent.getActivity(context, 0, launchIntent, piFlags)

        val scheduledTimeText = AlarmTimeFormatter.formatScheduledTime(scheduledTimeMs)
        val message = if (scheduledTimeText != null) {
            "Resumed for slot $globalSlot (scheduled $scheduledTimeText)"
        } else {
            "Resumed for slot $globalSlot"
        }

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.launch_background)
            .setContentTitle("Slot alarm fired")
            .setContentText(message)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .build()

        nm.notify(globalSlot, notification)
    }

    @Suppress("DEPRECATION")
    private fun readGlobalSlotExtra(intent: Intent): Int? {
        return numberExtra(intent, "globalSlot")
            ?: numberExtra(intent, "global_slot")
            ?: numberExtra(intent, "slotNumber")
    }

    @Suppress("DEPRECATION")
    private fun numberExtra(intent: Intent, key: String): Int? {
        val value = intent.extras?.get(key) ?: return null
        return when (value) {
            is Int -> value
            is Long -> value.toInt()
            is Number -> value.toInt()
            is String -> value.toIntOrNull()
            else -> null
        }?.takeIf { it >= 0 }
    }

    @Suppress("DEPRECATION")
    private fun optionalLongExtra(intent: Intent, key: String): Long? {
        if (!intent.hasExtra(key)) return null
        val value = intent.extras?.get(key) ?: return null
        return when (value) {
            is Int -> value.toLong()
            is Long -> value
            is Number -> value.toLong()
            is String -> value.toLongOrNull()
            else -> null
        }?.takeIf { it > 0 }
    }

}
