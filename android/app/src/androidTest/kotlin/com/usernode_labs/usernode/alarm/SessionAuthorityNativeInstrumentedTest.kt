package com.usernode_labs.usernode.alarm

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import io.flutter.embedding.engine.FlutterEngineCache
import java.io.File
import org.junit.After
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SessionAuthorityNativeInstrumentedTest {
    private lateinit var context: Context
    private lateinit var journalDirectory: File

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        journalDirectory = File(context.filesDir, "session-authority")
        journalDirectory.deleteRecursively()
        check(journalDirectory.mkdirs())
        BackgroundAlarmEngine.destroyCachedEngine("phase_0a_setup")
    }

    @After
    fun tearDown() {
        BackgroundAlarmEngine.destroyCachedEngine("phase_0a_teardown")
        journalDirectory.deleteRecursively()
    }

    @Test
    fun shippedAlarmEntryReadsRustJournalBeforeCreatingFlutter() {
        File(journalDirectory, "session-authority-v1.json").writeText("{")
        val owner = RuntimeOwner("session-a", 7, "account-a", "address-a")

        val admitted = BackgroundAlarmEngine.isEventAdmittedBeforeFlutter(
            context = context,
            eventType = "android_alarm_fired",
            eventData = owner.toMap(),
        )

        assertFalse(admitted)
        assertNull(FlutterEngineCache.getInstance().get(BackgroundAlarmEngine.ENGINE_ID))
        val nativeAdmission = com.usernode_labs.usernode.session.SessionAuthorityNative
            .admissionJson(context)
        assertTrue(nativeAdmission.contains("\"status\":\"terminal\""))
        assertTrue(nativeAdmission.contains("invalid JSON"))
        assertFalse(nativeAdmission.contains("library unavailable"))
        assertFalse(
            com.usernode_labs.usernode.session.SessionAuthorityNative
                .isBackgroundRuntimeAdmitted(context, owner),
        )
    }
}
