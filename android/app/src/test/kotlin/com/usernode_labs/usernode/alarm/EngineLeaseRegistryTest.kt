package com.usernode_labs.usernode.alarm

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

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
}
