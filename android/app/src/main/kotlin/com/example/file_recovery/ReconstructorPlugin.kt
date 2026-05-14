package com.example.file_recovery

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.concurrent.Executors

class ReconstructorPlugin(private val context: Context) {

    private val executor = Executors.newSingleThreadExecutor()

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "recoverFile"          -> {
                val filePath  = call.argument<String>("filePath")  ?: ""
                val fileName  = call.argument<String>("fileName")  ?: ""
                val mimeType  = call.argument<String>("mimeType")  ?: ""
                val destPath  = call.argument<String>("destPath")
                executor.submit { recoverFile(filePath, fileName, mimeType, destPath, result) }
            }
            "recoverFromUri"       -> {
                val uriStr    = call.argument<String>("uri")       ?: ""
                val fileName  = call.argument<String>("fileName")  ?: ""
                val mimeType  = call.argument<String>("mimeType")  ?: ""
                executor.submit { recoverFromUri(uriStr, fileName, mimeType, result) }
            }
            "stageForPreview"      -> {
                val sourcePath = call.argument<String>("sourcePath") ?: ""
                executor.submit { stageForPreview(sourcePath, result) }
            }
            "stageUriForPreview"   -> {
                val uriStr    = call.argument<String>("uri")       ?: ""
                val fileName  = call.argument<String>("fileName")  ?: ""
                executor.submit { stageUriForPreview(uriStr, fileName, result) }
            }
            else -> result.notImplemented()
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Recover a file from a filesystem path
    // ─────────────────────────────────────────────────────────────────────────
    private fun recoverFile(
        filePath: String,
        fileName: String,
        mimeType: String,
        destPath: String?,
        result: MethodChannel.Result
    ) {
        try {
            val src = File(filePath)
            if (!src.exists()) {
                result.error("NOT_FOUND", "Source file not found: $filePath", null)
                return
            }
            val destDir = if (destPath != null) File(destPath) else defaultDir(mimeType)
            destDir.mkdirs()
            val dest = File(destDir, unique(destDir, fileName))
            copy(src, dest)
            addToMediaStore(dest, mimeType)
            result.success(mapOf("success" to true, "recoveredPath" to dest.absolutePath))
        } catch (e: Exception) {
            result.error("RECOVERY_ERROR", e.message, null)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Recover a file from a content:// URI (MediaStore trash)
    // ─────────────────────────────────────────────────────────────────────────
    private fun recoverFromUri(
        uriStr: String,
        fileName: String,
        mimeType: String,
        result: MethodChannel.Result
    ) {
        try {
            val uri     = Uri.parse(uriStr)
            val destDir = defaultDir(mimeType).also { it.mkdirs() }
            val dest    = File(destDir, unique(destDir, fileName))

            context.contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(dest).use { output -> input.copyTo(output, 8192) }
            } ?: run {
                result.error("STREAM_ERROR", "Cannot open InputStream for URI: $uriStr", null)
                return
            }

            addToMediaStore(dest, mimeType)
            result.success(mapOf("success" to true, "recoveredPath" to dest.absolutePath))
        } catch (e: Exception) {
            result.error("RECOVERY_ERROR", e.message, null)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Stage a file into the app-private cache for preview (read-only display)
    // ─────────────────────────────────────────────────────────────────────────
    private fun stageForPreview(sourcePath: String, result: MethodChannel.Result) {
        try {
            val src = File(sourcePath)
            if (!src.exists()) { result.error("NOT_FOUND", "File not found", null); return }
            val staged = File(previewDir(), src.name)
            copy(src, staged)
            result.success(staged.absolutePath)
        } catch (e: Exception) {
            result.error("STAGE_ERROR", e.message, null)
        }
    }

    private fun stageUriForPreview(uriStr: String, fileName: String, result: MethodChannel.Result) {
        try {
            val uri = Uri.parse(uriStr)
            val staged = File(previewDir(), fileName)
            context.contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(staged).use { output -> input.copyTo(output, 8192) }
            } ?: run { result.error("STREAM_ERROR", "Cannot open URI stream", null); return }
            result.success(staged.absolutePath)
        } catch (e: Exception) {
            result.error("STAGE_ERROR", e.message, null)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Utilities
    // ─────────────────────────────────────────────────────────────────────────
    private fun copy(src: File, dest: File) {
        FileInputStream(src).use { i -> FileOutputStream(dest).use { o -> i.copyTo(o, 8192) } }
    }

    private fun previewDir(): File =
        File(context.cacheDir, "preview_staging").also { it.mkdirs() }

    private fun defaultDir(mimeType: String): File {
        val base = context.getExternalFilesDir(null) ?: context.filesDir
        val sub  = when {
            mimeType.startsWith("image/") -> "Recovered/Images"
            mimeType.startsWith("video/") -> "Recovered/Videos"
            mimeType.startsWith("audio/") -> "Recovered/Audio"
            else                          -> "Recovered/Documents"
        }
        return File(base, sub)
    }

    private fun unique(dir: File, name: String): String {
        val base = name.substringBeforeLast(".")
        val ext  = name.substringAfterLast(".", "")
        var candidate = name
        var n = 1
        while (File(dir, candidate).exists()) {
            candidate = "${base}_$n${if (ext.isNotEmpty()) ".$ext" else ""}"
            n++
        }
        return candidate
    }

    private fun addToMediaStore(file: File, mimeType: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        try {
            val uri = when {
                mimeType.startsWith("image/") -> MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                mimeType.startsWith("video/") -> MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                mimeType.startsWith("audio/") -> MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
                else -> return
            }
            val cv = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, file.name)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.DATE_ADDED, System.currentTimeMillis() / 1000)
            }
            context.contentResolver.insert(uri, cv)
        } catch (_: Exception) {}
    }
}
