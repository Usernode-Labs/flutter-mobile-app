package com.onhomeroom.app.session

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeApiMigrationTest {
    @Test
    fun `only the exact forward deployment move may retain credentials`() {
        val legacy = "https://social-vibecoding.usernodelabs.org/api/v4/mobile"
        val interim = "https://my.onhomeroom.com/api/v4/mobile"
        val current = "https://app.onhomeroom.com/api/v4/mobile"
        assertTrue(isHomeroomApiMigration(legacy, interim))
        assertTrue(isHomeroomApiMigration(legacy, current))
        assertTrue(isHomeroomApiMigration(interim, current))
        assertFalse(isHomeroomApiMigration(current, interim))
        assertFalse(isHomeroomApiMigration(current, legacy))
        assertFalse(isHomeroomApiMigration(current, current))
        for (other in listOf(
            "https://staging.onhomeroom.com/api/v4/mobile",
            "https://app.onhomeroom.com.evil.test/api/v4/mobile",
            "http://app.onhomeroom.com/api/v4/mobile",
            "https://app.onhomeroom.com/other/api/v4/mobile",
            "$current?override=true",
        )) {
            assertFalse(isHomeroomApiMigration(legacy, other))
            assertFalse(isHomeroomApiMigration(interim, other))
            assertFalse(isHomeroomApiMigration(other, current))
        }
    }
}
