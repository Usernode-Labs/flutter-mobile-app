package com.usernode_labs.usernode.session

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Process
import android.util.Base64
import android.util.Log
import com.usernode_labs.usernode.alarm.AlarmScheduler
import com.usernode_labs.usernode.alarm.AlarmWatchdogScheduler
import com.usernode_labs.usernode.alarm.ApplicationIncarnationStore
import com.usernode_labs.usernode.alarm.NativeWakeLockManager
import com.usernode_labs.usernode.alarm.SlotMonitoringService
import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.charset.StandardCharsets
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

internal fun armForegroundProducerOwnership(
    pollAfterMs: Long,
    ensureWatchdog: () -> Unit,
    isWakeLockHeld: () -> Boolean,
    acquireWakeLock: () -> Boolean,
    releaseWakeLock: () -> Unit,
    startMonitoring: (Long) -> Unit,
): Boolean {
    require(pollAfterMs >= 0)
    ensureWatchdog()
    val wakeLockWasHeld = isWakeLockHeld()
    if (!acquireWakeLock()) return false
    return try {
        startMonitoring(pollAfterMs)
        true
    } catch (_: Throwable) {
        if (!wakeLockWasHeld) releaseWakeLock()
        false
    }
}

/**
 * Single serialized native owner for Android producer wake callbacks.
 *
 * AlarmManager, WorkManager, foreground-service and notification behavior stay
 * in their existing platform classes. This coordinator only replaces the old
 * headless-Flutter hop with one bounded Rust request and compare-applies its
 * closed directive.
 */
internal object NativeProducerWakeCoordinator {
    private const val TAG = "usernode/ProducerWake"
    private const val FALLBACK_POLL_AFTER_MS = 30_000L
    private val executor: ExecutorService = Executors.newSingleThreadExecutor { task ->
        Thread(task, "usernode-producer-wake").apply { isDaemon = true }
    }
    private val runLock = Any()

    fun submit(
        context: Context,
        source: ProducerWakeSource,
        alarm: NativeScheduledWake? = null,
        expectedRevision: Long? = null,
        refreshPolicy: Boolean = true,
        monitoringIntent: Intent? = null,
        completion: ((ProducerWakeOutcome) -> Unit)? = null,
    ) {
        val applicationContext = context.applicationContext
        val applicationIncarnation = ApplicationIncarnationStore(applicationContext).ensure()
        executor.execute {
            val outcome = run(
                applicationContext,
                source,
                alarm,
                expectedRevision,
                refreshPolicy,
                monitoringIntent,
                applicationIncarnation,
            )
            completion?.invoke(outcome)
        }
    }

    /** WorkManager already invokes this off the main thread. */
    fun runBlocking(
        context: Context,
        source: ProducerWakeSource,
        alarm: NativeScheduledWake? = null,
        expectedRevision: Long? = null,
        refreshPolicy: Boolean = true,
        monitoringIntent: Intent? = null,
    ): ProducerWakeOutcome {
        val applicationContext = context.applicationContext
        return run(
            applicationContext,
            source,
            alarm,
            expectedRevision,
            refreshPolicy,
            monitoringIntent,
            ApplicationIncarnationStore(applicationContext).ensure(),
        )
    }

    fun clearReady(context: Context, expectedRevision: Long) {
        synchronized(runLock) {
            val appContext = context.applicationContext
            val store = NativeProducerWakeStore(appContext)
            val current = store.current()
            if (current != null) {
                check(current.readyRevision == expectedRevision) {
                    "native producer Ready revision mismatch"
                }
                val retired = store.compareClear(expectedRevision)
                    ?: throw IllegalStateException("native producer Ready clear failed")
                retired.wakeIdentity?.let { wakeId ->
                    alarmScheduler(appContext).cancelAlarm(alarmId(wakeId))
                }
            }
            // A reply-loss retry may find the selector already absent. The
            // remaining owners are idempotent and still belong to retired A.
            AlarmWatchdogScheduler.cancel(appContext)
            ApplicationIncarnationStore(appContext).rotate()
            SlotMonitoringService.stopNativeProducerMonitoring(appContext)
            NativeWakeLockManager.release()
        }
    }

