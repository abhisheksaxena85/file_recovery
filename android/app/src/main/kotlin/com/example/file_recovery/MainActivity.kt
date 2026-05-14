package com.example.file_recovery

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private companion object {
        const val STORAGE_CHANNEL     = "com.example.file_recovery/storage"
        const val SCANNER_CHANNEL     = "com.example.file_recovery/scanner"
        const val SCANNER_EVENTS      = "com.example.file_recovery/scanner_events"
        const val RECONSTRUCTOR_CHANNEL = "com.example.file_recovery/reconstructor"
        const val EXPORT_CHANNEL      = "com.example.file_recovery/export"
    }

    private lateinit var storagePlugin: StoragePlugin
    private lateinit var scannerPlugin: ScannerPlugin
    private lateinit var reconstructorPlugin: ReconstructorPlugin
    private lateinit var exportPlugin: ExportPlugin

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        storagePlugin      = StoragePlugin(this)
        scannerPlugin      = ScannerPlugin(this)
        reconstructorPlugin = ReconstructorPlugin(this)
        exportPlugin       = ExportPlugin(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL)
            .setMethodCallHandler { call, result -> storagePlugin.handle(call, result) }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCANNER_CHANNEL)
            .setMethodCallHandler { call, result -> scannerPlugin.handleMethod(call, result) }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SCANNER_EVENTS)
            .setStreamHandler(scannerPlugin.streamHandler)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RECONSTRUCTOR_CHANNEL)
            .setMethodCallHandler { call, result -> reconstructorPlugin.handle(call, result) }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EXPORT_CHANNEL)
            .setMethodCallHandler { call, result -> exportPlugin.handle(call, result) }
    }
}
