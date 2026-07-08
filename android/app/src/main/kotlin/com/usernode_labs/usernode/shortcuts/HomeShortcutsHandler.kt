package com.usernode_labs.usernode.shortcuts

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Log
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import com.usernode_labs.usernode.R
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

private const val TAG = "usernode/HomeShortcuts"

// Bound so oversized dapp icons don't blow shortcut memory; launchers only
// need ~108dp of adaptive-icon content anyway.
private const val MAX_ICON_DIMENSION = 512

/**
 * Native side of the `com.usernode.app/home_shortcuts` MethodChannel:
 * pins launcher shortcuts that deep-link back into the app via
 * `usernode://app/dapps/pinned/<id>`.
 */
class HomeShortcutsHandler(private val context: Context) {

    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isPinShortcutSupported" ->
                result.success(ShortcutManagerCompat.isRequestPinShortcutSupported(context))
            "requestPinShortcut" -> requestPinShortcut(call, result)
            else -> result.notImplemented()
        }
    }

    private fun requestPinShortcut(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
        val label = call.argument<String>("label")
        val deepLink = call.argument<String>("deepLink")
        val iconBytes = call.argument<ByteArray>("iconBytes")

        if (id.isNullOrBlank() || label.isNullOrBlank() || deepLink.isNullOrBlank()) {
            result.error("invalid_args", "id, label and deepLink are required", null)
            return
        }
        if (!ShortcutManagerCompat.isRequestPinShortcutSupported(context)) {
            result.success(false)
            return
        }

        // Pin the deep link to our own package so the shortcut can't be
        // hijacked by another usernode:// handler.
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(deepLink)).apply {
            setPackage(context.packageName)
        }

        val shortcut = ShortcutInfoCompat.Builder(context, "pinned_dapp_$id")
            .setShortLabel(label)
            .setLongLabel(label)
            .setIcon(buildIcon(iconBytes))
            .setIntent(intent)
            .build()

        try {
            result.success(ShortcutManagerCompat.requestPinShortcut(context, shortcut, null))
        } catch (e: Exception) {
            Log.w(TAG, "requestPinShortcut failed", e)
            result.error("pin_failed", e.message, null)
        }
    }

    private fun buildIcon(iconBytes: ByteArray?): IconCompat {
        if (iconBytes != null && iconBytes.isNotEmpty()) {
            try {
                var bitmap = BitmapFactory.decodeByteArray(iconBytes, 0, iconBytes.size)
                if (bitmap != null) {
                    if (bitmap.width > MAX_ICON_DIMENSION || bitmap.height > MAX_ICON_DIMENSION) {
                        val scale =
                            MAX_ICON_DIMENSION.toFloat() / maxOf(bitmap.width, bitmap.height)
                        bitmap = Bitmap.createScaledBitmap(
                            bitmap,
                            (bitmap.width * scale).toInt().coerceAtLeast(1),
                            (bitmap.height * scale).toInt().coerceAtLeast(1),
                            true,
                        )
                    }
                    return try {
                        IconCompat.createWithAdaptiveBitmap(bitmap)
                    } catch (e: Exception) {
                        Log.w(TAG, "Adaptive icon failed, using plain bitmap", e)
                        IconCompat.createWithBitmap(bitmap)
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Failed to decode shortcut icon, using launcher icon", e)
            }
        }
        return IconCompat.createWithResource(context, R.mipmap.ic_launcher)
    }
}