    fun clearOrphanedState(context: Context) {
        synchronized(runLock) {
            val appContext = context.applicationContext
            val store = NativeProducerWakeStore(appContext)
            val retired = store.clearAll()
            retired?.wakeIdentity?.let { wakeId ->
                alarmScheduler(appContext).cancelAlarm(alarmId(wakeId))
            }
            AlarmWatchdogScheduler.cancel(appContext)
            ApplicationIncarnationStore(appContext).rotate()
            SlotMonitoringService.stopNativeProducerMonitoring(appContext)
            NativeWakeLockManager.release()
        }
    }

    fun isReady(context: Context, expectedRevision: Long): Boolean = synchronized(runLock) {
        NativeProducerWakeStore(context.applicationContext).current()?.readyRevision ==
            expectedRevision
    }

    private fun run(
        context: Context,
        source: ProducerWakeSource,
        alarm: NativeScheduledWake?,
        expectedRevision: Long?,
        refreshPolicy: Boolean,
        monitoringIntent: Intent?,
        applicationIncarnation: String?,
    ): ProducerWakeOutcome = synchronized(runLock) wake@{
        if (!ApplicationIncarnationStore(context).matches(applicationIncarnation)) {
            Log.i(TAG, "Ignoring producer wake for a stale application incarnation")
            return@wake ProducerWakeOutcome.Ignored
        }
        val store = NativeProducerWakeStore(context)
        val current = store.current()
        val revision = expectedRevision ?: current?.readyRevision
            ?: return@wake ProducerWakeOutcome.Ignored
        if (revision < 0) return@wake ProducerWakeOutcome.Ignored
        if (source == ProducerWakeSource.EXACT_ALARM &&
            (alarm == null || current == null || !current.matches(alarm, revision))
        ) {
            Log.i(TAG, "Ignoring stale exact-alarm callback")
            return@wake ProducerWakeOutcome.Ignored
        }

        val outcome = runCurrentWake(
            context,
            store,
            source,
            alarm,
            revision,
            refreshPolicy,
            monitoringIntent,
        )
        if (outcome == ProducerWakeOutcome.Retry) {
            try {
                ensureForegroundRetryOwnership(
                    context,
                    store,
                    revision,
                    FALLBACK_POLL_AFTER_MS,
                )
            } catch (error: Throwable) {
                Log.w(TAG, "Could not retain producer retry (${error.javaClass.simpleName})")
            }
        }
        outcome
    }

    private fun runCurrentWake(
        context: Context,
        store: NativeProducerWakeStore,
        source: ProducerWakeSource,
        alarm: NativeScheduledWake?,
        revision: Long,
        refreshPolicy: Boolean,
        monitoringIntent: Intent?,
    ): ProducerWakeOutcome {
        var coldInstallClaim: ByteArray? = null
        return try {
            installAuthority(context)
            if (source == ProducerWakeSource.EXACT_ALARM &&
                !beginExactAlarmOwnership(context, monitoringIntent)
            ) {
                return ProducerWakeOutcome.Retry
            }

            for (attempt in 0..1) {
                val credential = AndroidNativeSessionPlatform.vault(context)
                    .producerWakeCredential(refreshPolicy, coldInstallClaim)
                if (credential is ProducerWakeCredential.Uncertain) {
                    return ProducerWakeOutcome.Retry
                }
                val request = ProducerWakeFrame.encode(source, revision, alarm, credential)
                val response = try {
                    when (credential) {
                        is ProducerWakeCredential.Present -> {
                            val wakeClaim = NativeSessionRust.nativeStageProducerWakeV1(request)
                            try {
                                if (wakeClaim.size != 32 ||
                                    wakeClaim.all { it == 0.toByte() }
                                ) {
                                    throw IllegalStateException("invalid producer wake claim")
                                }
                                NativeSessionRust.nativeRunProducerWakeClaimV1(wakeClaim)
                            } finally {
                                wakeClaim.fill(0)
                            }
                        }
                        ProducerWakeCredential.Absent ->
                            NativeSessionRust.nativeResolveProducerCredentialAbsentV1(request)
                        ProducerWakeCredential.Uncertain ->
                            throw IllegalStateException("unreachable uncertain wake")
                    }
                } finally {
                    // Rust also wipes native mutable buffers. Wipe the JVM
                    // copies regardless of whether JNI accepted the call.
                    request.fill(0)
                    if (credential is ProducerWakeCredential.Present) credential.close()
                }
                try {
                    val directive = ProducerWakeFrame.decode(response)
                    if (directive.revision < 0) return ProducerWakeOutcome.Retry
                    if (directive !is ProducerWakeDirective.InstallCredential) {
                        return applyDirective(
                            context,
                            store,
                            directive,
                            response,
                            revision,
                        )
                    }
                    if (attempt != 0) return ProducerWakeOutcome.Retry
                    when (
                        val stage = AndroidNativeSessionPlatform.vault(context)
                            .stageBackgroundColdInstalledCredential()
                    ) {
                        is ColdCredentialStage.Present -> {
                            coldInstallClaim = stage.installClaim
                        }
                        ColdCredentialStage.Absent -> Unit
                        ColdCredentialStage.Uncertain ->
                            return ProducerWakeOutcome.Retry
                    }
                } finally {
                    response.fill(0)
                }
            }
            ProducerWakeOutcome.Retry
        } catch (error: Throwable) {
            // Do not log an exception that might retain native request material.
            Log.w(TAG, "Native producer wake failed (${error.javaClass.simpleName})")
            ProducerWakeOutcome.Retry
        } finally {
            coldInstallClaim?.fill(0)
        }
    }

