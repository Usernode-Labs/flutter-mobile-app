package com.usernode_labs.usernode.alarm

/** The only two Flutter-engine roles that may own the alarm channel. */
internal enum class EngineRole {
    INTERACTIVE,
    HEADLESS,
}

/**
 * Opaque reference authorizing one exact Flutter engine binding.
 *
 * Values have no caller-selected identifier and are compared by reference.
 * A lease only becomes authoritative when [EngineLeaseRegistry.acquire]
 * installs that exact instance.
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
 * Acquisition fails closed while another engine is bound. Callers must close
 * the predecessor explicitly; there is no overwrite operation.
 */
internal class EngineLeaseRegistry<T : Any> {
    private var active: EngineLeaseCapture<T>? = null

    @Synchronized
    fun acquire(role: EngineRole, value: T): EngineLease? {
        if (active != null) return null
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
