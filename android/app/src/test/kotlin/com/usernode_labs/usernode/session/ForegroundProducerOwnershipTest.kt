package com.usernode_labs.usernode.session

import com.usernode_labs.usernode.alarm.producerNotificationContent
import com.usernode_labs.usernode.alarm.producerPeriodicPollDelayMs
import com.usernode_labs.usernode.alarm.producerStatePollAtMs
import com.usernode_labs.usernode.alarm.producerStatePollDelayMs
import com.usernode_labs.usernode.alarm.scheduledWakeNotificationContent
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ForegroundProducerOwnershipTest {
    @Test
    fun `only exact node epoch unavailable response enables current epoch fallback`() {
        assertTrue(allowsCurrentEpochProduction(503, "node_epoch_unavailable"))
        assertFalse(allowsCurrentEpochProduction(502, "node_epoch_unavailable"))
        assertFalse(allowsCurrentEpochProduction(503, "policy_unavailable"))
        assertArrayEquals(
            byteArrayOf('U'.code.toByte(), 'N'.code.toByte(), 'E'.code.toByte(), 'A'.code.toByte(), 1),
            NativeProducerPolicyFrame.nodeEpochUnavailable(),
        )
    }

    @Test
    fun `arming foreground ownership enables every liveness owner`() {
        val calls = mutableListOf<String>()

        val armed = armForegroundProducerOwnership(
            pollAfterMs = 30_000,
            ensureWatchdog = { calls += "watchdog" },
            isWakeLockHeld = {
                calls += "held"
                false
            },
            acquireWakeLock = {
                calls += "acquire"
                true
            },
            releaseWakeLock = { calls += "release" },
            startMonitoring = { calls += "poll:$it" },
        )

        assertTrue(armed)
        assertEquals(
            listOf("watchdog", "held", "acquire", "poll:30000"),
            calls,
        )
    }

    @Test
    fun `failed service start releases only a newly acquired wake lock`() {
        var releases = 0

        fun arm(wakeLockWasHeld: Boolean): Boolean = armForegroundProducerOwnership(
            pollAfterMs = 30_000,
            ensureWatchdog = {},
            isWakeLockHeld = { wakeLockWasHeld },
            acquireWakeLock = { true },
            releaseWakeLock = { releases += 1 },
            startMonitoring = { error("service start failed") },
        )

        assertFalse(arm(wakeLockWasHeld = false))
        assertEquals(1, releases)
        assertFalse(arm(wakeLockWasHeld = true))
        assertEquals(1, releases)
    }

    @Test
    fun `sleep transaction stops ownership only after platform and Rust commit`() {
        val calls = mutableListOf<String>()

        val completed = completeProducerDirectiveTransaction(
            platformApplied = true,
            completeRust = {
                calls += "rust:$it"
                true
            },
            rollbackPlatform = { calls += "rollback" },
            finishCommitted = { calls += "stop-foreground" },
        )

        assertTrue(completed)
        assertEquals(listOf("rust:true", "stop-foreground"), calls)
    }

    @Test
    fun `Rust rejection rolls back alarm without stopping foreground ownership`() {
        val calls = mutableListOf<String>()

        val completed = completeProducerDirectiveTransaction(
            platformApplied = true,
            completeRust = {
                calls += "rust:$it"
                false
            },
            rollbackPlatform = { calls += "rollback" },
            finishCommitted = { calls += "stop-foreground" },
        )

        assertFalse(completed)
        assertEquals(listOf("rust:true", "rollback"), calls)
    }

    @Test
    fun `alarm install failure reports failure and retains foreground ownership`() {
        val calls = mutableListOf<String>()

        val completed = completeProducerDirectiveTransaction(
            platformApplied = false,
            completeRust = {
                calls += "rust:$it"
                true
            },
            rollbackPlatform = { calls += "rollback" },
            finishCommitted = { calls += "stop-foreground" },
        )

        assertFalse(completed)
        assertEquals(listOf("rollback", "rust:false"), calls)
    }

    @Test
    fun `policy unavailable refreshes only a local-policy wake`() {
        assertTrue(
            shouldRefreshProducerPolicy(
                refreshPolicy = false,
                reason = ProducerWakeReason.POLICY_UNAVAILABLE,
            ),
        )
        assertFalse(
            shouldRefreshProducerPolicy(
                refreshPolicy = true,
                reason = ProducerWakeReason.POLICY_UNAVAILABLE,
            ),
        )
        assertFalse(
            shouldRefreshProducerPolicy(
                refreshPolicy = false,
                reason = ProducerWakeReason.TRANSITION_IN_PROGRESS,
            ),
        )
    }

    @Test
    fun `producer notification describes the actual awake state`() {
        val waiting = producerNotificationContent(
            ProducerWakeReason.AWAITING_HIGHER_BLOCK,
            ProducerForegroundDetail.ProducedHeight(49_294),
        )
        assertEquals("Waiting for successor block", waiting.title)
        assertTrue(waiting.message.contains("Produced block 49294"))
        assertTrue(waiting.message.contains("up to 30 seconds"))

        val producing = producerNotificationContent(
            ProducerWakeReason.PRODUCTION_IN_PROGRESS,
            ProducerForegroundDetail.None,
        )
        assertEquals("Producing a block", producing.title)
        assertEquals("Block production is in progress", producing.message)

        val evaluating = producerNotificationContent(
            ProducerWakeReason.VRF_PENDING,
            ProducerForegroundDetail.None,
        )
        assertEquals("Evaluating production slots", evaluating.title)
    }

    @Test
    fun `production soon notification includes its real slot`() {
        val content = producerNotificationContent(
            ProducerWakeReason.PRODUCTION_SOON,
            ProducerForegroundDetail.Target(
                globalSlot = 380_400,
                targetTimeMs = 1_789_060_000_000,
            ),
        )

        assertEquals("Block production scheduled", content.title)
        assertTrue(content.message.contains("slot 380400"))
        assertTrue(content.message.contains("keeping the node awake"))
        assertEquals(
            1_789_060_000_000,
            producerStatePollAtMs(
                ProducerWakeReason.PRODUCTION_SOON,
                ProducerForegroundDetail.Target(380_400, 1_789_060_000_000),
            ),
        )
        assertEquals(
            null,
            producerStatePollAtMs(
                ProducerWakeReason.VRF_READINESS,
                ProducerForegroundDetail.Target(380_400, 1_789_060_000_000),
            ),
        )
        assertEquals(1_250L, producerStatePollDelayMs(2_000, 1_000))
        assertEquals(250L, producerStatePollDelayMs(2_000, 2_000))
        assertEquals(250L, producerStatePollDelayMs(2_000, 11_999))
        assertEquals(null, producerStatePollDelayMs(2_000, 12_001))
        assertEquals(30_000L, producerPeriodicPollDelayMs(30_000, 50_000, 1_000))
        assertEquals(34_000L, producerPeriodicPollDelayMs(30_000, 30_000, 1_000))
        assertEquals(30_000L, producerPeriodicPollDelayMs(30_000, 1_000, 1_001))
    }

    @Test
    fun `sleep notification identifies the scheduled wake slot and time`() {
        val content = scheduledWakeNotificationContent(
            globalSlot = 380_401,
            alarmTimeMs = 1_789_060_000_000,
        )

        assertEquals("Block production wake scheduled", content.title)
        assertTrue(content.message.startsWith("Slot 380401 wakeup at "))
    }
}