    /**
     * Exact selector validation, wakelock acquisition, and the existing FGS
     * start are one serialized ownership step. Logout cannot retire A between
     * validation and acquisition; no stale callback can strand either owner.
     */
    private fun beginExactAlarmOwnership(
        context: Context,
        monitoringIntent: Intent?,
    ): Boolean {
        val intent = monitoringIntent ?: return false
        val incarnation = intent.getStringExtra(
            ApplicationIncarnationStore.EXTRA_APPLICATION_INCARNATION,
        ) ?: return false
        if (!ApplicationIncarnationStore(context).matches(incarnation) ||
            !NativeWakeLockManager.acquire(context, incarnation)
        ) {
            return false
        }
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            true
        } catch (error: Throwable) {
            NativeWakeLockManager.release()
            Log.w(TAG, "Could not start exact-alarm monitoring (${error.javaClass.simpleName})")
            false
        }
    }

    private fun applyDirective(
        context: Context,
        store: NativeProducerWakeStore,
        directive: ProducerWakeDirective,
        exactResponse: ByteArray,
        expectedRevision: Long,
    ): ProducerWakeOutcome {
        val previous = store.current()
        if (!directive.applyRequired) {
            return applyImmediateDirective(
                context,
                store,
                previous,
                directive,
                expectedRevision,
            )
        }
        if (directive.revision != expectedRevision ||
            (previous != null && previous.readyRevision != expectedRevision)
        ) {
            completeApply(exactResponse, success = false)
            return ProducerWakeOutcome.Retry
        }

        val applied = try {
            when (directive) {
                is ProducerWakeDirective.KeepForeground ->
                    applyKeepForeground(context, store, previous, directive)
                is ProducerWakeDirective.ScheduleExact ->
                    applyScheduleExact(context, store, previous, directive)
                is ProducerWakeDirective.RetryLater ->
                    applyRetryLater(context, store, directive)
                is ProducerWakeDirective.CancelAndStop ->
                    applyCancelAndStop(context, store, previous, directive)
                is ProducerWakeDirective.InstallCredential -> false
            }
        } catch (error: Throwable) {
            Log.w(TAG, "Could not apply producer directive (${error.javaClass.simpleName})")
            false
        }
        if (!applied) {
            rollbackAppliedDirective(context, store, previous, directive)
            completeApply(exactResponse, success = false)
            return ProducerWakeOutcome.Retry
        }

        val completed = completeApply(exactResponse, success = true)
        if (!completed) {
            rollbackAppliedDirective(context, store, previous, directive)
            return ProducerWakeOutcome.Retry
        }
        finishAppliedDirective(context, store, previous, directive)
        return when (directive) {
            is ProducerWakeDirective.RetryLater -> ProducerWakeOutcome.Retry
            else -> ProducerWakeOutcome.Completed
        }
    }

    private fun applyImmediateDirective(
        context: Context,
        store: NativeProducerWakeStore,
        previous: NativeProducerWakeState?,
        directive: ProducerWakeDirective,
        expectedRevision: Long,
    ): ProducerWakeOutcome {
        // Cold/logged-out/transition responses carry no live Ready admission.
        // Only definitive retirement may mutate shared platform ownership.
        when (directive) {
            is ProducerWakeDirective.CancelAndStop -> {
                if (previous != null && previous.readyRevision != expectedRevision) {
                    return ProducerWakeOutcome.Retry
                }
                val retired = previous?.let(store::compareClear)
                retired?.wakeIdentity?.let { alarmScheduler(context).cancelAlarm(alarmId(it)) }
                AlarmWatchdogScheduler.cancel(context)
                SlotMonitoringService.stopNativeProducerMonitoring(context)
                NativeWakeLockManager.release()
                if (directive.terminateProcess) {
                    Process.killProcess(Process.myPid())
                }
                return ProducerWakeOutcome.Completed
            }
            else -> return ProducerWakeOutcome.Retry
        }
    }

    private fun applyKeepForeground(
        context: Context,
        store: NativeProducerWakeStore,
        previous: NativeProducerWakeState?,
        directive: ProducerWakeDirective.KeepForeground,
    ): Boolean {
        val incarnation = ApplicationIncarnationStore(context).ensure() ?: return false
        if (!armForegroundOwnership(context, incarnation, directive.pollAfterMs.toLong())) {
            return false
        }
        if (!store.replace(previous, NativeProducerWakeState.ready(directive.revision))) {
            return false
        }
        previous?.wakeIdentity?.let { alarmScheduler(context).cancelAlarm(alarmId(it)) }
        return true
    }

    private fun applyScheduleExact(
        context: Context,
        store: NativeProducerWakeStore,
        previous: NativeProducerWakeState?,
        directive: ProducerWakeDirective.ScheduleExact,
    ): Boolean {
        val incarnation = ApplicationIncarnationStore(context).ensure() ?: return false
        val scheduled = scheduleExact(context, incarnation, directive)
        if (!scheduled) return false

        val applied = NativeProducerWakeState.from(directive)
        if (!store.replace(previous, applied)) {
            alarmScheduler(context).cancelAlarm(alarmId(directive.wakeIdentity))
            return false
        }
        AlarmWatchdogScheduler.ensurePeriodic(
            context,
            "native_producer_schedule",
            incarnation,
        )
        return true
    }

    private fun finishAppliedDirective(
        context: Context,
        store: NativeProducerWakeStore,
        previous: NativeProducerWakeState?,
        directive: ProducerWakeDirective,
    ) {
        when (directive) {
            is ProducerWakeDirective.ScheduleExact -> {
                if (previous?.wakeIdentity != null &&
                    !previous.wakeIdentity.contentEquals(directive.wakeIdentity)
                ) {
                    alarmScheduler(context).cancelAlarm(alarmId(previous.wakeIdentity))
                }
                // Completion releases A's Rust permit. A successor may become
                // Ready immediately, so stale A may stop only its own runtime.
                val appliedStillCurrent = store.current()
                    ?.sameAs(NativeProducerWakeState.from(directive)) == true
                if (directive.pauseRuntime && appliedStillCurrent) {
                    SlotMonitoringService.stopNativeProducerMonitoring(context)
                    NativeWakeLockManager.release()
                }
            }
            is ProducerWakeDirective.CancelAndStop -> {
                val appliedStillCurrent = store.current()
                    ?.sameAs(NativeProducerWakeState.ready(directive.revision)) == true
                if (appliedStillCurrent) {
                    AlarmWatchdogScheduler.cancel(context)
                    SlotMonitoringService.stopNativeProducerMonitoring(context)
                    NativeWakeLockManager.release()
                }
            }
            else -> Unit
        }
    }

    private fun applyRetryLater(
        context: Context,
        store: NativeProducerWakeStore,
        directive: ProducerWakeDirective.RetryLater,
    ): Boolean = ensureForegroundRetryOwnership(
        context,
        store,
        directive.revision,
        directive.retryAfterMs.toLong(),
    )

    private fun ensureForegroundRetryOwnership(
        context: Context,
        store: NativeProducerWakeStore,
        expectedRevision: Long,
        pollAfterMs: Long,
    ): Boolean {
        val incarnation = ApplicationIncarnationStore(context).current() ?: return false
        val current = store.current()
        if (current != null && current.readyRevision != expectedRevision) return false
        if (current == null &&
            !store.replace(null, NativeProducerWakeState.ready(expectedRevision))
        ) {
            return false
        }
        return armForegroundOwnership(context, incarnation, pollAfterMs)
    }

    private fun armForegroundOwnership(
        context: Context,
        incarnation: String,
        pollAfterMs: Long,
    ): Boolean {
        val armed = armForegroundProducerOwnership(
            pollAfterMs = pollAfterMs,
            ensureWatchdog = {
                try {
                    if (!AlarmWatchdogScheduler.isEnabled(context)) {
                        AlarmWatchdogScheduler.ensurePeriodic(
                            context,
                            "native_producer_foreground",
                            incarnation,
                        )
                    }
                } catch (error: Throwable) {
                    Log.w(TAG, "Could not retain producer watchdog (${error.javaClass.simpleName})")
                }
            },
            isWakeLockHeld = NativeWakeLockManager::isHeld,
            acquireWakeLock = { NativeWakeLockManager.acquire(context, incarnation) },
            releaseWakeLock = NativeWakeLockManager::release,
            startMonitoring = { delay ->
                SlotMonitoringService.startNativeProducerMonitoring(
                    context,
                    incarnation,
                    delay,
                )
            },
        )
        if (!armed) Log.w(TAG, "Could not retain foreground producer ownership")
        return armed
    }

    private fun applyCancelAndStop(
        context: Context,
        store: NativeProducerWakeStore,
        previous: NativeProducerWakeState?,
        directive: ProducerWakeDirective.CancelAndStop,
    ): Boolean {
        if (directive.terminateProcess) return false
        val applied = NativeProducerWakeState.ready(directive.revision)
        if (!store.replace(previous, applied)) return false
        previous?.wakeIdentity?.let { alarmScheduler(context).cancelAlarm(alarmId(it)) }
        return true
    }

    private fun rollbackAppliedDirective(
        context: Context,
        store: NativeProducerWakeStore,
        previous: NativeProducerWakeState?,
        directive: ProducerWakeDirective,
    ) {
        when (directive) {
            is ProducerWakeDirective.ScheduleExact -> {
                alarmScheduler(context).cancelAlarm(alarmId(directive.wakeIdentity))
                val applied = NativeProducerWakeState.from(directive)
                store.replace(applied, previous)
            }
            is ProducerWakeDirective.KeepForeground -> {
                val applied = NativeProducerWakeState.ready(directive.revision)
                if (store.replace(applied, previous)) {
                    previous?.wakeIdentity?.let { restoreExact(context, previous) }
                }
            }
            is ProducerWakeDirective.CancelAndStop -> {
                val applied = NativeProducerWakeState.ready(directive.revision)
                if (store.replace(applied, previous)) {
                    previous?.wakeIdentity?.let { restoreExact(context, previous) }
                }
            }
            is ProducerWakeDirective.RetryLater,
            is ProducerWakeDirective.InstallCredential -> Unit
        }
    }

    private fun completeApply(exactResponse: ByteArray, success: Boolean): Boolean = try {
        NativeSessionRust.nativeCompleteProducerWakeApplyV1(exactResponse, success)
    } catch (error: Throwable) {
        Log.w(TAG, "Could not complete producer directive (${error.javaClass.simpleName})")
        false
    }

    private fun scheduleExact(
        context: Context,
        incarnation: String,
        directive: ProducerWakeDirective.ScheduleExact,
    ): Boolean {
        val delay = (directive.triggerAtMs - System.currentTimeMillis()).coerceAtLeast(0)
        return alarmScheduler(context).scheduleExactAlarm(
            alarmId(directive.wakeIdentity),
            delay,
            directive.targetGlobalSlot,
            mapOf(
                ApplicationIncarnationStore.EXTRA_APPLICATION_INCARNATION to incarnation,
                "nativeReadyRevision" to directive.revision,
                "nativeWakeIdentity" to encodeIdentity(directive.wakeIdentity),
                "nativeWakeTriggerAtMs" to directive.triggerAtMs,
                "nativeRustWakeTimeMs" to directive.rustWakeTimeMs,
                "nativeTargetRustTimeMs" to directive.targetRustTimeMs,
                "nodeRunning" to !directive.pauseRuntime,
                "reason" to directive.reason.wireName,
                "purpose" to "block_production",
            ),
        )
    }

    private fun restoreExact(context: Context, previous: NativeProducerWakeState) {
        val identity = previous.wakeIdentity ?: return
        val incarnation = ApplicationIncarnationStore(context).current() ?: return
        alarmScheduler(context).scheduleExactAlarm(
            alarmId(identity),
            (previous.triggerAtMs - System.currentTimeMillis()).coerceAtLeast(0),
            previous.globalSlot,
            mapOf(
                ApplicationIncarnationStore.EXTRA_APPLICATION_INCARNATION to incarnation,
                "nativeReadyRevision" to previous.readyRevision,
                "nativeWakeIdentity" to encodeIdentity(identity),
                "nativeWakeTriggerAtMs" to previous.triggerAtMs,
                "nodeRunning" to false,
                "reason" to "completion_rejected",
                "purpose" to "block_production",
            ),
        )
    }

    private fun installAuthority(context: Context) {
        val directory = File(context.noBackupFilesDir, "native_session_v2")
        if ((!directory.exists() && !directory.mkdirs()) || !directory.isDirectory) {
            throw IllegalStateException("native process storage unavailable")
        }
        NativeSessionRust.nativeInstallProcessAuthority(directory.absolutePath)
    }

    private fun alarmScheduler(context: Context): AlarmScheduler = AlarmScheduler(
        context,
        context.getSystemService(Context.ALARM_SERVICE) as AlarmManager,
    )

    private fun alarmId(identity: ByteArray): String = "native_${encodeIdentity(identity)}"

    private fun encodeIdentity(identity: ByteArray): String = Base64.encodeToString(
        identity,
        Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
    )
}

