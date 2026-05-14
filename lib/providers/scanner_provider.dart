import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/recovered_file.dart';
import '../models/scan_progress.dart';
import '../services/scanner_service.dart';

class ScannerProvider extends ChangeNotifier {
  final _service = ScannerService();

  ScanProgress _progress = const ScanProgress();
  List<RecoveredFile> _results = [];
  StreamSubscription? _subscription;
  bool _isRooted = false;

  ScanProgress        get progress => _progress;
  List<RecoveredFile> get results  => _results;
  bool                get isRooted => _isRooted;
  bool                get isActive => _progress.isActive;

  Future<void> checkRoot() async {
    _isRooted = await _service.isRooted();
    notifyListeners();
  }

  Future<void> startScan(String storagePath) async {
    // Cancel any previous scan subscription
    await _subscription?.cancel();
    _results = [];
    _progress = ScanProgress(
      status:    ScanStatus.scanning,
      startTime: DateTime.now(),
      message:   'Starting scan…',
    );
    notifyListeners();

    _subscription = _service.eventStream.listen(
      _handleEvent,
      onError: (e) {
        _progress = _progress.copyWith(
          status: ScanStatus.error,
          errorMessage: e.toString(),
        );
        notifyListeners();
      },
    );

    await _service.startScan(storagePath);
  }

  Future<void> stopScan() async {
    await _service.stopScan();
    _progress = _progress.copyWith(status: ScanStatus.cancelled);
    notifyListeners();
  }

  void _handleEvent(Map<String, dynamic> event) {
    final key   = event['key'] as String? ?? '';
    final value = event['value'];

    switch (key) {
      case 'status':
        final s = _statusFromString(value as String? ?? '');
        _progress = _progress.copyWith(status: s);

      case 'message':
        _progress = _progress.copyWith(message: value as String? ?? '');

      case 'current_path':
        _progress = _progress.copyWith(currentPath: value as String? ?? '');

      case 'found_count':
        _progress = _progress.copyWith(filesFound: (value as num?)?.toInt() ?? 0);

      case 'results':
        if (value is List) {
          _results = value
              .whereType<Map<Object?, Object?>>()
              .map(RecoveredFile.fromMap)
              .toList();
          _results.sort((a, b) => b.confidence.compareTo(a.confidence));
          _progress = _progress.copyWith(filesFound: _results.length);
        }

      case 'error':
        _progress = _progress.copyWith(
          status: ScanStatus.error,
          errorMessage: value as String? ?? 'Unknown error',
        );
    }

    notifyListeners();
  }

  ScanStatus _statusFromString(String s) => switch (s) {
    'scanning'  => ScanStatus.scanning,
    'carving'   => ScanStatus.carving,
    'done'      => ScanStatus.done,
    'error'     => ScanStatus.error,
    'cancelled' => ScanStatus.cancelled,
    _           => ScanStatus.idle,
  };

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
