package com.usernode_labs.usernode.alarm

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class NodeRecoveryLeaseStoreTest {
    private val disabled = NodeRecoveryLeaseStore.Lease(
        enabled = false,
        generation = 0L,
        bindingFingerprint = null
    )

    private fun reserve(
        current: NodeRecoveryLeaseStore.Lease,
        bindingFingerprint: String
    ) = NodeRecoveryLeaseStore.reserve(
        current,
        bindingFingerprint,
        current.generation,
        current.bindingFingerprint
    )

    @Test
    fun reservationAdvancesGenerationAndInvalidatesOldActivation() {
        val oldReserved = reserve(disabled, "old")
        val oldActive = NodeRecoveryLeaseStore.activate(
            oldReserved,
            oldReserved.generation,
            "old"
        )
        val replacement = reserve(oldActive, "new")

        assertFalse(replacement.enabled)
        assertEquals(2L, replacement.generation)
        assertEquals("new", replacement.bindingFingerprint)
        assertSame(
            replacement,
            NodeRecoveryLeaseStore.activate(
                replacement,
                oldReserved.generation,
                "old"
            )
        )
    }

    @Test
    fun matchingActivationDoesNotAdvanceTheReservedGeneration() {
        val reserved = reserve(disabled, "binding")
        val active = NodeRecoveryLeaseStore.activate(
            reserved,
            reserved.generation,
            "binding"
        )

        assertTrue(active.enabled)
        assertEquals(reserved.generation, active.generation)
        assertEquals("binding", active.bindingFingerprint)
    }

    @Test
    fun conditionalRevokeCannotClearANewerBinding() {
        val newer = reserve(disabled, "new")

        assertSame(
            newer,
            NodeRecoveryLeaseStore.revoke(newer, newer.generation, "old")
        )
        val revoked = NodeRecoveryLeaseStore.revoke(
            newer,
            newer.generation,
            "new"
        )
        assertFalse(revoked.enabled)
        assertEquals(newer.generation + 1L, revoked.generation)
        assertEquals(null, revoked.bindingFingerprint)
    }

    @Test
    fun revokedGenerationCannotRunNativeRecoverySideEffects() {
        val reserved = reserve(disabled, "binding")
        val active = NodeRecoveryLeaseStore.activate(
            reserved,
            reserved.generation,
            "binding"
        )
        val revoked = NodeRecoveryLeaseStore.revoke(
            active,
            active.generation,
            "binding"
        )
        var sideEffectRan = false

        val accepted = NodeRecoveryLeaseStore.runIfMatches(
            revoked,
            active.generation,
            "binding"
        ) {
            sideEffectRan = true
            true
        }

        assertFalse(accepted)
        assertFalse(sideEffectRan)
    }

    @Test
    fun currentGenerationCanAtomicallyEnqueueNativeRecoverySideEffects() {
        val reserved = reserve(disabled, "binding")
        val active = NodeRecoveryLeaseStore.activate(
            reserved,
            reserved.generation,
            "binding"
        )
        var sideEffectRan = false

        val accepted = NodeRecoveryLeaseStore.runIfMatches(
            active,
            active.generation,
            "binding"
        ) {
            sideEffectRan = true
            true
        }

        assertTrue(accepted)
        assertTrue(sideEffectRan)
    }

    @Test
    fun staleGenerationCannotMutateANewerLeaseWithTheSameFingerprint() {
        val first = reserve(disabled, "binding")
        val firstActive = NodeRecoveryLeaseStore.activate(
            first,
            first.generation,
            "binding"
        )
        val retired = NodeRecoveryLeaseStore.revoke(
            firstActive,
            firstActive.generation,
            "binding"
        )
        val newer = reserve(retired, "binding")

        assertSame(
            newer,
            NodeRecoveryLeaseStore.disable(
                newer,
                firstActive.generation,
                "binding"
            )
        )
        assertSame(
            newer,
            NodeRecoveryLeaseStore.revoke(
                newer,
                firstActive.generation,
                "binding"
            )
        )
        assertSame(
            newer,
            NodeRecoveryLeaseStore.reserve(
                newer,
                "other",
                firstActive.generation,
                "binding"
            )
        )
    }

    @Test
    fun reservationWithoutOwnedAuthorityCannotReplaceCurrentBinding() {
        val current = reserve(disabled, "current")

        assertSame(
            current,
            NodeRecoveryLeaseStore.reserve(
                current,
                "replacement",
                null,
                null
            )
        )
    }
}