internal enum class ProducerWakeSource(val code: Int) {
    EXACT_ALARM(1),
    BOOT(2),
    PACKAGE_REPLACED(3),
    WATCHDOG(4),
    FOREGROUND_RESUME(5),
    IOS_BACKGROUND(6),
}

internal enum class ProducerWakeOutcome { Completed, Retry, Ignored }

internal data class NativeScheduledWake(
    val readyRevision: Long,
    val wakeIdentity: ByteArray,
    val globalSlot: Int,
    val triggerAtMs: Long,
)

private sealed class ProducerWakeDirective(
    open val revision: Long,
    open val reason: ProducerWakeReason,
) {
    var applyRequired: Boolean = false

    data class KeepForeground(
        override val revision: Long,
        val pollAfterMs: Int,
        override val reason: ProducerWakeReason,
    ) : ProducerWakeDirective(revision, reason)

    data class ScheduleExact(
        override val revision: Long,
        val wakeIdentity: ByteArray,
        val triggerAtMs: Long,
        val rustWakeTimeMs: Long,
        val targetGlobalSlot: Int,
        val targetRustTimeMs: Long,
        val pauseRuntime: Boolean,
        override val reason: ProducerWakeReason,
    ) : ProducerWakeDirective(revision, reason)

    data class CancelAndStop(
        override val revision: Long,
        val terminateProcess: Boolean,
        override val reason: ProducerWakeReason,
    ) : ProducerWakeDirective(revision, reason)

    data class RetryLater(
        override val revision: Long,
        val retryAfterMs: Int,
        override val reason: ProducerWakeReason,
    ) : ProducerWakeDirective(revision, reason)

    data class InstallCredential(
        override val revision: Long,
    ) : ProducerWakeDirective(revision, ProducerWakeReason.RUNTIME_UNAVAILABLE)
}

