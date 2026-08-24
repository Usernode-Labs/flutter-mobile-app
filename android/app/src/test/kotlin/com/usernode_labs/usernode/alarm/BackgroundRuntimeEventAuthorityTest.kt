package com.usernode_labs.usernode.alarm

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BackgroundRuntimeEventAuthorityTest {
    @Test
    fun privilegedEventsFailClosedWithoutACompleteOwner() {
        assertFalse(
            BackgroundRuntimeEventAuthority.isAdmitted(
                eventType = "android_alarm_fired",
                eventData = emptyMap(),
                durableAdmission = { true },
            ),
        )
        assertFalse(
            BackgroundRuntimeEventAuthority.isAdmitted(
                eventType = "android_alarm_fired",
                eventData = mapOf(
                    BackgroundRuntimeEventAuthority.SESSION_ID_KEY to "session-a",
                    BackgroundRuntimeEventAuthority.RUNTIME_GENERATION_KEY to 7L,
                ),
                durableAdmission = { true },
            ),
        )
    }

    @Test
    fun durableAuthorityAdmitsOnlyTheExactCompleteRuntimeOwner() {
        val owner = RuntimeOwner("session-a", 7, "account-a", "address-a")
        assertTrue(
            BackgroundRuntimeEventAuthority.isAdmitted(
                eventType = "android_alarm_fired",
                eventData = owner.toMap(),
                durableAdmission = { it == owner },
            ),
        )
        assertFalse(
            BackgroundRuntimeEventAuthority.isAdmitted(
                eventType = "android_alarm_fired",
                eventData = owner.copy(address = "address-b").toMap(),
                durableAdmission = { it == owner },
            ),
        )
    }

    @Test
    fun uiPermissionSignalsCarryNoRuntimeAuthority() {
        assertTrue(
            BackgroundRuntimeEventAuthority.isAdmitted(
                eventType = "android_exact_alarm_permission_granted",
                eventData = emptyMap(),
                durableAdmission = { false },
            ),
        )
    }
}
