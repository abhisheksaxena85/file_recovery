import 'dart:async';
import 'package:flutter/services.dart';
import '../models/recovered_file.dart';
import '../models/scan_progress.dart';

class ScannerService {
  static const _method = MethodChannel('com.example.file_recovery/scanner');
  static const _events = EventChannel('com.example.file_recovery/scanner_events');

  Stream<Map<String, dynamic>>? _rawStream;

  Stream<Map<String, dynamic>> get eventStream {
    _rawStream ??= _events
        .receiveBroadcastStream()
        .map((e) => Map<String, dynamic>.from(e as Map));
    return _rawStream!;
  }

  Future<bool> isRooted() async {
    try {
      return await _method.invokeMethod<bool>('isRooted') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> startScan(String storagePath) async {
    await _method.invokeMethod('startScan', {'path': storagePath});
  }

  Future<void> stopScan() async {
    await _method.invokeMethod('stopScan');
  }
}
