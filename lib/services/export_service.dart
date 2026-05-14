import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {
  static const _channel = MethodChannel('com.example.file_recovery/export');

  /// Share a file via the system share sheet.
  Future<void> shareFile(String filePath, String mimeType, String name) async {
    try {
      await Share.shareXFiles(
        [XFile(filePath, mimeType: mimeType, name: name)],
        subject: 'Recovered file: $name',
      );
    } on PlatformException catch (e) {
      throw Exception('Share failed: ${e.message}');
    }
  }

  /// Copy a file to a SAF-picked destination URI.
  Future<bool> copyToUri(String sourcePath, String destUri) async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'copyToUri',
        {'sourcePath': sourcePath, 'destUri': destUri},
      );
      return result?['success'] as bool? ?? false;
    } on PlatformException catch (e) {
      throw Exception('Export failed: ${e.message}');
    }
  }

  /// Returns a content:// URI suitable for sharing the file via FileProvider.
  Future<String?> getShareUri(String filePath) async {
    try {
      return await _channel.invokeMethod<String>(
        'getShareUri',
        {'filePath': filePath},
      );
    } on PlatformException catch (e) {
      throw Exception('URI generation failed: ${e.message}');
    }
  }
}
