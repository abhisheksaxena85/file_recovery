import 'dart:io';
import 'package:flutter/material.dart';
import '../models/recovered_file.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class RecoveredFileCard extends StatelessWidget {
  final RecoveredFile file;
  final VoidCallback onTap;
  final VoidCallback? onRecover;
  final bool showRecover;

  const RecoveredFileCard({
    super.key,
    required this.file,
    required this.onTap,
    this.onRecover,
    this.showRecover = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppGradients.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: file.isRecovered
                ? AppColors.success.withValues(alpha: 0.4)
                : AppColors.cardBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail area
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(15)),
                child: _Thumbnail(file: file),
              ),
            ),
            // Info + action
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _ConfidenceDot(confidence: file.confidence),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${file.confidence}% · ${file.formattedSize}',
                          style: GoogleFonts.inter(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (file.isRecovered)
                    _RecoveredBadge()
                  else if (showRecover)
                    _RecoverButton(onTap: onRecover),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final RecoveredFile file;
  const _Thumbnail({required this.file});

  @override
  Widget build(BuildContext context) {
    final path = file.recoveredPath ?? file.path;
    final hasPhysicalFile = path.isNotEmpty && File(path).existsSync();

    if (file.isImage && hasPhysicalFile) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _IconThumbnail(file: file),
      );
    }
    return _IconThumbnail(file: file);
  }
}

class _IconThumbnail extends StatelessWidget {
  final RecoveredFile file;
  const _IconThumbnail({required this.file});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: _bgColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_icon, size: 36, color: _iconColor),
          const SizedBox(height: 4),
          Text(
            file.name.split('.').last.toUpperCase(),
            style: GoogleFonts.inter(
              color: _iconColor.withValues(alpha: 0.7),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  IconData get _icon => switch (file.fileType) {
    'image'    => Icons.image_rounded,
    'video'    => Icons.videocam_rounded,
    'audio'    => Icons.audiotrack_rounded,
    'document' => Icons.description_rounded,
    'archive'  => Icons.folder_zip_rounded,
    _          => Icons.insert_drive_file_rounded,
  };

  Color get _iconColor => switch (file.fileType) {
    'image'    => AppColors.primary,
    'video'    => AppColors.accent,
    'audio'    => AppColors.warning,
    'document' => AppColors.secondary,
    _          => AppColors.textMuted,
  };

  Color get _bgColor => switch (file.fileType) {
    'image'    => Color.fromARGB(18, 0, 212, 170),
    'video'    => Color.fromARGB(18, 255, 101, 132),
    'audio'    => Color.fromARGB(18, 251, 191, 36),
    'document' => Color.fromARGB(18, 108, 99, 255),
    _          => AppColors.surface,
  };
}

class _ConfidenceDot extends StatelessWidget {
  final int confidence;
  const _ConfidenceDot({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final color = confidence >= 85
        ? AppColors.success
        : confidence >= 60
            ? AppColors.warning
            : AppColors.error;
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _RecoveredBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 10, color: AppColors.success),
          const SizedBox(width: 4),
          Text(
            'Recovered',
            style: GoogleFonts.inter(
              color: AppColors.success,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecoverButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _RecoverButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          gradient: AppGradients.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Recover',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: Colors.black,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
