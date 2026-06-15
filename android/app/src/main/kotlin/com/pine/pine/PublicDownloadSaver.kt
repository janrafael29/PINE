package com.pine.pine

import android.content.ContentValues
import android.content.Context
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import java.io.IOException

object PublicDownloadSaver {
    @Throws(IOException::class)
    fun saveZip(context: Context, fileName: String, bytes: ByteArray): String {
        val safeName = sanitizeFileName(fileName)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return saveViaMediaStore(context, safeName, bytes)
        }
        return saveViaLegacyPublicDir(context, safeName, bytes)
    }

    private fun saveViaMediaStore(
        context: Context,
        fileName: String,
        bytes: ByteArray,
    ): String {
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, "application/zip")
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val uri =
            resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IOException("MediaStore insert failed")
        try {
            resolver.openOutputStream(uri)?.use { stream ->
                stream.write(bytes)
                stream.flush()
            } ?: throw IOException("Could not open output stream")
            val published = ContentValues().apply {
                put(MediaStore.Downloads.IS_PENDING, 0)
            }
            resolver.update(uri, published, null, null)
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw if (e is IOException) e else IOException(e.message ?: "Save failed", e)
        }
        return "${Environment.DIRECTORY_DOWNLOADS}/$fileName"
    }

    @Suppress("DEPRECATION")
    private fun saveViaLegacyPublicDir(
        context: Context,
        fileName: String,
        bytes: ByteArray,
    ): String {
        val dir =
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (!dir.exists() && !dir.mkdirs()) {
            throw IOException("Downloads folder unavailable")
        }
        val out = File(dir, fileName)
        out.writeBytes(bytes)
        MediaScannerConnection.scanFile(
            context,
            arrayOf(out.absolutePath),
            arrayOf("application/zip"),
            null,
        )
        return out.absolutePath
    }

    private fun sanitizeFileName(fileName: String): String {
        val safe =
            File(fileName).name
                .replace(Regex("[\\\\/:*?\"<>|\\p{Cntrl}]"), "_")
                .trim()
        if (safe.isBlank() || safe == "." || safe == "..") {
            return "pine-export.zip"
        }
        return if (safe.endsWith(".zip", ignoreCase = true)) safe else "$safe.zip"
    }
}
