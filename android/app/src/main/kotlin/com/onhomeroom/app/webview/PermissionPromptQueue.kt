package com.onhomeroom.app.webview

/** Serializes Activity permission dialogs, coalescing requests for the same gate. */
internal class PermissionPromptQueue<T> {
    private val waiting = ArrayDeque<T>()
    var active: T? = null
        private set

    fun enqueue(value: T) {
        if (value != active && value !in waiting) waiting.addLast(value)
    }

    fun next(): T? {
        if (active != null || waiting.isEmpty()) return null
        return waiting.removeFirst().also { active = it }
    }

    fun complete(value: T) {
        if (active == value) active = null
    }
}
