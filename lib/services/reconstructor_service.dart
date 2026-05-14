import 'package:flutter/services.dart';

class ReconstructorService {
  static const _channel =
      MethodChannel('com.example.file_recovery/reconstructor');

  /// Copy a file from [filePath] to the default recovery directory.
  /// Returns the new path of the recovered file.
  Future<String?> recoverFile({
    required String filePath,
    required String fileName,
    required String mimeType,
    String? destPath,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'recoverFile',
        {
          'filePath': filePath,
          'fileName': fileName,
          'mimeType': mimeType,
          if (destPath != null) 'destPath': destPath,
        },
      );
      return result?['recoveredPath'] as String?;
    } on PlatformException catch (e) {
      throw Exception('Recovery failed: ${e.message}');
    }
  }

  /// Recover a file from a content:// URI (MediaStore trash).
  Future<String?> recoverFromUri({
    required String uri,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'recoverFromUri',
        {'uri': uri, 'fileName': fileName, 'mimeType': mimeType},
      );
      return result?['recoveredPath'] as String?;
    } on PlatformException catch (e) {
      throw Exception('Recovery from URI failed: ${e.message}');
    }
  }

  /// Copy a file to a private staging directory for preview.
  Future<String?> stageForPreview(String sourcePath) async {
    try {
      return await _channel.invokeMethod<String>(
        'stageForPreview',
        {'sourcePath': sourcePath},
      );
    } on PlatformException catch (e) {
      throw Exception('Staging failed: ${e.message}');
    }
  }

  /// Stage a content:// URI for preview.
  Future<String?> stageUriForPreview(String uri, String fileName) async {
    try {
      return await _channel.invokeMethod<String>(
        'stageUriForPreview',
        {'uri': uri, 'fileName': fileName},
      );
    } on PlatformException catch (e) {
      throw Exception('URI staging failed: ${e.message}');
    }
  }
}
