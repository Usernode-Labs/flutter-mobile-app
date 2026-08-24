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
 * The checkpoint callback is a deterministic test seam; production uses the
 * no-op process instance.
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

    fun runIfAdmitted(
        operation: String,
        owner: RuntimeOwner,
        admitted: (RuntimeOwner) -> Boolean,
        effect: () -> Boolean,
    ): Boolean = serialized(operation) {
        if (admitted(owner)) effect() else false
    }

    fun runIfOwned(
        operation: String,
        owner: RuntimeOwner,
        resourceOwner: () -> RuntimeOwner?,
        effect: () -> Boolean,
    ): Boolean = serialized(operation) {
        if (resourceOwner() == owner) effect() else false
    }

    companion object {
        val process = NativeSchedulingAuthority()
    }
}
