package com.usernode_labs.usernode.alarm

import java.util.concurrent.locks.ReentrantLock

internal enum class NativeSchedulingCheckpoint {
    BEFORE_ACQUIRE,
    AFTER_ACQUIRE,
    BEFORE_RELEASE,
    AFTER_RELEASE,
}

/**
 * One process-global serialization boundary for native runtime scheduling.
 *
 * The lock is deliberately reentrant: an admitted alarm/watchdog/service
 * operation rechecks [ApplicationIncarnationStore] while it is held, and that
 * store is protected by this same authority. The checkpoint callback is a
 * deterministic test seam; production uses the no-op process instance.
 */
internal class NativeSchedulingAuthority(
    private val checkpoint: (String, NativeSchedulingCheckpoint) -> Unit = { _, _ -> },
) {
    private val lock = ReentrantLock()

    fun <T> serialized(operation: String, effect: () -> T): T {
        checkpoint(operation, NativeSchedulingCheckpoint.BEFORE_ACQUIRE)
        lock.lock()
        try {
            checkpoint(operation, NativeSchedulingCheckpoint.AFTER_ACQUIRE)
            return effect()
        } finally {
            try {
                checkpoint(operation, NativeSchedulingCheckpoint.BEFORE_RELEASE)
            } finally {
                lock.unlock()
                checkpoint(operation, NativeSchedulingCheckpoint.AFTER_RELEASE)
            }
        }
    }

    fun runIfCurrent(
        operation: String,
        captured: String?,
        current: () -> String?,
        onRejected: () -> Unit = {},
        effect: () -> Boolean,
    ): Boolean = serialized(operation) {
        val authoritative = current()
        if (captured.isNullOrBlank() || authoritative == null || captured != authoritative) {
            onRejected()
            false
        } else {
            effect()
        }
    }

    companion object {
        val process = NativeSchedulingAuthority()
    }
}
