package com.usernode_labs.usernode.alarm

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

class EngineLeaseRegistryTest {
    @Test
    fun `acquire refuses overwrite and stale release cannot clear successor`() {
        val registry = EngineLeaseRegistry<Any>()
        val firstValue = Any()
        val first = registry.acquire(EngineRole.HEADLESS, firstValue)!!

        assertNull(registry.acquire(EngineRole.INTERACTIVE, Any()))
        assertSame(firstValue, registry.capture()!!.value)
        assertSame(firstValue, registry.compareRelease(first))

        val secondValue = Any()
        val second = registry.acquire(EngineRole.INTERACTIVE, secondValue)!!
        assertNull(registry.compareRelease(first))
        assertTrue(registry.isCurrent(second))
        assertFalse(registry.isCurrent(first))
        assertSame(secondValue, registry.capture()!!.value)
        assertEquals(EngineRole.INTERACTIVE, second.role)
    }

    @Test
    fun `release linearizes after synchronous dispatch scheduling`() {
        val registry = EngineLeaseRegistry<Any>()
        val value = Any()
        val lease = registry.acquire(EngineRole.HEADLESS, value)!!
        val dispatchEntered = CountDownLatch(1)
        val allowDispatchToReturn = CountDownLatch(1)
        val dispatchFailure = AtomicReference<Throwable?>()
        val released = AtomicReference<Any?>()

        val dispatchThread = Thread {
            try {
                assertTrue(
                    registry.runIfCurrent(lease) { captured ->
                        assertSame(value, captured)
                        dispatchEntered.countDown()
                        assertTrue(allowDispatchToReturn.await(2, TimeUnit.SECONDS))
                    },
                )
            } catch (failure: Throwable) {
                dispatchFailure.set(failure)
            }
        }
        dispatchThread.start()
        assertTrue(dispatchEntered.await(2, TimeUnit.SECONDS))

        val releaseThread = Thread {
            released.set(registry.compareRelease(lease))
        }
        releaseThread.start()
        assertTrue(awaitBlocked(releaseThread))

        allowDispatchToReturn.countDown()
        dispatchThread.join(2000)
        releaseThread.join(2000)

        assertFalse(dispatchThread.isAlive)
        assertFalse(releaseThread.isAlive)
        assertNull(dispatchFailure.get())
        assertSame(value, released.get())
        assertFalse(registry.runIfCurrent(lease) { error("stale dispatch ran") })
    }

    private fun awaitBlocked(thread: Thread): Boolean {
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(2)
        while (System.nanoTime() < deadline) {
            if (thread.state == Thread.State.BLOCKED) return true
            Thread.yield()
        }
        return false
    }
}
