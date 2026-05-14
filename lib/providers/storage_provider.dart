import 'package:flutter/foundation.dart';
import '../models/storage_volume.dart';
import '../services/storage_service.dart';

class StorageProvider extends ChangeNotifier {
  final _service = StorageService();

  List<StorageVolume> _volumes = [];
  StorageVolume? _selected;
  bool _loading = false;
  String? _error;

  List<StorageVolume> get volumes  => _volumes;
  StorageVolume?       get selected => _selected;
  bool                 get loading  => _loading;
  String?              get error    => _error;

  Future<void> loadVolumes() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _volumes = await _service.getStorageVolumes();
      // Auto-select primary if only one volume
      if (_volumes.length == 1) _selected = _volumes.first;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void selectVolume(StorageVolume volume) {
    _selected = volume;
    notifyListeners();
  }
}
