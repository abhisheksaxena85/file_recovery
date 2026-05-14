package com.example.file_recovery

import java.io.File

/**
 * Represents a well-known binary file signature (magic bytes).
 *
 * @param name         Human-readable format name
 * @param magic        Byte sequence to match
 * @param headerOffset Byte offset within file where the magic bytes start (most are 0)
 * @param extension    Canonical file extension (without dot)
 * @param mimeType     Canonical MIME type
 * @param endMagic     Optional end-of-file trailer bytes (null = unknown / use maxSize)
 * @param maxSize      Maximum expected file size in bytes (used during block carving)
 */
data class FileSignature(
    val name: String,
    val magic: ByteArray,
    val headerOffset: Int = 0,
    val extension: String,
    val mimeType: String,
    val endMagic: ByteArray? = null,
    val maxSize: Int = 50 * 1024 * 1024
) {
    /** Returns true if [bytes] starting at [position]+[headerOffset] matches [magic]. */
    fun matchesAt(bytes: ByteArray, position: Int): Boolean {
        val start = position + headerOffset
        if (start < 0 || start + magic.size > bytes.size) return false
        for (i in magic.indices) {
            if (bytes[start + i] != magic[i]) return false
        }
        return true
    }

    /** Returns true if [bytes] at [position] matches [endMagic]. */
    fun endMatchesAt(bytes: ByteArray, position: Int): Boolean {
        val em = endMagic ?: return false
        if (position + em.size > bytes.size) return false
        for (i in em.indices) {
            if (bytes[position + i] != em[i]) return false
        }
        return true
    }

    override fun equals(other: Any?) = other is FileSignature && name == other.name
    override fun hashCode() = name.hashCode()
}

/** Central registry of all supported file signatures. */
object FileSignatures {

    private val b = { v: Int -> v.toByte() }

