package com.onhomeroom.app.session

import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeProducerPolicyRequestTest {
    @Test
    fun `local recovery completes while policy HTTP is pending`() {
        PendingRefresh().use { refresh ->
            val result = refresh.start()
            refresh.locally {
                // This uses the same monitor as interactive cold recovery.
                assertEquals("credential-a", refresh.storedRaw)
                assertFalse(result.isDone)
            }
            refresh.respond.countDown()

            assertSame(refresh.evidence, result.get(5, TimeUnit.SECONDS))
            assertEquals(1, refresh.applied)
            assertArrayEquals(ByteArray(3), refresh.secret)
        }
    }

    @Test
    fun `an old unauthorized response cannot delete a replacement credential`() {
        PendingRefresh(NativeHttpResult.Unauthorized).use { refresh ->
            val result = refresh.start()
            refresh.locally { refresh.storedRaw = "credential-b" }
            refresh.respond.countDown()

            assertSame(ProducerWakeCredential.Uncertain, result.get(5, TimeUnit.SECONDS))
            assertEquals("credential-b", refresh.storedRaw)
            assertEquals(0, refresh.applied)
            assertArrayEquals(ByteArray(3), refresh.secret)
        }
    }

    @Test
    fun `logout while HTTP is pending prevents epoch fallback publication`() {
        PendingRefresh().use { refresh ->
            val result = refresh.start()
            refresh.locally { refresh.storedRaw = null }
            refresh.respond.countDown()

            assertSame(ProducerWakeCredential.Uncertain, result.get(5, TimeUnit.SECONDS))
            assertEquals(null, refresh.storedRaw)
            assertEquals(0, refresh.applied)
        }
    }

    @Test
    fun `a concurrent lease renewal invalidates the earlier snapshot`() {
        PendingRefresh().use { refresh ->
            val result = refresh.start()
            refresh.locally { refresh.storedRaw = "credential-a-renewed-lease" }
            refresh.respond.countDown()

            assertSame(ProducerWakeCredential.Uncertain, result.get(5, TimeUnit.SECONDS))
            assertEquals("credential-a-renewed-lease", refresh.storedRaw)
            assertEquals(0, refresh.applied)
        }
    }

    @Test
    fun `an origin change invalidates an otherwise unchanged credential snapshot`() {
        PendingRefresh().use { refresh ->
            val result = refresh.start()
            refresh.locally { refresh.origin = "https://new.example/api" }
            refresh.respond.countDown()

            assertSame(ProducerWakeCredential.Uncertain, result.get(5, TimeUnit.SECONDS))
            assertEquals(0, refresh.applied)
        }
    }

    @Test
    fun `unauthorized response still retires the unchanged credential`() {
        PendingRefresh(NativeHttpResult.Unauthorized).use { refresh ->
            val result = refresh.start()
            refresh.respond.countDown()

            assertSame(ProducerWakeCredential.Absent, result.get(5, TimeUnit.SECONDS))
            assertEquals(null, refresh.storedRaw)
            assertEquals(1, refresh.applied)
        }
    }

    @Test
    fun `request failure releases decrypted material without applying a response`() {
        val secret = byteArrayOf(1, 2, 3)
        val failure = IllegalStateException("request failed")
        val request = NativeProducerPolicyRequest(
            storedRaw = "credential-a",
            origin = "https://example.com/api",
            fetch = { throw failure },
            apply = { error("A failed request has no response to apply") },
            release = { secret.fill(0) },
        )

        assertSame(failure, assertThrows(IllegalStateException::class.java) {
            request.execute(Any(), { "credential-a" }, { "https://example.com/api" })
        })
        assertArrayEquals(ByteArray(3), secret)
    }

    @Test
    fun `response application failure also releases decrypted material`() {
        val secret = byteArrayOf(1, 2, 3)
        val failure = IllegalStateException("response failed validation")
        val request = NativeProducerPolicyRequest(
            storedRaw = "credential-a",
            origin = "https://example.com/api",
            fetch = { NativeHttpResult.Unauthorized },
            apply = { throw failure },
            release = { secret.fill(0) },
        )

        assertSame(failure, assertThrows(IllegalStateException::class.java) {
            request.execute(Any(), { "credential-a" }, { "https://example.com/api" })
        })
        assertArrayEquals(ByteArray(3), secret)
    }

    private class PendingRefresh(
        private val response: NativeHttpResult = NativeHttpResult.Failure(
            503, "node_epoch_unavailable", null,
        ),
    ) : AutoCloseable {
        private val monitor = Any()
        private val workers = Executors.newFixedThreadPool(2)
        private val fetching = CountDownLatch(1)
        val respond = CountDownLatch(1)
        var storedRaw: String? = "credential-a"
        var origin = "https://example.com/api"
        var applied = 0
        val secret = byteArrayOf(1, 2, 3)
        val evidence = ProducerWakeCredential.Present(byteArrayOf(1), byteArrayOf(2))

        fun start() = workers.submit<ProducerWakeCredential> {
            val request = synchronized(monitor) {
                NativeProducerPolicyRequest(
                    storedRaw = storedRaw!!,
                    origin = origin,
                    fetch = {
                        assertFalse(Thread.holdsLock(monitor))
                        fetching.countDown()
                        assertTrue(respond.await(10, TimeUnit.SECONDS))
                        response
                    },
                    apply = {
                        assertTrue(Thread.holdsLock(monitor))
                        applied += 1
                        if (it == NativeHttpResult.Unauthorized) {
                            storedRaw = null
                            ProducerWakeCredential.Absent
                        } else {
                            evidence
                        }
                    },
                    release = { secret.fill(0) },
                )
            }
            request.execute(
                vaultMonitor = monitor,
                currentStoredRaw = {
                    assertTrue(Thread.holdsLock(monitor))
                    storedRaw
                },
                currentOrigin = {
                    assertTrue(Thread.holdsLock(monitor))
                    origin
                },
            )
        }.also { assertTrue(fetching.await(5, TimeUnit.SECONDS)) }

        fun locally(action: () -> Unit) {
            workers.submit { synchronized(monitor, action) }.get(5, TimeUnit.SECONDS)
        }

        override fun close() {
            respond.countDown()
            workers.shutdownNow()
            assertTrue(workers.awaitTermination(5, TimeUnit.SECONDS))
        }
    }
}