private enum class ProducerWakeReason(val code: Int, val wireName: String) {
    VRF_PENDING(1, "vrf_pending"),
    IMMINENT_TARGET(2, "imminent_target"),
    NEXT_WON_SLOT(3, "next_won_slot"),
    EPOCH_END(4, "epoch_end"),
    CREDENTIAL_UNCERTAIN(5, "credential_uncertain"),
    LOGGED_OUT(6, "logged_out"),
    TRANSITION_IN_PROGRESS(7, "transition_in_progress"),
    POLICY_UNAVAILABLE(8, "policy_unavailable"),
    POST_PRODUCTION_HOLD(9, "post_production_hold"),
    RUNTIME_UNAVAILABLE(10, "runtime_unavailable");

    companion object {
        fun fromCode(code: Int): ProducerWakeReason = values().firstOrNull { it.code == code }
            ?: throw IllegalArgumentException("invalid producer wake reason")
    }
}

private object ProducerWakeFrame {
    fun encode(
        source: ProducerWakeSource,
        expectedRevision: Long,
        alarm: NativeScheduledWake?,
        credential: ProducerWakeCredential,
    ): ByteArray {
        val evidence = when (credential) {
            is ProducerWakeCredential.Present -> 1
            ProducerWakeCredential.Absent -> 2
            ProducerWakeCredential.Uncertain -> 3
        }
        val bytes = ByteArrayOutputStream()
        DataOutputStream(bytes).use { output ->
            output.write("UNPW".toByteArray(StandardCharsets.US_ASCII))
            output.writeByte(1)
            output.writeByte(source.code)
            output.writeByte(evidence)
            output.writeLong(expectedRevision)
            output.write(alarm?.wakeIdentity ?: ByteArray(32))
            output.writeInt(alarm?.globalSlot ?: 0)
            output.writeLong(alarm?.triggerAtMs ?: 0)
            if (credential is ProducerWakeCredential.Present) {
                output.writeShort(credential.vaultEvidenceFrame.size)
                output.write(credential.vaultEvidenceFrame)
                output.writeShort(credential.producerPolicyFrame.size)
                output.write(credential.producerPolicyFrame)
            } else {
                output.writeShort(0)
                output.writeShort(0)
            }
        }
        return bytes.toByteArray().also {
            if (it.size > 2048) {
                it.fill(0)
                throw IllegalArgumentException("producer wake request too large")
            }
        }
    }

