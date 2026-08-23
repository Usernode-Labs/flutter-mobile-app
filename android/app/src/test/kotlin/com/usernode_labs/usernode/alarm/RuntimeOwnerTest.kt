package com.usernode_labs.usernode.alarm

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class RuntimeOwnerTest {
    private val owner = RuntimeOwner(
        sessionId = "session-a",
        runtimeGeneration = 7,
        accountId = "account-a",
        address = "address-a",
    )

    @Test
    fun completeOwnerRoundTripsThroughTheNativeMap() {
        assertEquals(
            mapOf(
                "session_id" to "session-a",
                "runtime_generation" to 7L,
                "account_id" to "account-a",
                "address" to "address-a",
            ),
            owner.toMap(),
        )
        assertEquals(owner, RuntimeOwner.fromMap(owner.toMap()))
    }

    @Test
    fun missingMalformedAndZeroFieldsFailClosed() {
        val valid = owner.toMap()
        for (invalid in listOf(
            valid - "session_id",
            valid - "runtime_generation",
            valid - "account_id",
            valid - "address",
            valid + ("session_id" to ""),
            valid + ("runtime_generation" to 0L),
            valid + ("runtime_generation" to "7"),
            valid + ("account_id" to ""),
            valid + ("address" to ""),
        )) {
            assertNull(RuntimeOwner.fromMap(invalid))
        }
    }
}
