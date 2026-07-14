package com.usernode_labs.usernode.alarm

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class FlutterAlarmEventBufferTest {
    @Test
    fun `events sent before Flutter is ready are flushed in order once ready`() {
        val buffer = FlutterAlarmEventBuffer()

        assertNull(buffer.enqueueOrDispatch("android_native_wakelock_acquired", mapOf("wakelockHeld" to true)))
        assertNull(buffer.enqueueOrDispatch("android_alarm_fired", mapOf("alarmId" to "fg_resume")))
        assertEquals(2, buffer.pendingCount())

        val drained = buffer.markFlutterReady()

        assertEquals(2, drained.size)
        assertEquals("android_native_wakelock_acquired", drained[0].eventType)
        assertEquals("android_alarm_fired", drained[1].eventType)
        assertTrue(buffer.drainIfReady().isEmpty())
    }

    @Test
    fun `events are queued again after Flutter becomes not ready`() {
        val buffer = FlutterAlarmEventBuffer()

        buffer.markFlutterReady()
        val immediate = buffer.enqueueOrDispatch("android_alarm_fired", mapOf("alarmId" to "fg_resume"))
        assertEquals("android_alarm_fired", immediate?.eventType)

        buffer.markFlutterNotReady()
        assertNull(buffer.enqueueOrDispatch("android_alarm_fired", mapOf("alarmId" to "fg_resume_2")))
        assertEquals(1, buffer.pendingCount())

        val drained = buffer.markFlutterReady()
        assertEquals(1, drained.size)
        assertEquals("fg_resume_2", drained.single().eventData["alarmId"])
    }

    @Test
    fun `queued event preserves acknowledgement callback until dispatch`() {
        val buffer = FlutterAlarmEventBuffer()
        var acknowledged: Boolean? = null

        assertNull(
            buffer.enqueueOrDispatch(
                "android_workmanager_watchdog",
                emptyMap(),
            ) { acknowledged = it },
        )

        val event = buffer.markFlutterReady().single()
        event.completion?.invoke(true)

        assertEquals(true, acknowledged)
    }

    @Test
    fun `dropping a queued event rejects its acknowledgement`() {
        val buffer = FlutterAlarmEventBuffer(maxPendingEvents = 1)
        var acknowledged: Boolean? = null

        buffer.enqueueOrDispatch(
            "android_workmanager_watchdog",
            emptyMap(),
        ) { acknowledged = it }
        buffer.enqueueOrDispatch("android_alarm_fired", emptyMap())

        assertEquals(false, acknowledged)
    }
}
