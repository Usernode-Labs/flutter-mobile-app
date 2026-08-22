package com.usernode_labs.usernode.alarm

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BackgroundRuntimeEventAuthorityTest {
    @Test
    fun missingJournalLeavesTheLegacyFenceAsTheOnlyStagedOwner() {
        assertTrue(
            BackgroundRuntimeEventAuthority.isAdmitted(
                eventType = "android_alarm_fired",
                eventData = emptyMap(),
                journalIsMissing = { true },
                durableAdmission = { _, _ -> false },
            ),
        )
    }

    @Test
    fun durableAuthorityRejectsAnUnscopedOrStaleRuntimeEvent() {
        assertFalse(
            BackgroundRuntimeEventAuthority.isAdmitted(
                eventType = "android_alarm_fired",
                eventData = emptyMap(),
                journalIsMissing = { false },
                durableAdmission = { _, _ -> true },
            ),
        )
        assertFalse(
            BackgroundRuntimeEventAuthority.isAdmitted(
                eventType = "android_alarm_fired",
                eventData = mapOf(
                    BackgroundRuntimeEventAuthority.SESSION_ID_KEY to "session-a",
                    BackgroundRuntimeEventAuthority.RUNTIME_GENERATION_KEY to 7L,
                ),
                journalIsMissing = { false },
                durableAdmission = { _, _ -> false },
            ),
        )
    }

    @Test
    fun durableAuthorityAdmitsOnlyTheExactPositiveRuntimeEnvelope() {
        assertTrue(
            BackgroundRuntimeEventAuthority.isAdmitted(
                eventType = "android_alarm_fired",
                eventData = mapOf(
                    BackgroundRuntimeEventAuthority.SESSION_ID_KEY to "session-a",
                    BackgroundRuntimeEventAuthority.RUNTIME_GENERATION_KEY to 7L,
                ),
                journalIsMissing = { false },
                durableAdmission = { sessionId, generation ->
                    sessionId == "session-a" && generation == 7L
                },
            ),
        )
        assertFalse(
            BackgroundRuntimeEventAuthority.isAdmitted(
                eventType = "android_alarm_fired",
                eventData = mapOf(
                    BackgroundRuntimeEventAuthority.SESSION_ID_KEY to "session-a",
                    BackgroundRuntimeEventAuthority.RUNTIME_GENERATION_KEY to 0L,
                ),
                journalIsMissing = { false },
                durableAdmission = { _, _ -> true },
            ),
        )
    }

    @Test
    fun uiPermissionSignalsCarryNoRuntimeAuthority() {
        assertTrue(
            BackgroundRuntimeEventAuthority.isAdmitted(
                eventType = "android_exact_alarm_permission_granted",
                eventData = emptyMap(),
                journalIsMissing = { false },
                durableAdmission = { _, _ -> false },
            ),
        )
    }
}