    val ALL: List<FileSignature> = listOf(
        // ── Images ──────────────────────────────────────────────────────────
        FileSignature(
            name = "JPEG", extension = "jpg", mimeType = "image/jpeg",
            magic = byteArrayOf(b(0xFF), b(0xD8), b(0xFF)),
            endMagic = byteArrayOf(b(0xFF), b(0xD9)),
            maxSize = 25 * 1024 * 1024
        ),
        FileSignature(
            name = "PNG", extension = "png", mimeType = "image/png",
            magic = byteArrayOf(b(0x89), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A),
            endMagic = byteArrayOf(0x49, 0x45, 0x4E, 0x44, b(0xAE), 0x42, 0x60, b(0x82)),
            maxSize = 25 * 1024 * 1024
        ),
        FileSignature(
            name = "GIF87a", extension = "gif", mimeType = "image/gif",
            magic = byteArrayOf(0x47, 0x49, 0x46, 0x38, 0x37, 0x61),
            endMagic = byteArrayOf(0x00, 0x3B),
            maxSize = 10 * 1024 * 1024
        ),
        FileSignature(
            name = "GIF89a", extension = "gif", mimeType = "image/gif",
            magic = byteArrayOf(0x47, 0x49, 0x46, 0x38, 0x39, 0x61),
            endMagic = byteArrayOf(0x00, 0x3B),
            maxSize = 10 * 1024 * 1024
        ),
        FileSignature(
            name = "BMP", extension = "bmp", mimeType = "image/bmp",
            magic = byteArrayOf(0x42, 0x4D),
            maxSize = 10 * 1024 * 1024
        ),
        FileSignature(
            name = "WEBP", extension = "webp", mimeType = "image/webp",
            magic = byteArrayOf(0x52, 0x49, 0x46, 0x46),  // "RIFF" — need secondary check
            maxSize = 15 * 1024 * 1024
        ),
        FileSignature(
            name = "HEIC", extension = "heic", mimeType = "image/heic",
            magic = byteArrayOf(0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63),
            maxSize = 25 * 1024 * 1024
        ),

        // ── Video ────────────────────────────────────────────────────────────
        FileSignature(
            name = "MP4/M4V", extension = "mp4", mimeType = "video/mp4",
            magic = byteArrayOf(0x66, 0x74, 0x79, 0x70),  // "ftyp"
            headerOffset = 4,
            maxSize = 500 * 1024 * 1024
        ),
        FileSignature(
            name = "AVI", extension = "avi", mimeType = "video/x-msvideo",
            magic = byteArrayOf(0x52, 0x49, 0x46, 0x46),  // "RIFF"
            maxSize = 500 * 1024 * 1024
        ),
        FileSignature(
            name = "MKV", extension = "mkv", mimeType = "video/x-matroska",
            magic = byteArrayOf(0x1A, 0x45, b(0xDF), b(0xA3)),
            maxSize = 500 * 1024 * 1024
        ),
        FileSignature(
            name = "MOV", extension = "mov", mimeType = "video/quicktime",
            magic = byteArrayOf(0x6D, 0x6F, 0x6F, 0x76),  // "moov"
            headerOffset = 4,
            maxSize = 500 * 1024 * 1024
        ),
        FileSignature(
            name = "3GP", extension = "3gp", mimeType = "video/3gpp",
            magic = byteArrayOf(0x66, 0x74, 0x79, 0x70, 0x33, 0x67, 0x70),
            headerOffset = 4,
            maxSize = 100 * 1024 * 1024
        ),

        // ── Audio ────────────────────────────────────────────────────────────
        FileSignature(
            name = "MP3/ID3", extension = "mp3", mimeType = "audio/mpeg",
            magic = byteArrayOf(0x49, 0x44, 0x33),  // "ID3"
            maxSize = 50 * 1024 * 1024
        ),
        FileSignature(
            name = "MP3/sync", extension = "mp3", mimeType = "audio/mpeg",
            magic = byteArrayOf(b(0xFF), b(0xFB)),
            maxSize = 50 * 1024 * 1024
        ),
        FileSignature(
            name = "WAV", extension = "wav", mimeType = "audio/wav",
            magic = byteArrayOf(0x52, 0x49, 0x46, 0x46),  // "RIFF"
            maxSize = 200 * 1024 * 1024
        ),
        FileSignature(
            name = "AAC", extension = "aac", mimeType = "audio/aac",
            magic = byteArrayOf(b(0xFF), b(0xF1)),
            maxSize = 50 * 1024 * 1024
        ),
        FileSignature(
            name = "FLAC", extension = "flac", mimeType = "audio/flac",
            magic = byteArrayOf(0x66, 0x4C, 0x61, 0x43),  // "fLaC"
            maxSize = 150 * 1024 * 1024
        ),
        FileSignature(
            name = "OGG", extension = "ogg", mimeType = "audio/ogg",
            magic = byteArrayOf(0x4F, 0x67, 0x67, 0x53),  // "OggS"
            maxSize = 100 * 1024 * 1024
        ),
        FileSignature(
            name = "M4A", extension = "m4a", mimeType = "audio/mp4",
            magic = byteArrayOf(0x66, 0x74, 0x79, 0x70, 0x4D, 0x34, 0x41),
            headerOffset = 4,
            maxSize = 80 * 1024 * 1024
        ),

        // ── Documents ────────────────────────────────────────────────────────
        FileSignature(
            name = "PDF", extension = "pdf", mimeType = "application/pdf",
            magic = byteArrayOf(0x25, 0x50, 0x44, 0x46),  // "%PDF"
            endMagic = byteArrayOf(0x25, 0x25, 0x45, 0x4F, 0x46),  // "%%EOF"
            maxSize = 50 * 1024 * 1024
        ),
        FileSignature(
            name = "ZIP/APK/DOCX", extension = "zip", mimeType = "application/zip",
            magic = byteArrayOf(0x50, 0x4B, 0x03, 0x04),  // "PK\x03\x04"
            maxSize = 200 * 1024 * 1024
        ),
        FileSignature(
            name = "DOC/XLS/PPT", extension = "doc", mimeType = "application/msword",
            magic = byteArrayOf(b(0xD0), b(0xCF), 0x11, b(0xE0), b(0xA1), b(0xB1), 0x1A, b(0xE1)),
            maxSize = 50 * 1024 * 1024
        ),
        FileSignature(
            name = "SQLITE", extension = "db", mimeType = "application/x-sqlite3",
            magic = byteArrayOf(0x53, 0x51, 0x4C, 0x69, 0x74, 0x65, 0x20, 0x66, 0x6F, 0x72, 0x6D, 0x61, 0x74, 0x20, 0x33, 0x00),
            maxSize = 200 * 1024 * 1024
        )
    )

    /**
     * Read up to 16 bytes from [file] and check against all known signatures.
     * Returns a Triple of (mimeType, extension, confidence) or null if no match.
     */
    fun detect(file: File): Triple<String, String, Int>? {
        return try {
            val header = ByteArray(minOf(16, file.length().toInt()))
            file.inputStream().use { it.read(header) }
            for (sig in ALL) {
                if (sig.matchesAt(header, 0)) {
                    return Triple(sig.mimeType, sig.extension, 82)
                }
            }
            null
        } catch (e: Exception) { null }
    }

    /** Find all matching signatures at a byte position (block carving). */
    fun matchesAt(bytes: ByteArray, pos: Int): List<FileSignature> =
        ALL.filter { it.matchesAt(bytes, pos) }
}
