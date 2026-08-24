package com.usernode_labs.usernode.alarm

import java.util.Collections
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ExactRuntimeSchedulingAuthorityTest {
    private val ownerA = RuntimeOwner("session-a", 7, "account-a", "address-a")
    private val ownerB = RuntimeOwner("session-b", 1, "account-b", "address-b")

    @Test
    fun acceptedACompletesBeforeQueuedBUsesTheSameNativeOwner() {
        val aAdmitted = CountDownLatch(1)
        val releaseA = CountDownLatch(1)
        val bQueued = CountDownLatch(1)
        val journalOwner = AtomicReference(ownerA)
        val effects = Collections.synchronizedList(mutableListOf<String>())
        val authority = NativeSchedulingAuthority { operation, point ->
            when {
                operation == "schedule-b" &&
                    point == NativeSchedulingCheckpoint.BEFORE_ACQUIRE -> bQueued.countDown()
            }
        }
        val executor = Executors.newFixedThreadPool(2)

        try {
            val a = executor.submit<Boolean> {
                authority.runIfAdmitted(
                    operation = "schedule-a",
                    owner = ownerA,
                    admitted = {
                        val accepted = it == journalOwner.get()
                        aAdmitted.countDown()
                        assertTrue(releaseA.await(5, TimeUnit.SECONDS))
                        accepted
                    },
                ) {
                    effects += "A"
                    true
                }
            }
            assertTrue(aAdmitted.await(5, TimeUnit.SECONDS))

            journalOwner.set(ownerB)
            val b = executor.submit<Boolean> {
                authority.runIfAdmitted(
                    operation = "schedule-b",
                    owner = ownerB,
                    admitted = { it == journalOwner.get() },
                ) {
                    effects += "B"
                    true
                }
            }
            assertTrue(bQueued.await(5, TimeUnit.SECONDS))
            releaseA.countDown()

            assertTrue(a.get(5, TimeUnit.SECONDS))
            assertTrue(b.get(5, TimeUnit.SECONDS))
            assertEquals(listOf("A", "B"), effects)
        } finally {
            executor.shutdownNow()
        }
    }

    @Test
    fun retirementWinningBeforeAdmissionReachesNoSink() {
        val journalOwner = AtomicReference<RuntimeOwner?>(null)
        var reachedSink = false
        val authority = NativeSchedulingAuthority()

        assertFalse(
            authority.runIfAdmitted(
                operation = "stale-a",
                owner = ownerA,
                admitted = { it == journalOwner.get() },
            ) {
                reachedSink = true
                true
            },
        )
        assertFalse(reachedSink)
    }

    @Test
    fun lateACleanupCannotRemoveAResourceReplacedByB() {
        val resourceOwner = AtomicReference<RuntimeOwner?>(ownerB)
        var removed = false
        val authority = NativeSchedulingAuthority()

        assertFalse(
            authority.runIfOwned(
                operation = "cleanup-a",
                owner = ownerA,
                resourceOwner = resourceOwner::get,
            ) {
                removed = true
                resourceOwner.set(null)
                true
            },
        )
        assertFalse(removed)
        assertEquals(ownerB, resourceOwner.get())
    }
}
