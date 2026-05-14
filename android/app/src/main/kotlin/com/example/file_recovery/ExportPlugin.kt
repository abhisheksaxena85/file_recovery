package com.example.file_recovery

import android.content.Context
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.concurrent.Executors

class ExportPlugin(private val context: Context) {

    private val executor = Executors.newSingleThreadExecutor()

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "exportFile" -> {
                val sourcePath = call.argument<String>("sourcePath") ?: ""
                val destUri    = call.argument<String>("destUri")
                executor.submit { exportFile(sourcePath, destUri, result) }
            }
            "getShareUri" -> {
                val filePath = call.argument<String>("filePath") ?: ""
                getShareUri(filePath, result)
            }
            "copyToUri" -> {
                val sourcePath = call.argument<String>("sourcePath") ?: ""
                val destUri    = call.argument<String>("destUri")    ?: ""
                executor.submit { copyToUri(sourcePath, destUri, result) }
            }
            else -> result.notImplemented()
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Export file to a SAF-picked tree / document URI
    // ─────────────────────────────────────────────────────────────────────────
    private fun exportFile(sourcePath: String, destUri: String?, result: MethodChannel.Result) {
        try {
            val src = File(sourcePath)
            if (!src.exists()) { result.error("NOT_FOUND", "Source not found: $sourcePath", null); return }

            if (destUri != null) {
                copyToUri(sourcePath, destUri, result)
            } else {
                result.error("NO_DEST", "No destination URI provided", null)
            }
        } catch (e: Exception) {
            result.error("EXPORT_ERROR", e.message, null)
        }
    }

    private fun copyToUri(sourcePath: String, destUriStr: String, result: MethodChannel.Result) {
        try {
            val src = File(sourcePath)
            val uri = Uri.parse(destUriStr)
            context.contentResolver.openOutputStream(uri)?.use { out ->
                FileInputStream(src).use { input -> input.copyTo(out, 8192) }
            } ?: run { result.error("STREAM_ERROR", "Cannot open output stream", null); return }
            result.success(mapOf("success" to true, "dest" to destUriStr))
        } catch (e: Exception) {
            result.error("COPY_ERROR", e.message, null)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Get a shareable FileProvider URI for a file
    // ─────────────────────────────────────────────────────────────────────────
    private fun getShareUri(filePath: String, result: MethodChannel.Result) {
        try {
            val file = File(filePath)
            val uri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
            } else {
                Uri.fromFile(file)
            }
            result.success(uri.toString())
        } catch (e: Exception) {
            result.error("URI_ERROR", e.message, null)
        }
    }
}
