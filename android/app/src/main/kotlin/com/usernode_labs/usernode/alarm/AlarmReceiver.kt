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
import com.usernode_labs.usernode.session.NativeProducerWakeCoordinator
import com.usernode_labs.usernode.session.NativeScheduledWake
import com.usernode_labs.usernode.session.ProducerWakeSource
import android.util.Base64

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
        val applicationIncarnation = intent.getStringExtra(
            ApplicationIncarnationStore.EXTRA_APPLICATION_INCARNATION,
        )
        if (!ApplicationIncarnationStore(context).matches(applicationIncarnation)) {
            Log.w(TAG, "Ignoring slot alarm for stale application incarnation")
            return
        }
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

        Log.d(TAG, "[AlarmReceiver] Slot alarm details - ID: $alarmId, GlobalSlot: $globalSlot, Scheduled: $scheduledTimeMs")

        if (alarmId == null) {
            Log.e(TAG, "[AlarmReceiver] Missing alarmId in intent")
            return
        }
        if (globalSlot == null) {
            Log.e(TAG, "[AlarmReceiver] Missing or invalid globalSlot in intent")
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

        // Only the exact opaque selector persisted by the native coordinator
        // may acquire background runtime ownership. Old/pre-cutover alarms are
        // still recorded above for diagnostics, but cannot strand a wakelock
        // or foreground service.
        val scheduledWake = readNativeScheduledWake(intent, globalSlot)
        if (scheduledWake == null) {
            Log.w(TAG, "Ignoring an alarm without an exact native wake selector")
            return
        }
        val serviceIntent = Intent(context, SlotMonitoringService::class.java).apply {
            action = SlotMonitoringService.ACTION_START_MONITORING
            putExtra("alarmId", alarmId)
            putExtra("globalSlot", globalSlot)
            putExtra("nodeRunning", nodeRunning)
            putExtra("alarmTimeMs", scheduledTimeMs)
            putExtra(
                ApplicationIncarnationStore.EXTRA_APPLICATION_INCARNATION,
                applicationIncarnation,
            )
            nativeScheduledAtMs?.let { putExtra("nativeScheduledAtMs", it) }
            scheduledElapsedRealtimeMs?.let { putExtra("scheduledElapsedRealtimeMs", it) }
            nativeTriggerAtMs?.let { putExtra("nativeTriggerAtMs", it) }
            triggerElapsedRealtimeMs?.let { putExtra("triggerElapsedRealtimeMs", it) }
            putExtra("receiverElapsedRealtimeMs", receiverElapsedRealtimeMs)
            nativeDeliveryLatencyMs?.let { putExtra("nativeDeliveryLatencyMs", it) }
            elapsedDeliveryLatencyMs?.let { putExtra("elapsedDeliveryLatencyMs", it) }
            reason?.let { putExtra("reason", it) }
            purpose?.let { putExtra("purpose", it) }
        }
        val pending = goAsync()
        NativeProducerWakeCoordinator.submit(
            context,
            ProducerWakeSource.EXACT_ALARM,
            scheduledWake,
            monitoringIntent = serviceIntent,
        ) {
            pending.finish()
        }
        // Retain the existing diagnostic timestamp; the event is now handed
        // to the private native coordinator instead of a Flutter engine.
        AlarmStateStore(context).recordFlutterEventSent(alarmId, System.currentTimeMillis())
    }

    private fun handleBootCompleted(context: Context) {
        if (!AlarmWatchdogScheduler.isEnabled(context)) {
            Log.i(TAG, "Ignoring boot recovery because block production watchdog is disabled")
            return
        }
        val applicationIncarnation =
            ApplicationIncarnationStore(context).current() ?: run {
                Log.i(TAG, "Ignoring boot recovery without an application incarnation")
                return
            }

        Log.i(TAG, "Device boot completed - starting monitoring")
        AlarmWatchdogScheduler.ensurePeriodic(
            context,
            "boot_completed",
            applicationIncarnation,
        )
        AlarmWatchdogScheduler.enqueueOneTime(
            context,
            "boot_completed",
            applicationIncarnation,
        )
        startMonitoringService(
            context = context,
            alarmId = "boot_completed",
            globalSlot = 0,
            nodeRunning = false,
            applicationIncarnation = applicationIncarnation,
        )
        NativeProducerWakeCoordinator.submit(context, ProducerWakeSource.BOOT)
    }

    private fun handlePackageReplaced(context: Context) {
        if (!AlarmWatchdogScheduler.isEnabled(context)) {
            Log.i(TAG, "Ignoring package update recovery because block production watchdog is disabled")
            return
        }
        val applicationIncarnation =
            ApplicationIncarnationStore(context).current() ?: run {
                Log.i(TAG, "Ignoring package recovery without an application incarnation")
                return
            }

        Log.i(TAG, "App updated - starting monitoring")
        AlarmWatchdogScheduler.ensurePeriodic(
            context,
            "package_replaced",
            applicationIncarnation,
        )
        AlarmWatchdogScheduler.enqueueOneTime(
            context,
            "package_replaced",
            applicationIncarnation,
        )
        startMonitoringService(
            context = context,
            alarmId = "package_replaced",
            globalSlot = 0,
            nodeRunning = false,
            applicationIncarnation = applicationIncarnation,
        )
        NativeProducerWakeCoordinator.submit(context, ProducerWakeSource.PACKAGE_REPLACED)
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
        val applicationIncarnation = ApplicationIncarnationStore(context).current()
        if (granted &&
            applicationIncarnation != null &&
            AlarmWatchdogScheduler.isEnabled(context)
        ) {
            AlarmWatchdogScheduler.ensurePeriodic(
                context,
                "exact_alarm_permission_granted",
                applicationIncarnation,
            )
            AlarmWatchdogScheduler.enqueueOneTime(
                context,
                "exact_alarm_permission_granted",
                applicationIncarnation,
            )
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

    private fun sendAuditRecoveryEvent(
        context: Context,
        reason: String,
        applicationIncarnation: String,
    ) {
        sendFlutterEvent(
            context = context,
            eventType = "android_alarm_recovery_requested",
            eventData = mapOf(
                "reason" to reason,
                "source" to "alarm_receiver",
                ApplicationIncarnationStore.EXTRA_APPLICATION_INCARNATION to
                    applicationIncarnation,
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

        // Permission UI events are best effort and have no headless owner.
    }

    private fun startMonitoringService(
        context: Context,
        alarmId: String,
        globalSlot: Int,
        nodeRunning: Boolean,
        applicationIncarnation: String,
    ) {
        val serviceIntent = Intent(context, SlotMonitoringService::class.java).apply {
            action = SlotMonitoringService.ACTION_START_MONITORING
            putExtra("alarmId", alarmId)
            putExtra("globalSlot", globalSlot)
            putExtra("nodeRunning", nodeRunning)
            putExtra(
                ApplicationIncarnationStore.EXTRA_APPLICATION_INCARNATION,
                applicationIncarnation,
            )
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }

        Log.i(TAG, "SlotMonitoringService started (alarmId=$alarmId, globalSlot=$globalSlot)")
    }

    private fun readNativeScheduledWake(
        intent: Intent,
        globalSlot: Int,
    ): NativeScheduledWake? {
        val revision = intent.getLongExtra("nativeReadyRevision", -1L)
        val triggerAtMs = intent.getLongExtra("nativeWakeTriggerAtMs", -1L)
        val encodedIdentity = intent.getStringExtra("nativeWakeIdentity") ?: return null
        val identity = try {
            Base64.decode(
                encodedIdentity,
                Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
            )
        } catch (_: Exception) {
            return null
        }
        if (revision < 0 || triggerAtMs <= 0 || identity.size != 32 ||
            identity.all { it == 0.toByte() }
        ) {
            identity.fill(0)
            return null
        }
        return NativeScheduledWake(revision, identity, globalSlot, triggerAtMs)
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
