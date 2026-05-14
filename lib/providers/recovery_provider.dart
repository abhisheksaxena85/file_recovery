import 'package:flutter/foundation.dart';
import '../models/recovered_file.dart';
import '../services/reconstructor_service.dart';
import '../services/export_service.dart';

enum RecoveryStatus { idle, recovering, done, error }

class RecoveryProvider extends ChangeNotifier {
  final _reconstructor = ReconstructorService();
  final _export        = ExportService();

  final Map<String, RecoveryStatus> _status = {};
  final Set<String> _recovering = {};
  String? _lastError;
  String? _lastRecoveredPath;

  RecoveryStatus statusOf(String fileId) =>
      _status[fileId] ?? RecoveryStatus.idle;

  bool isRecovering(String fileId) => _recovering.contains(fileId);
  String? get lastError         => _lastError;
  String? get lastRecoveredPath => _lastRecoveredPath;

  Future<String?> recoverFile(RecoveredFile file) async {
    if (_recovering.contains(file.id)) return null;
    _recovering.add(file.id);
    _status[file.id] = RecoveryStatus.recovering;
    _lastError = null;
    notifyListeners();

    try {
      String? path;
      final isContentUri = file.contentUri.startsWith('content://');

      if (isContentUri) {
        path = await _reconstructor.recoverFromUri(
          uri:      file.contentUri,
          fileName: file.name,
          mimeType: file.mimeType,
        );
      } else {
        path = await _reconstructor.recoverFile(
          filePath: file.path,
          fileName: file.name,
          mimeType: file.mimeType,
        );
      }

      file.isRecovered   = true;
      file.recoveredPath = path;
      _status[file.id]   = RecoveryStatus.done;
      _lastRecoveredPath = path;
      notifyListeners();
      return path;
    } catch (e) {
      _lastError       = e.toString();
      _status[file.id] = RecoveryStatus.error;
      notifyListeners();
      return null;
    } finally {
      _recovering.remove(file.id);
      notifyListeners();
    }
  }

  Future<void> recoverAll(List<RecoveredFile> files) async {
    for (final f in files) {
      if (f.isRecoverable && !f.isRecovered) {
        await recoverFile(f);
      }
    }
  }

  Future<String?> stageForPreview(RecoveredFile file) async {
    try {
      final isContentUri = file.contentUri.startsWith('content://');
      if (isContentUri) {
        return await _reconstructor.stageUriForPreview(
          file.contentUri,
          file.name,
        );
      } else if (file.path.isNotEmpty) {
        return await _reconstructor.stageForPreview(file.path);
      }
    } catch (_) {}
    return null;
  }

  Future<void> shareFile(RecoveredFile file) async {
    final path = file.recoveredPath ?? file.path;
    if (path.isEmpty) return;
    await _export.shareFile(path, file.mimeType, file.name);
  }
}
