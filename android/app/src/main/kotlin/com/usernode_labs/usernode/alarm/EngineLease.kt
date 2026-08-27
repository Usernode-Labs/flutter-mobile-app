package com.usernode_labs.usernode.alarm

/** The only Flutter-engine role that may own the alarm channel. */
internal enum class EngineRole {
    INTERACTIVE,
}

/**
 * Opaque reference authorizing one exact Flutter engine binding.
 *
 * Values have no caller-selected identifier and are compared by reference.
 * A lease only becomes authoritative when [EngineLeaseRegistry.replace]
 * installs that exact instance as the current interactive engine.
 */
internal class EngineLease private constructor(
    internal val role: EngineRole,
) {
    internal companion object {
        fun candidate(role: EngineRole): EngineLease = EngineLease(role)
    }
}

internal class EngineLeaseCapture<T : Any> internal constructor(
    internal val lease: EngineLease,
    internal val value: T,
)

/**
 * Owns one exact engine-bound value and only releases the matching lease.
 *
 * Interactive replacement invalidates the predecessor synchronously. A stale
 * dispatch or compare-release can never act on its successor.
 */
internal class EngineLeaseRegistry<T : Any> {
    private var active: EngineLeaseCapture<T>? = null

    /** Installs an interactive successor and invalidates the predecessor. */
    @Synchronized
    fun replace(role: EngineRole, value: T): EngineLease {
        val lease = EngineLease.candidate(role)
        active = EngineLeaseCapture(lease, value)
        return lease
    }

    @Synchronized
    fun capture(): EngineLeaseCapture<T>? = active

    @Synchronized
    fun isCurrent(expected: EngineLease): Boolean = active?.lease === expected

    /**
     * Runs one synchronous dispatch step only while [expected] is current.
     *
     * The registry lock ends when [body] returns. It never covers an
     * asynchronous platform reply.
     */
    @Synchronized
    fun runIfCurrent(expected: EngineLease, body: (T) -> Unit): Boolean {
        val current = active ?: return false
        if (current.lease !== expected) return false
        body(current.value)
        return true
    }

    @Synchronized
    fun compareRelease(expected: EngineLease): T? {
        val current = active ?: return null
        if (current.lease !== expected) return null
        active = null
        return current.value
    }
}
