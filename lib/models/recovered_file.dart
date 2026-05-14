class RecoveredFile {
  final String id;
  final String name;
  final String path;
  final int size;
  final DateTime? modifiedDate;
  final DateTime? expiresDate;
  final String mimeType;
  final String fileType;    // image | video | audio | document | archive | other
  final String recoverySource; // mediastore_trash | lost_dir | trash_folder | file_carving | raw_block_scan
  final int confidence;     // 0–100
  final String contentUri;  // file:// or content:// URI
  final bool isRecoverable;
  bool isRecovered;
  String? recoveredPath;
  bool isSelected;

  RecoveredFile({
    required this.id,
    required this.name,
    required this.path,
    required this.size,
    this.modifiedDate,
    this.expiresDate,
    required this.mimeType,
    required this.fileType,
    required this.recoverySource,
    required this.confidence,
    required this.contentUri,
    this.isRecoverable = true,
    this.isRecovered = false,
    this.recoveredPath,
    this.isSelected = false,
  });

  factory RecoveredFile.fromMap(Map<Object?, Object?> map) {
    final modMs  = (map['modifiedDate'] as num?)?.toInt();
    final expMs  = (map['expiresDate']  as num?)?.toInt();
    return RecoveredFile(
      id:             map['id'] as String? ?? '',
      name:           map['name'] as String? ?? 'Unknown',
      path:           map['path'] as String? ?? '',
      size:           (map['size'] as num?)?.toInt() ?? 0,
      modifiedDate:   modMs != null && modMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(modMs)
          : null,
      expiresDate:    expMs != null && expMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(expMs)
          : null,
      mimeType:       map['mimeType'] as String? ?? '',
      fileType:       map['fileType'] as String? ?? 'other',
      recoverySource: map['recoverySource'] as String? ?? '',
      confidence:     (map['confidence'] as num?)?.toInt() ?? 50,
      contentUri:     (map['contentUri'] as String?)
          ?? (map['uri'] as String?)
          ?? '',
      isRecoverable:  map['isRecoverable'] as bool? ?? true,
    );
  }

  String get formattedSize {
    if (size == 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    int idx = 0;
    double val = size.toDouble();
    while (val >= 1024 && idx < units.length - 1) {
      val /= 1024;
      idx++;
    }
    return '${val.toStringAsFixed(idx == 0 ? 0 : 1)} ${units[idx]}';
  }

  String get confidenceLabel {
    if (confidence >= 85) return 'High';
    if (confidence >= 60) return 'Medium';
    return 'Low';
  }

  String get sourceLabel {
    switch (recoverySource) {
      case 'mediastore_trash': return 'Recycle Bin';
      case 'lost_dir':         return 'LOST.DIR';
      case 'trash_folder':     return 'Trash Folder';
      case 'file_carving':     return 'Deep Scan';
      case 'raw_block_scan':   return 'Block Scan';
      default:                 return recoverySource;
    }
  }

  bool get isImage    => fileType == 'image';
  bool get isVideo    => fileType == 'video';
  bool get isAudio    => fileType == 'audio';
  bool get isDocument => fileType == 'document';
}
