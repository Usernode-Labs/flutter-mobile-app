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

class NativeSchedulingAuthorityTest {
    @Test
    fun admittedInstallationFinishesBeforeRotation() {
        val scheduleHasAuthority = CountDownLatch(1)
        val allowSchedule = CountDownLatch(1)
        val rotationReachedAcquire = CountDownLatch(1)
        val checkpoints = Collections.synchronizedList(mutableListOf<String>())
        val authority = NativeSchedulingAuthority { operation, point ->
            checkpoints += "$operation:${point.name}"
            when {
                operation == "schedule" &&
                    point == NativeSchedulingCheckpoint.AFTER_ACQUIRE -> {
                    scheduleHasAuthority.countDown()
                    assertTrue(allowSchedule.await(5, TimeUnit.SECONDS))
                }
                operation == "rotate" &&
                    point == NativeSchedulingCheckpoint.BEFORE_ACQUIRE -> {
                    rotationReachedAcquire.countDown()
                }
            }
        }
        val current = AtomicReference("incarnation-a")
        val effects = Collections.synchronizedList(mutableListOf<String>())
        val executor = Executors.newFixedThreadPool(2)

        try {
            val schedule = executor.submit<Boolean> {
                authority.runIfCurrent(
                    operation = "schedule",
                    captured = "incarnation-a",
                    current = current::get,
                ) {
                    effects += listOf("setExact", "persist", "notification")
                    true
                }
            }
            assertTrue(scheduleHasAuthority.await(5, TimeUnit.SECONDS))

            val rotate = executor.submit<String> {
                authority.serialized("rotate") {
                    current.set("incarnation-b")
                    effects += "rotate"
                    current.get()
                }
            }
            assertTrue(rotationReachedAcquire.await(5, TimeUnit.SECONDS))
            allowSchedule.countDown()

            assertTrue(schedule.get(5, TimeUnit.SECONDS))
            assertEquals("incarnation-b", rotate.get(5, TimeUnit.SECONDS))
            assertEquals(
                listOf("setExact", "persist", "notification", "rotate"),
                effects,
            )
            assertCompleteAcquireRelease(checkpoints, "schedule")
            assertCompleteAcquireRelease(checkpoints, "rotate")
        } finally {
            executor.shutdownNow()
        }
    }

    @Test
    fun rotationWinningRejectsInstallationBeforeItsFirstEffect() {
        val rotationHasAuthority = CountDownLatch(1)
        val allowRotation = CountDownLatch(1)
        val scheduleReachedAcquire = CountDownLatch(1)
        val authority = NativeSchedulingAuthority { operation, point ->
            when {
                operation == "rotate" &&
                    point == NativeSchedulingCheckpoint.AFTER_ACQUIRE -> {
                    rotationHasAuthority.countDown()
                    assertTrue(allowRotation.await(5, TimeUnit.SECONDS))
                }
                operation == "schedule" &&
                    point == NativeSchedulingCheckpoint.BEFORE_ACQUIRE -> {
                    scheduleReachedAcquire.countDown()
                }
            }
        }
        val current = AtomicReference("incarnation-a")
        val installed = AtomicReference(false)
        val executor = Executors.newFixedThreadPool(2)

        try {
            val rotate = executor.submit<Unit> {
                authority.serialized("rotate") {
                    current.set("incarnation-b")
                }
            }
            assertTrue(rotationHasAuthority.await(5, TimeUnit.SECONDS))

            val schedule = executor.submit<Boolean> {
                authority.runIfCurrent(
                    operation = "schedule",
                    captured = "incarnation-a",
                    current = current::get,
                ) {
                    installed.set(true)
                    true
                }
            }
            assertTrue(scheduleReachedAcquire.await(5, TimeUnit.SECONDS))
            allowRotation.countDown()

            rotate.get(5, TimeUnit.SECONDS)
            assertFalse(schedule.get(5, TimeUnit.SECONDS))
            assertFalse(installed.get())
        } finally {
            executor.shutdownNow()
        }
    }

    @Test
    fun staleScheduleCannotInsertAfterRetirementCancellation() {
        val cancellationHasAuthority = CountDownLatch(1)
        val allowCancellation = CountDownLatch(1)
        val scheduleReachedAcquire = CountDownLatch(1)
        val authority = NativeSchedulingAuthority { operation, point ->
            when {
                operation == "cancel" &&
                    point == NativeSchedulingCheckpoint.AFTER_ACQUIRE -> {
                    cancellationHasAuthority.countDown()
                    assertTrue(allowCancellation.await(5, TimeUnit.SECONDS))
                }
                operation == "stale-schedule" &&
                    point == NativeSchedulingCheckpoint.BEFORE_ACQUIRE -> {
                    scheduleReachedAcquire.countDown()
                }
            }
        }
        val current = AtomicReference("incarnation-b")
        val effects = Collections.synchronizedList(mutableListOf<String>())
        val executor = Executors.newFixedThreadPool(2)

        try {
            val cancel = executor.submit<Boolean> {
                authority.runIfCurrent(
                    operation = "cancel",
                    captured = "incarnation-b",
                    current = current::get,
                ) {
                    effects += "cancel"
                    true
                }
            }
            assertTrue(cancellationHasAuthority.await(5, TimeUnit.SECONDS))

            val schedule = executor.submit<Boolean> {
                authority.runIfCurrent(
                    operation = "stale-schedule",
                    captured = "incarnation-a",
                    current = current::get,
                ) {
                    effects += "setExact"
                    true
                }
            }
            assertTrue(scheduleReachedAcquire.await(5, TimeUnit.SECONDS))
            allowCancellation.countDown()

            assertTrue(cancel.get(5, TimeUnit.SECONDS))
            assertFalse(schedule.get(5, TimeUnit.SECONDS))
            assertEquals(listOf("cancel"), effects)
        } finally {
            executor.shutdownNow()
        }
    }

    private fun assertCompleteAcquireRelease(
        checkpoints: List<String>,
        operation: String,
    ) {
        assertEquals(
            listOf(
                "$operation:BEFORE_ACQUIRE",
                "$operation:AFTER_ACQUIRE",
                "$operation:BEFORE_RELEASE",
                "$operation:AFTER_RELEASE",
            ),
            checkpoints.filter { it.startsWith("$operation:") },
        )
    }
}
