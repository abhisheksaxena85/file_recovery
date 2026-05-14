class StorageVolume {
  final String id;
  final String description;
  final String path;
  final bool isRemovable;
  final bool isPrimary;
  final int totalBytes;
  final int freeBytes;
  final int usedBytes;
  final String state;

  const StorageVolume({
    required this.id,
    required this.description,
    required this.path,
    required this.isRemovable,
    required this.isPrimary,
    required this.totalBytes,
    required this.freeBytes,
    required this.usedBytes,
    this.state = 'mounted',
  });

  factory StorageVolume.fromMap(Map<Object?, Object?> map) {
    return StorageVolume(
      id:          map['id'] as String? ?? '',
      description: map['description'] as String? ?? 'Storage',
      path:        map['path'] as String? ?? '',
      isRemovable: map['isRemovable'] as bool? ?? false,
      isPrimary:   map['isPrimary'] as bool? ?? false,
      totalBytes:  (map['totalBytes'] as num?)?.toInt() ?? 0,
      freeBytes:   (map['freeBytes'] as num?)?.toInt() ?? 0,
      usedBytes:   (map['usedBytes'] as num?)?.toInt() ?? 0,
      state:       map['state'] as String? ?? 'mounted',
    );
  }

  String get formattedTotal  => _formatBytes(totalBytes);
  String get formattedFree   => _formatBytes(freeBytes);
  String get formattedUsed   => _formatBytes(usedBytes);
  double get usedFraction    => totalBytes > 0 ? usedBytes / totalBytes : 0.0;

  String _formatBytes(int bytes) {
    if (bytes == 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    int idx = 0;
    double val = bytes.toDouble();
    while (val >= 1024 && idx < units.length - 1) {
      val /= 1024;
      idx++;
    }
    return '${val.toStringAsFixed(idx == 0 ? 0 : 1)} ${units[idx]}';
  }
}
