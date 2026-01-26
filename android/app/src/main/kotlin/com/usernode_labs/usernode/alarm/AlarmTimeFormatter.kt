package com.usernode_labs.usernode.alarm

import java.text.DateFormat
import java.util.Date
import java.util.Locale

object AlarmTimeFormatter {
    fun formatScheduledTime(alarmTimeMs: Long): String? {
        if (alarmTimeMs <= 0L) return null
        val formatter = DateFormat.getDateTimeInstance(
            DateFormat.SHORT,
            DateFormat.MEDIUM,
            Locale.getDefault()
        )
        return formatter.format(Date(alarmTimeMs))
    }
}
