package com.example.file_recovery

import android.content.ContentResolver
import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.atomic.AtomicBoolean

class ScannerPlugin(private val context: Context) {

    private val executor  = Executors.newSingleThreadExecutor()
    private var scanFuture: Future<*>? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val cancelled  = AtomicBoolean(false)

    /** Public EventChannel stream handler — registered in MainActivity. */
    val streamHandler = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            eventSink = events
        }
        override fun onCancel(arguments: Any?) {
            eventSink = null
        }
    }
    @Volatile private var eventSink: EventChannel.EventSink? = null

    // ─────────────────────────────────────────────────────────────────────────
    // Method dispatch
    // ─────────────────────────────────────────────────────────────────────────
    fun handleMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startScan" -> {
                val path = call.argument<String>("path") ?: ""
                startScan(path, result)
            }
            "stopScan"  -> stopScan(result)
            "isRooted"  -> result.success(checkRoot())
            else        -> result.notImplemented()
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Scan orchestration
    // ─────────────────────────────────────────────────────────────────────────
    private fun startScan(storagePath: String, result: MethodChannel.Result) {
        // Cancel any previous scan
        scanFuture?.cancel(true)
        cancelled.set(false)

        result.success(true)

        scanFuture = executor.submit {
            try {
                sendEvent("status",  "scanning")
                sendEvent("message", "Initializing scanner…")

                val found = mutableListOf<Map<String, Any?>>()

                // Strategy 1 – MediaStore Trash (most reliable, non-root)
                if (!cancelled.get()) {
                    sendEvent("message", "Scanning MediaStore Recycle Bin…")
                    val ms = scanMediaStoreTrash()
                    found.addAll(ms)
                    sendEvent("found_count", found.size)
                }

                // Strategy 2 – LOST.DIR
                if (!cancelled.get()) {
                    sendEvent("message", "Scanning LOST.DIR…")
                    found.addAll(scanLostDir(storagePath))
                    sendEvent("found_count", found.size)
                }

                // Strategy 3 – Trash / hidden folders
                if (!cancelled.get()) {
                    sendEvent("message", "Scanning trash folders…")
                    found.addAll(scanTrashFolders(storagePath))
                    sendEvent("found_count", found.size)
                }

                // Strategy 4 – File carving on accessible paths
                if (!cancelled.get()) {
                    sendEvent("message", "Deep scanning for file signatures…")
                    found.addAll(performFileCarving(storagePath, found))
                    sendEvent("found_count", found.size)
                }

                // Strategy 5 – Root scan (block device carving)
                if (!cancelled.get() && checkRoot()) {
                    sendEvent("message", "Root detected — performing block-level scan…")
                    found.addAll(scanWithRoot(storagePath))
                    sendEvent("found_count", found.size)
                }

                sendEvent("status",  "done")
                sendEvent("results", found)

            } catch (e: InterruptedException) {
                sendEvent("status", "cancelled")
            } catch (e: Exception) {
                sendEvent("status", "error")
                sendEvent("error",  e.message ?: "Unknown error during scan")
            }
        }
    }

    private fun stopScan(result: MethodChannel.Result) {
        cancelled.set(true)
        scanFuture?.cancel(true)
        result.success(true)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Strategy 1 – MediaStore Trash (IS_TRASHED=1), API 29+
    // ─────────────────────────────────────────────────────────────────────────
    private fun scanMediaStoreTrash(): List<Map<String, Any?>> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return emptyList()

        val results = mutableListOf<Map<String, Any?>>()

        val uris = listOf(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)
        )

        val projection = buildList {
            add(MediaStore.MediaColumns._ID)
            add(MediaStore.MediaColumns.DISPLAY_NAME)
            add(MediaStore.MediaColumns.DATA)
            add(MediaStore.MediaColumns.SIZE)
            add(MediaStore.MediaColumns.DATE_MODIFIED)
            add(MediaStore.MediaColumns.MIME_TYPE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                add(MediaStore.MediaColumns.DATE_EXPIRES)
                add(MediaStore.MediaColumns.RELATIVE_PATH)
            }
        }.toTypedArray()

        for (baseUri in uris) {
            if (cancelled.get()) break
            try {
                val cursor: Cursor? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    val bundle = android.os.Bundle().apply {
                        putString(ContentResolver.QUERY_ARG_SQL_SELECTION,
                            "${MediaStore.MediaColumns.IS_TRASHED} = 1")
                        putStringArray(ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS, emptyArray())
                        putInt(MediaStore.QUERY_ARG_MATCH_TRASHED, MediaStore.MATCH_INCLUDE)
                    }
                    context.contentResolver.query(baseUri, projection, bundle, null)
                } else {
                    context.contentResolver.query(
                        baseUri, projection,
                        "${MediaStore.MediaColumns.IS_TRASHED} = 1",
                        null, null
                    )
                }

                cursor?.use { c ->
                    while (c.moveToNext() && !cancelled.get()) {
                        val row = cursorToMap(c, baseUri, "mediastore_trash", 95)
                        if (row != null) results.add(row)
                    }
                }
            } catch (_: Exception) {}
        }
        return results
    }

    private fun cursorToMap(c: Cursor, uri: Uri, source: String, confidence: Int): Map<String, Any?>? {
        return try {
            val id      = c.getLong(c.getColumnIndexOrThrow(MediaStore.MediaColumns._ID))
            val name    = c.getString(c.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME)) ?: return null
            val data    = safeGetString(c, MediaStore.MediaColumns.DATA)
            val size    = safeGetLong(c, MediaStore.MediaColumns.SIZE)
            val modified= safeGetLong(c, MediaStore.MediaColumns.DATE_MODIFIED)
            val mime    = safeGetString(c, MediaStore.MediaColumns.MIME_TYPE) ?: ""
            val expires = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R)
                safeGetLong(c, MediaStore.MediaColumns.DATE_EXPIRES) else 0L

            mapOf(
                "id"             to "ms_$id",
                "name"           to name,
                "path"           to (data ?: ""),
                "size"           to size,
                "modifiedDate"   to (modified * 1000),
                "expiresDate"    to (expires * 1000),
                "mimeType"       to mime,
                "fileType"       to mimeToFileType(mime),
                "recoverySource" to source,
                "confidence"     to confidence,
                "contentUri"     to "$uri/$id",
                "isRecoverable"  to true
            )
        } catch (_: Exception) { null }
    }

    private fun safeGetString(c: Cursor, col: String): String? =
        try { c.getString(c.getColumnIndexOrThrow(col)) } catch (_: Exception) { null }

    private fun safeGetLong(c: Cursor, col: String): Long =
        try { c.getLong(c.getColumnIndexOrThrow(col)) } catch (_: Exception) { 0L }

    // ─────────────────────────────────────────────────────────────────────────
    // Strategy 2 – LOST.DIR
    // ─────────────────────────────────────────────────────────────────────────
    private fun scanLostDir(storagePath: String): List<Map<String, Any?>> {
        val results = mutableListOf<Map<String, Any?>>()
        val dir = File("$storagePath/LOST.DIR")
        if (dir.exists() && dir.isDirectory) scanDir(dir, results, "lost_dir", 85)
        return results
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Strategy 3 – Trash & hidden folders
    // ─────────────────────────────────────────────────────────────────────────
    private fun scanTrashFolders(storagePath: String): List<Map<String, Any?>> {
        val results = mutableListOf<Map<String, Any?>>()
        val candidates = listOf(
            "$storagePath/.Trash",
            "$storagePath/.trash",
            "$storagePath/.Trashes",
            "$storagePath/.RecycleBin",
            "$storagePath/.thumbnails",
            "$storagePath/Android/.nomedia"
        )
        for (p in candidates) {
            if (cancelled.get()) break
            val d = File(p)
            if (d.exists() && d.isDirectory) scanDir(d, results, "trash_folder", 78)
        }
        return results
    }

    private fun scanDir(
        dir: File,
        results: MutableList<Map<String, Any?>>,
        source: String,
        confidence: Int
    ) {
        try {
            for (file in dir.walkTopDown().maxDepth(6)) {
                if (cancelled.get()) break
                if (!file.isDirectory && file.length() > 0) {
                    val detectedMime = extensionToMime(file.extension)
                    val fileType = mimeToFileType(detectedMime)
                    if (fileType != "other") {
                        results.add(buildFileMap(file, source, confidence, detectedMime))
                        sendEvent("current_path", file.absolutePath)
                    }
                }
            }
        } catch (_: SecurityException) {}
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Strategy 4 – File carving (signature detection on existing files)
    // ─────────────────────────────────────────────────────────────────────────
    private fun performFileCarving(
        storagePath: String,
        existing: List<Map<String, Any?>>
    ): List<Map<String, Any?>> {
        val results = mutableListOf<Map<String, Any?>>()
        val knownPaths = existing.mapNotNull { it["path"] as? String }.toHashSet()

        val searchRoots = listOf(
            storagePath,
            "$storagePath/Android/data",
            "$storagePath/Android/media",
            context.cacheDir.absolutePath
        )

        for (root in searchRoots) {
            if (cancelled.get()) break
            val dir = File(root)
            if (!dir.exists()) continue
            try {
                for (file in dir.walkTopDown().maxDepth(4)) {
                    if (cancelled.get()) break
                    if (!file.isDirectory && file.length() > 128 && file.absolutePath !in knownPaths) {
                        val detected = FileSignatures.detect(file) ?: continue
                        val (mime, ext, conf) = detected
                        if (mimeToFileType(mime) != "other") {
                            val renamedName = if (file.extension.lowercase() == ext) file.name
                                             else "${file.nameWithoutExtension}.$ext"
                            results.add(buildFileMap(file, "file_carving", conf, mime, renamedName))
                            sendEvent("current_path", file.absolutePath)
                        }
                    }
                }
            } catch (_: SecurityException) {}
        }
        return results
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Strategy 5 – Root block-device carving
    // ─────────────────────────────────────────────────────────────────────────
    private fun scanWithRoot(storagePath: String): List<Map<String, Any?>> {
        val results = mutableListOf<Map<String, Any?>>()
        try {
            val stagingDir = File(context.cacheDir, "root_carved").also { it.mkdirs() }
            val devices = listBlockDevices(storagePath)
            for (device in devices) {
                if (cancelled.get()) break
                sendEvent("message", "Carving block device: $device")
                results.addAll(carveBlockDevice(device, stagingDir))
                sendEvent("found_count", results.size)
            }
        } catch (_: Exception) {}
        return results
    }

    private fun listBlockDevices(storagePath: String): List<String> {
        return try {
            val proc = Runtime.getRuntime().exec(arrayOf("su", "-c", "blkid"))
            val out = proc.inputStream.bufferedReader().readText()
            proc.waitFor()
            out.lines()
                .filter { it.contains("/dev/block/") }
                .mapNotNull { Regex("/dev/block/[\\w/]+").find(it)?.value }
                .distinct()
        } catch (_: Exception) { emptyList() }
    }

    private fun carveBlockDevice(devicePath: String, outputDir: File): List<Map<String, Any?>> {
        val results = mutableListOf<Map<String, Any?>>()
        try {
            // Read first 100 MB in 512-byte sectors (safety limit)
            val sectorSize = 512
            val maxSectors = 204800
            val proc = Runtime.getRuntime().exec(
                arrayOf("su", "-c", "dd if=$devicePath bs=$sectorSize count=$maxSectors")
            )
            val bytes = proc.inputStream.readBytes()
            proc.waitFor()

            var offset = 0
            while (offset < bytes.size - 16) {
                if (cancelled.get()) break
                for (sig in FileSignatures.ALL) {
                    if (sig.matchesAt(bytes, offset)) {
                        val endOffset = findCarveEnd(bytes, offset, sig)
                        val chunkSize = endOffset - offset
                        if (chunkSize > 256) {
                            val chunk   = bytes.copyOfRange(offset, minOf(endOffset, bytes.size))
                            val outFile = File(outputDir, "blk_${offset}.${sig.extension}")
                            outFile.writeBytes(chunk)
                            results.add(buildFileMap(outFile, "raw_block_scan", 72, sig.mimeType))
                        }
                    }
                }
                offset += sectorSize
            }
        } catch (_: Exception) {}
        return results
    }

    private fun findCarveEnd(bytes: ByteArray, start: Int, sig: FileSignature): Int {
        val limit = minOf(start + sig.maxSize, bytes.size)
        if (sig.endMagic != null) {
            var i = start
            while (i < limit - sig.endMagic.size) {
                if (sig.endMatchesAt(bytes, i)) return i + sig.endMagic.size
                i++
            }
        }
        return limit
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────
    private fun buildFileMap(
        file: File,
        source: String,
        confidence: Int,
        mime: String,
        displayName: String = file.name
    ): Map<String, Any?> = mapOf(
        "id"             to "${source}_${file.absolutePath.hashCode()}",
        "name"           to displayName,
        "path"           to file.absolutePath,
        "size"           to file.length(),
        "modifiedDate"   to file.lastModified(),
        "expiresDate"    to 0L,
        "mimeType"       to mime,
        "fileType"       to mimeToFileType(mime),
        "recoverySource" to source,
        "confidence"     to confidence,
        "contentUri"     to "file://${file.absolutePath}",
        "isRecoverable"  to true
    )

    private fun mimeToFileType(mime: String): String = when {
        mime.startsWith("image/")      -> "image"
        mime.startsWith("video/")      -> "video"
        mime.startsWith("audio/")      -> "audio"
        mime.contains("pdf")           -> "document"
        mime.contains("word") || mime.contains("msword")  -> "document"
        mime.contains("excel") || mime.contains("sheet")  -> "document"
        mime.contains("text/")         -> "document"
        mime.contains("zip") || mime.contains("archive") -> "archive"
        else                            -> "other"
    }

    private fun extensionToMime(ext: String): String = when (ext.lowercase()) {
        "jpg", "jpeg" -> "image/jpeg"
        "png"         -> "image/png"
        "gif"         -> "image/gif"
        "webp"        -> "image/webp"
        "bmp"         -> "image/bmp"
        "heic"        -> "image/heic"
        "mp4", "m4v"  -> "video/mp4"
        "avi"         -> "video/x-msvideo"
        "mkv"         -> "video/x-matroska"
        "mov"         -> "video/quicktime"
        "3gp"         -> "video/3gpp"
        "mp3"         -> "audio/mpeg"
        "wav"         -> "audio/wav"
        "aac"         -> "audio/aac"
        "ogg"         -> "audio/ogg"
        "flac"        -> "audio/flac"
        "m4a"         -> "audio/mp4"
        "pdf"         -> "application/pdf"
        "doc", "docx" -> "application/msword"
        "zip"         -> "application/zip"
        "db"          -> "application/x-sqlite3"
        else          -> "application/octet-stream"
    }

    private fun checkRoot(): Boolean = try {
        val proc = Runtime.getRuntime().exec(arrayOf("su", "-c", "id"))
        val out  = proc.inputStream.bufferedReader().readLine() ?: ""
        proc.waitFor()
        out.contains("uid=0")
    } catch (_: Exception) { false }

    private fun sendEvent(key: String, value: Any?) {
        mainHandler.post {
            try { eventSink?.success(mapOf("key" to key, "value" to value)) }
            catch (_: Exception) {}
        }
    }
}
