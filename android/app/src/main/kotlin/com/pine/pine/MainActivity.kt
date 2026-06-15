package com.pine.pine

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val downloadChannel = "com.pine.pine/public_download"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, downloadChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveZipToDownloads" -> {
                        val fileName = call.argument<String>("fileName")
                        val bytes = call.argument<ByteArray>("bytes")
                        if (fileName.isNullOrBlank() || bytes == null) {
                            result.error("ARG", "fileName and bytes are required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val saved =
                                PublicDownloadSaver.saveZip(
                                    applicationContext,
                                    fileName,
                                    bytes,
                                )
                            result.success(saved)
                        } catch (e: Exception) {
                            result.error(
                                "SAVE_FAILED",
                                e.message ?: "Could not save to Downloads",
                                null,
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
