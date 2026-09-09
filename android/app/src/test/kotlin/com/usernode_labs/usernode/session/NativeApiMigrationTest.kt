package com.usernode_labs.usernode.session

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeApiMigrationTest {
    @Test
    fun `only the exact forward deployment move may retain credentials`() {
        val old = "https://social-vibecoding.usernodelabs.org/api/v4/mobile"
        val next = "https://my.onhomeroom.com/api/v4/mobile"
        assertTrue(isHomeroomApiMigration(old, next))
        assertFalse(isHomeroomApiMigration(next, old))
        assertFalse(isHomeroomApiMigration(old, old))
        for (other in listOf(
            "https://staging.onhomeroom.com/api/v4/mobile",
            "https://my.onhomeroom.com.evil.test/api/v4/mobile",
            "http://my.onhomeroom.com/api/v4/mobile",
            "https://my.onhomeroom.com/other/api/v4/mobile",
            "$next?override=true",
        )) {
            assertFalse(isHomeroomApiMigration(old, other))
            assertFalse(isHomeroomApiMigration(other, next))
        }
    }
}
