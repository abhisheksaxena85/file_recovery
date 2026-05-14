enum ScanStatus { idle, scanning, carving, done, error, cancelled }

class ScanProgress {
  final ScanStatus status;
  final int filesFound;
  final String currentPath;
  final String message;
  final String? errorMessage;
  final DateTime? startTime;

  const ScanProgress({
    this.status = ScanStatus.idle,
    this.filesFound = 0,
    this.currentPath = '',
    this.message = '',
    this.errorMessage,
    this.startTime,
  });

  ScanProgress copyWith({
    ScanStatus? status,
    int? filesFound,
    String? currentPath,
    String? message,
    String? errorMessage,
    DateTime? startTime,
  }) {
    return ScanProgress(
      status:       status       ?? this.status,
      filesFound:   filesFound   ?? this.filesFound,
      currentPath:  currentPath  ?? this.currentPath,
      message:      message      ?? this.message,
      errorMessage: errorMessage ?? this.errorMessage,
      startTime:    startTime    ?? this.startTime,
    );
  }

  Duration get elapsed {
    if (startTime == null) return Duration.zero;
    return DateTime.now().difference(startTime!);
  }

  String get elapsedFormatted {
    final d = elapsed;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }

  bool get isActive => status == ScanStatus.scanning || status == ScanStatus.carving;
}
