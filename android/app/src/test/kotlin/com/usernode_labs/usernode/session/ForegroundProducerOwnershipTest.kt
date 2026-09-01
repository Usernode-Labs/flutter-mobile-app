package com.usernode_labs.usernode.session

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ForegroundProducerOwnershipTest {
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
}