    fun decode(frame: ByteArray): ProducerWakeDirective {
        if (frame.size < 15 || frame.size > 109 ||
            !frame.copyOfRange(0, 4).contentEquals("UNPR".toByteArray(StandardCharsets.US_ASCII)) ||
            frame[4].toInt() != 1
        ) {
            throw IllegalArgumentException("invalid producer wake response")
        }
        val input = ByteBuffer.wrap(frame).order(ByteOrder.BIG_ENDIAN)
        input.position(5)
        val tag = input.get().toInt() and 0xff
        val revision = input.long.takeIf { it >= 0 }
            ?: throw IllegalArgumentException("invalid producer wake revision")
        val directive = when (tag) {
            1 -> {
                ProducerWakeDirective.KeepForeground(
                    revision,
                    input.int.nonNegative(),
                    ProducerWakeReason.fromCode(input.get().toInt() and 0xff),
                )
            }
            2 -> {
                val identity = ByteArray(32).also(input::get)
                if (identity.all { it == 0.toByte() }) {
                    throw IllegalArgumentException("invalid zero wake identity")
                }
                ProducerWakeDirective.ScheduleExact(
                    revision,
                    identity,
                    input.long.nonNegative(),
                    input.long.nonNegative(),
                    input.int.nonNegative(),
                    input.long.nonNegative(),
                    input.boolean(),
                    ProducerWakeReason.fromCode(input.get().toInt() and 0xff),
                )
            }
            3 -> {
                ProducerWakeDirective.CancelAndStop(
                    revision,
                    input.boolean(),
                    ProducerWakeReason.fromCode(input.get().toInt() and 0xff),
                )
            }
            4 -> {
                ProducerWakeDirective.RetryLater(
                    revision,
                    input.int.nonNegative(),
                    ProducerWakeReason.fromCode(input.get().toInt() and 0xff),
                )
            }
            5 -> {
                ProducerWakeDirective.InstallCredential(revision)
            }
            else -> throw IllegalArgumentException("invalid producer wake directive")
        }
        directive.applyRequired = input.boolean()
        if (directive.applyRequired) {
            if (directive is ProducerWakeDirective.InstallCredential || input.remaining() != 32) {
                throw IllegalArgumentException("invalid producer apply claim")
            }
            val claim = ByteArray(32)
            try {
                input.get(claim)
                if (claim.all { it == 0.toByte() }) {
                    throw IllegalArgumentException("invalid producer apply claim")
                }
            } finally {
                claim.fill(0)
            }
        }
        if (input.hasRemaining()) throw IllegalArgumentException("trailing producer wake response")
        return directive
    }

