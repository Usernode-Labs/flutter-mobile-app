package com.usernode_labs.usernode.alarm

import android.content.Context

/**
 * Durable authority for Android background node recovery.
 *
 * Every alarm/worker captures the current generation and binding fingerprint.
 * Logout, rebinding, and producer revocation invalidate queued work by advancing
 * the generation before the runtime is stopped.
 */
object NodeRecoveryLeaseStore {
    private const val PREFS_NAME = "node_recovery_lease"
    private const val ENABLED_KEY = "enabled"
    private const val GENERATION_KEY = "generation"
    private const val BINDING_FINGERPRINT_KEY = "binding_fingerprint"

    data class Lease(
        val enabled: Boolean,
        val generation: Long,
        val bindingFingerprint: String?
    ) {
        fun asMap(): Map<String, Any?> = mapOf(
            "enabled" to enabled,
            "generation" to generation,
            "bindingFingerprint" to bindingFingerprint
        )
    }

    data class MutationResult(
        val lease: Lease,
        val accepted: Boolean
    ) {
        fun asMap(): Map<String, Any?> = lease.asMap() + ("accepted" to accepted)
    }

    @Synchronized
    fun reserve(
        context: Context,
        bindingFingerprint: String,
        expectedGeneration: Long?,
        expectedBindingFingerprint: String?,
        onSuperseded: () -> Unit = {}
    ): MutationResult {
        val current = load(context)
        val accepted = sameAuthority(
            current,
            expectedGeneration,
            expectedBindingFingerprint
        )
        if (!accepted) return MutationResult(current, false)
        val next = reserve(
            current,
            bindingFingerprint,
            expectedGeneration,
            expectedBindingFingerprint
        )
        if (next == current) return MutationResult(current, true)
        persist(context, next)
        onSuperseded()
        return MutationResult(next, true)
    }

    @Synchronized
    fun activate(
        context: Context,
        generation: Long?,
        bindingFingerprint: String?
    ): MutationResult {
        val current = load(context)
        val accepted = sameAuthority(current, generation, bindingFingerprint) &&
            bindingFingerprint != null
        if (!accepted) return MutationResult(current, false)
        val next = activate(current, generation, bindingFingerprint)
        if (next == current) return MutationResult(current, true)
        persist(context, next)
        return MutationResult(next, true)
    }

    @Synchronized
    fun disable(
        context: Context,
        generation: Long?,
        bindingFingerprint: String?,
        onDisabled: () -> Unit = {}
    ): MutationResult {
        val current = load(context)
        val accepted = sameAuthority(current, generation, bindingFingerprint) &&
            bindingFingerprint != null
        if (!accepted) return MutationResult(current, false)
        val next = disable(current, generation, bindingFingerprint)
        if (next == current) return MutationResult(current, true)
        persist(context, next)
        onDisabled()
        return MutationResult(next, true)
    }

    @Synchronized
    fun revoke(
        context: Context,
        expectedGeneration: Long?,
        expectedBindingFingerprint: String?,
        onRevoked: () -> Unit = {}
    ): MutationResult {
        val current = load(context)
        if (!sameAuthority(current, expectedGeneration, expectedBindingFingerprint)) {
            return MutationResult(current, false)
        }
        val next = revoke(current, expectedGeneration, expectedBindingFingerprint)
        if (next == current) return MutationResult(current, true)
        persist(context, next)
        onRevoked()
        return MutationResult(next, true)
    }

    internal fun reserve(
        current: Lease,
        bindingFingerprint: String,
        expectedGeneration: Long?,
        expectedBindingFingerprint: String?
    ): Lease {
        if (!sameAuthority(current, expectedGeneration, expectedBindingFingerprint)) {
            return current
        }
        if (current.bindingFingerprint == bindingFingerprint) return current
        return Lease(
            enabled = false,
            generation = current.generation + 1L,
            bindingFingerprint = bindingFingerprint
        )
    }

    internal fun activate(
        current: Lease,
        generation: Long?,
        bindingFingerprint: String?
    ): Lease {
        if (!sameAuthority(current, generation, bindingFingerprint) ||
            bindingFingerprint == null ||
            current.enabled
        ) {
            return current
        }
        return current.copy(enabled = true)
    }

    internal fun disable(
        current: Lease,
        generation: Long?,
        bindingFingerprint: String?
    ): Lease {
        if (!sameAuthority(current, generation, bindingFingerprint) ||
            bindingFingerprint == null ||
            !current.enabled
        ) {
            return current
        }
        return current.copy(enabled = false)
    }

    internal fun revoke(
        current: Lease,
        expectedGeneration: Long?,
        expectedBindingFingerprint: String?
    ): Lease {
        if (!sameAuthority(current, expectedGeneration, expectedBindingFingerprint)) {
            return current
        }
        if (!current.enabled && current.bindingFingerprint == null) return current
        return Lease(
            enabled = false,
            generation = current.generation + 1L,
            bindingFingerprint = null
        )
    }

    fun load(context: Context): Lease {
        val prefs = prefs(context)
        return Lease(
            enabled = prefs.getBoolean(ENABLED_KEY, false),
            generation = prefs.getLong(GENERATION_KEY, 0L),
            bindingFingerprint = prefs.getString(BINDING_FINGERPRINT_KEY, null)
        )
    }

    fun matches(
        context: Context,
        generation: Long?,
        bindingFingerprint: String?
    ): Boolean = matches(load(context), generation, bindingFingerprint)

    /**
     * Runs a native recovery side effect under the same process lock used by
     * reserve/revoke. Either the side effect is enqueued before revocation (so
     * teardown observes and stops it), or revocation wins and it never runs.
     */
    @Synchronized
    fun runIfMatches(
        context: Context,
        generation: Long?,
        bindingFingerprint: String?,
        action: () -> Boolean
    ): Boolean = runIfMatches(
        load(context),
        generation,
        bindingFingerprint,
        action
    )

    internal fun matches(
        current: Lease,
        generation: Long?,
        bindingFingerprint: String?
    ): Boolean {
        if (generation == null || bindingFingerprint == null) return false
        return current.enabled &&
            current.generation == generation &&
            current.bindingFingerprint == bindingFingerprint
    }

    internal fun sameAuthority(
        current: Lease,
        generation: Long?,
        bindingFingerprint: String?
    ): Boolean = generation != null &&
        current.generation == generation &&
        current.bindingFingerprint == bindingFingerprint

    internal fun runIfMatches(
        current: Lease,
        generation: Long?,
        bindingFingerprint: String?,
        action: () -> Boolean
    ): Boolean {
        if (!matches(current, generation, bindingFingerprint)) return false
        return action()
    }

    private fun persist(context: Context, lease: Lease) {
        prefs(context)
            .edit()
            .putBoolean(ENABLED_KEY, lease.enabled)
            .putLong(GENERATION_KEY, lease.generation)
            .putString(BINDING_FINGERPRINT_KEY, lease.bindingFingerprint)
            .commit()
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
