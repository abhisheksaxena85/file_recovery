import 'package:flutter/services.dart';
import '../models/storage_volume.dart';

class StorageService {
  static const _channel = MethodChannel('com.example.file_recovery/storage');

  Future<List<StorageVolume>> getStorageVolumes() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getStorageVolumes');
      if (result == null) return [];
      return result
          .whereType<Map<Object?, Object?>>()
          .map(StorageVolume.fromMap)
          .toList();
    } on PlatformException catch (e) {
      throw Exception('Failed to get storage volumes: ${e.message}');
    }
  }
}
