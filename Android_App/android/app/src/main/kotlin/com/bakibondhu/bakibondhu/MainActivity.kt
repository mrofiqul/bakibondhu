package com.bakibondhu.bakibondhu

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

class MainActivity : FlutterActivity() {
    private val channel = "bakibondhu/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveToDownloads" -> {
                        val name = call.argument<String>("name")
                        val bytes = call.argument<ByteArray>("bytes")
                        val mime = call.argument<String>("mime")
                            ?: "application/octet-stream"
                        if (name == null || bytes == null) {
                            result.error("bad_args", "name and bytes are required", null)
                        } else {
                            try {
                                result.success(saveToDownloads(name, bytes, mime))
                            } catch (e: Exception) {
                                result.error("save_failed", e.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Saves [bytes] into the public Downloads folder and returns a display path.
     * API 29+ uses MediaStore (no permission needed); older devices throw so the
     * Dart side can fall back to the system "Save to…" picker.
     */
    private fun saveToDownloads(name: String, bytes: ByteArray, mime: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, name)
                put(MediaStore.Downloads.MIME_TYPE, mime)
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            }
            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IOException("Could not create the download entry")
            resolver.openOutputStream(uri).use { out ->
                (out ?: throw IOException("Could not open the download for writing"))
                    .write(bytes)
            }
            return "Downloads/$name"
        }
        // Pre-Android 10: this direct write needs legacy storage permission, which
        // the app doesn't request — signal failure so Dart falls back to the picker.
        throw IOException("legacy_unsupported")
    }
}
