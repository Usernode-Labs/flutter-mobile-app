package com.onhomeroom.app.webview

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PermissionPromptQueueTest {
    @Test
    fun `camera waits for microphone and duplicate requests share a prompt`() {
        val queue = PermissionPromptQueue<String>()
        queue.enqueue("microphone")
        assertEquals("microphone", queue.next())
        queue.enqueue("camera")
        queue.enqueue("camera")
        queue.enqueue("microphone")
        assertNull(queue.next())
        queue.complete("microphone")
        assertEquals("camera", queue.next())
        assertNull(queue.next())
        queue.complete("camera")
        assertNull(queue.next())
    }

    @Test
    fun `unrelated result does not release an active prompt`() {
        val queue = PermissionPromptQueue<String>()
        queue.enqueue("camera")
        queue.next()
        queue.complete("microphone")
        assertEquals("camera", queue.active)
        assertNull(queue.next())
    }

    @Test
    fun `a completed or cancelled gate can be requested again`() {
        val queue = PermissionPromptQueue<String>()
        queue.enqueue("camera")
        queue.next()
        queue.complete("camera")
        queue.enqueue("camera")
        assertEquals("camera", queue.next())
    }
}