    private fun ByteBuffer.boolean(): Boolean = when (get().toInt()) {
        0 -> false
        1 -> true
        else -> throw IllegalArgumentException("invalid producer wake boolean")
    }

    private fun Int.nonNegative(): Int = takeIf { it >= 0 }
        ?: throw IllegalArgumentException("invalid producer wake integer")

    private fun Long.nonNegative(): Long = takeIf { it >= 0 }
        ?: throw IllegalArgumentException("invalid producer wake integer")
}

private data class NativeProducerWakeState(
    val readyRevision: Long,
    val wakeIdentity: ByteArray?,
    val globalSlot: Int,
    val triggerAtMs: Long,
) {
    fun matches(alarm: NativeScheduledWake, revision: Long): Boolean =
        readyRevision == revision &&
            wakeIdentity != null &&
            wakeIdentity.contentEquals(alarm.wakeIdentity) &&
            globalSlot == alarm.globalSlot &&
            triggerAtMs == alarm.triggerAtMs

    fun sameAs(other: NativeProducerWakeState?): Boolean =
        other != null &&
            readyRevision == other.readyRevision &&
            when {
                wakeIdentity == null -> other.wakeIdentity == null
                other.wakeIdentity == null -> false
                else -> wakeIdentity.contentEquals(other.wakeIdentity)
            } &&
            globalSlot == other.globalSlot &&
            triggerAtMs == other.triggerAtMs

    companion object {
        fun ready(revision: Long) = NativeProducerWakeState(revision, null, 0, 0)

        fun from(directive: ProducerWakeDirective.ScheduleExact) = NativeProducerWakeState(
            directive.revision,
            directive.wakeIdentity.copyOf(),
            directive.targetGlobalSlot,
            directive.triggerAtMs,
        )
    }
}

