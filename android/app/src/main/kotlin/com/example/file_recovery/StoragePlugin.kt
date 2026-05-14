package com.example.file_recovery

import android.content.Context
import android.os.Build
import android.os.Environment
import android.os.storage.StorageManager
import android.os.storage.StorageVolume
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class StoragePlugin(private val context: Context) {

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getStorageVolumes" -> getStorageVolumes(result)
            else -> result.notImplemented()
        }
    }

    private fun getStorageVolumes(result: MethodChannel.Result) {
        try {
            val storageManager = context.getSystemService(Context.STORAGE_SERVICE) as StorageManager
            val volumes: List<StorageVolume> = storageManager.storageVolumes

            val volumeList = mutableListOf<Map<String, Any?>>()
            var index = 0

            for (volume in volumes) {
                val path: String? = resolveVolumePath(volume)
                if (path == null) {
                    index++
                    continue
                }

                val dir = File(path)
                val totalBytes = dir.totalSpace
                val freeBytes  = dir.freeSpace
                val usedBytes  = totalBytes - freeBytes

                val state: String = try {
                    Environment.getExternalStorageState(dir)
                } catch (e: Exception) { "mounted" }

                volumeList.add(
                    mapOf(
                        "id"          to (getVolumeUuid(volume) ?: "vol_$index"),
                        "description" to (getVolumeDescription(volume) ?: (if (volume.isPrimary) "Internal Storage" else "External Storage")),
                        "path"        to path,
                        "isRemovable" to volume.isRemovable,
                        "isPrimary"   to volume.isPrimary,
                        "totalBytes"  to totalBytes,
                        "freeBytes"   to freeBytes,
                        "usedBytes"   to usedBytes,
                        "state"       to state
                    )
                )
                index++
            }

            result.success(volumeList)
        } catch (e: Exception) {
            result.error("STORAGE_ERROR", e.message, null)
        }
    }

    private fun resolveVolumePath(volume: StorageVolume): String? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            volume.directory?.absolutePath
        } else {
            try {
                val method = StorageVolume::class.java.getMethod("getPath")
                method.invoke(volume) as? String
            } catch (e: Exception) {
                if (volume.isPrimary) Environment.getExternalStorageDirectory().absolutePath
                else null
            }
        }
    }

    private fun getVolumeUuid(volume: StorageVolume): String? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) volume.uuid
            else null
        } catch (e: Exception) { null }
    }

    private fun getVolumeDescription(volume: StorageVolume): String? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) volume.getDescription(context)
            else null
        } catch (e: Exception) { null }
    }
}
