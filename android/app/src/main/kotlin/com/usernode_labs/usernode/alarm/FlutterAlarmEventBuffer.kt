package com.usernode_labs.usernode.alarm

data class FlutterAlarmEvent(
    val eventType: String,
    val eventData: Map<String, Any?>,
)

class FlutterAlarmEventBuffer(
    private val maxPendingEvents: Int = 32,
) {
    private val pendingEvents = ArrayDeque<FlutterAlarmEvent>()
    private var flutterReady = false

    @Synchronized
    fun enqueueOrDispatch(
        eventType: String,
        eventData: Map<String, Any?>,
    ): FlutterAlarmEvent? {
        val event = FlutterAlarmEvent(eventType, LinkedHashMap(eventData))
        if (flutterReady) {
            return event
        }

        if (pendingEvents.size >= maxPendingEvents) {
            pendingEvents.removeFirst()
        }
        pendingEvents.addLast(event)
        return null
    }

    @Synchronized
    fun markFlutterReady(): List<FlutterAlarmEvent> {
        flutterReady = true
        return drainLocked()
    }

    @Synchronized
    fun markFlutterNotReady() {
        flutterReady = false
    }

    @Synchronized
    fun drainIfReady(): List<FlutterAlarmEvent> {
        if (!flutterReady) {
            return emptyList()
        }
        return drainLocked()
    }

    @Synchronized
    fun pendingCount(): Int = pendingEvents.size

    private fun drainLocked(): List<FlutterAlarmEvent> {
        if (pendingEvents.isEmpty()) {
            return emptyList()
        }

        val drained = ArrayList<FlutterAlarmEvent>(pendingEvents.size)
        while (pendingEvents.isNotEmpty()) {
            drained.add(pendingEvents.removeFirst())
        }
        return drained
    }
}