private class NativeProducerWakeStore(context: Context) {
    private val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    fun current(): NativeProducerWakeState? {
        if (!preferences.contains(REVISION)) return null
        val revision = preferences.getLong(REVISION, -1)
        val encodedIdentity = preferences.getString(WAKE_IDENTITY, null)
        val identity = encodedIdentity?.let {
            try {
                Base64.decode(it, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
                    .takeIf { decoded -> decoded.size == 32 }
            } catch (_: Exception) {
                null
            }
        }
        return NativeProducerWakeState(
            revision,
            identity,
            preferences.getInt(GLOBAL_SLOT, 0),
            preferences.getLong(TRIGGER_AT_MS, 0),
        ).takeIf { it.readyRevision >= 0 }
    }

    fun replace(
        expected: NativeProducerWakeState?,
        next: NativeProducerWakeState?,
    ): Boolean {
        val current = current()
        val matches = if (expected == null) current == null else expected.sameAs(current)
        if (!matches) return false
        if (next == null) return preferences.edit().clear().commit()
        val editor = preferences.edit()
            .putLong(REVISION, next.readyRevision)
            .putInt(GLOBAL_SLOT, next.globalSlot)
            .putLong(TRIGGER_AT_MS, next.triggerAtMs)
        val identity = next.wakeIdentity
        if (identity == null) {
            editor.remove(WAKE_IDENTITY)
        } else {
            editor.putString(
                WAKE_IDENTITY,
                Base64.encodeToString(
                    identity,
                    Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
                ),
            )
        }
        return editor.commit()
    }

    fun compareClear(expectedRevision: Long): NativeProducerWakeState? {
        val current = current() ?: return null
        if (current.readyRevision != expectedRevision) return null
        return current.takeIf { preferences.edit().clear().commit() }
    }

    fun compareClear(expected: NativeProducerWakeState): NativeProducerWakeState? {
        val current = current() ?: return null
        if (!expected.sameAs(current)) return null
        return current.takeIf { preferences.edit().clear().commit() }
    }

    fun clearAll(): NativeProducerWakeState? {
        val current = current()
        check(preferences.edit().clear().commit()) {
            "orphaned native producer clear failed"
        }
        return current
    }

    private companion object {
        const val PREFERENCES = "native_producer_wake_v1"
        const val REVISION = "ready_revision"
        const val WAKE_IDENTITY = "wake_identity"
        const val GLOBAL_SLOT = "global_slot"
        const val TRIGGER_AT_MS = "trigger_at_ms"
    }
}
