package com.example.copypaws

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val WIDGET_CHANNEL = "widget_channel"
    private val SYSTEM_SETTINGS_CHANNEL = "system_settings_channel"
    private val CLIPBOARD_IMAGE_CHANNEL = "clipboard_image_channel"
    private var widgetChannel: MethodChannel? = null
    private var systemSettingsChannel: MethodChannel? = null
    private var clipboardImageChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Setup method channel for widget deep link communication
        widgetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
        systemSettingsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_SETTINGS_CHANNEL)
        clipboardImageChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CLIPBOARD_IMAGE_CHANNEL)
        systemSettingsChannel?.setMethodCallHandler(::handleSystemSettingsCall)
        clipboardImageChannel?.setMethodCallHandler(::handleClipboardImageCall)
        
        Log.d("MainActivity", "Widget channel configured")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val data = intent?.data
        if (data != null && data.scheme == "copypaws") {
            val action = data.host ?: "open"
            Log.d("MainActivity", "Deep link received: copypaws://$action")
            
            // Forward to Flutter via method channel
            widgetChannel?.invokeMethod("widgetAction", mapOf(
                "action" to action,
                "uri" to data.toString()
            ))
        }
    }

    private fun handleSystemSettingsCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isIgnoringBatteryOptimizations" -> {
                result.success(isIgnoringBatteryOptimizations())
            }
            "requestIgnoreBatteryOptimizations" -> {
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:$packageName")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                    }
                    result.success(true)
                } catch (e: Exception) {
                    Log.e("MainActivity", "Failed to request battery optimization exemption", e)
                    result.error("battery_optimization_request_failed", e.message, null)
                }
            }
            "openBatteryOptimizationSettings" -> {
                try {
                    val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    Log.e("MainActivity", "Failed to open battery optimization settings", e)
                    result.error("battery_optimization_settings_failed", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun handleClipboardImageCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setImageContent" -> {
                val base64Data = call.argument<String>("base64Data")
                val mimeType = call.argument<String>("mimeType")
                val clipId = call.argument<String>("clipId") ?: "clipboard_image"

                if (base64Data.isNullOrBlank()) {
                    result.error("invalid_args", "base64Data is required", null)
                    return
                }

                try {
                    result.success(setImageClipboard(base64Data, mimeType, clipId))
                } catch (e: Exception) {
                    Log.e("MainActivity", "Failed to set image clipboard content", e)
                    result.error("clipboard_image_failed", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }

        val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
        return powerManager?.isIgnoringBatteryOptimizations(packageName) ?: false
    }

    private fun setImageClipboard(base64Data: String, mimeType: String?, clipId: String): Boolean {
        val imageBytes = android.util.Base64.decode(base64Data, android.util.Base64.DEFAULT)
        require(imageBytes.isNotEmpty()) { "Decoded image bytes are empty" }

        val resolvedMimeType = resolveMimeType(mimeType, imageBytes)
        val extension = extensionForMimeType(resolvedMimeType)
        val imageDir = File(cacheDir, "clipboard_images")
        if (!imageDir.exists()) {
            imageDir.mkdirs()
        }

        val safeClipId = clipId.replace(Regex("[^A-Za-z0-9._-]"), "_")
        val imageFile = File(
            imageDir,
            "${safeClipId}_${System.currentTimeMillis()}.$extension"
        )
        imageFile.writeBytes(imageBytes)
        cleanupOldClipboardImages(imageDir)

        val imageUri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            imageFile
        )

        val clipData = ClipData.newUri(contentResolver, "CopyPaws Image", imageUri)
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(clipData)

        Log.d("MainActivity", "Image copied to clipboard: $imageUri")
        return true
    }

    private fun resolveMimeType(explicitMimeType: String?, imageBytes: ByteArray): String {
        if (!explicitMimeType.isNullOrBlank() && explicitMimeType.startsWith("image/")) {
            return explicitMimeType
        }

        if (imageBytes.size >= 8 &&
            imageBytes[0] == 0x89.toByte() &&
            imageBytes[1] == 0x50.toByte() &&
            imageBytes[2] == 0x4E.toByte() &&
            imageBytes[3] == 0x47.toByte()
        ) {
            return "image/png"
        }

        if (imageBytes.size >= 3 &&
            imageBytes[0] == 0xFF.toByte() &&
            imageBytes[1] == 0xD8.toByte() &&
            imageBytes[2] == 0xFF.toByte()
        ) {
            return "image/jpeg"
        }

        if (imageBytes.size >= 6) {
            val header = String(imageBytes.copyOfRange(0, 6), Charsets.US_ASCII)
            if (header == "GIF87a" || header == "GIF89a") {
                return "image/gif"
            }
        }

        if (imageBytes.size >= 12) {
            val riff = String(imageBytes.copyOfRange(0, 4), Charsets.US_ASCII)
            val webp = String(imageBytes.copyOfRange(8, 12), Charsets.US_ASCII)
            if (riff == "RIFF" && webp == "WEBP") {
                return "image/webp"
            }
        }

        return "image/png"
    }

    private fun extensionForMimeType(mimeType: String): String {
        return when (mimeType.lowercase()) {
            "image/jpeg", "image/jpg" -> "jpg"
            "image/gif" -> "gif"
            "image/webp" -> "webp"
            else -> "png"
        }
    }

    private fun cleanupOldClipboardImages(imageDir: File) {
        val files = imageDir.listFiles()?.sortedByDescending { it.lastModified() } ?: return
        files.drop(20).forEach { staleFile ->
            if (!staleFile.delete()) {
                Log.w("MainActivity", "Failed to delete stale clipboard image: ${staleFile.path}")
            }
        }
    }
}
