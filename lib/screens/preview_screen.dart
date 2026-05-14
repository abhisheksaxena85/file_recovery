import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../models/recovered_file.dart';
import '../providers/recovery_provider.dart';
import '../theme/app_theme.dart';

class PreviewScreen extends StatefulWidget {
  final RecoveredFile file;

  const PreviewScreen({super.key, required this.file});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen>
    with SingleTickerProviderStateMixin {
  String? _stagedPath;
  bool _loading = true;
  VideoPlayerController? _videoCtrl;
  bool _infoExpanded = true;

  late AnimationController _sheetCtrl;
  late Animation<double> _sheetAnim;

  @override
  void initState() {
    super.initState();
    _sheetCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _sheetAnim = CurvedAnimation(
      parent: _sheetCtrl,
      curve: Curves.easeOutCubic,
    );
    _sheetCtrl.forward();
    _stage();
  }

  Future<void> _stage() async {
    final recovery = context.read<RecoveryProvider>();
    final path = await recovery.stageForPreview(widget.file);
    if (!mounted) return;

    setState(() {
      _stagedPath = path ?? widget.file.path;
      _loading    = false;
    });

    if (widget.file.isVideo && _stagedPath != null) {
      await _initVideo(_stagedPath!);
    }
  }

  Future<void> _initVideo(String path) async {
    _videoCtrl = VideoPlayerController.file(File(path));
    await _videoCtrl!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    _sheetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Media area (fullscreen)
          Positioned.fill(child: _buildMediaArea()),

          // ── Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  _GlassButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  _GlassButton(
                    icon: Icons.share_rounded,
                    onTap: _share,
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom info sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(_sheetAnim),
              child: _buildInfoSheet(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaArea() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final path = _stagedPath ?? widget.file.path;

    if (widget.file.isImage && path.isNotEmpty) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 5.0,
        child: Center(
          child: Image.file(
            File(path),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _NonPreviewable(file: widget.file),
          ),
        ),
      );
    }

    if (widget.file.isVideo && _videoCtrl?.value.isInitialized == true) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Container(color: Colors.black),
          AspectRatio(
            aspectRatio: _videoCtrl!.value.aspectRatio,
            child: VideoPlayer(_videoCtrl!),
          ),
          _VideoControls(controller: _videoCtrl!),
        ],
      );
    }

    return _NonPreviewable(file: widget.file);
  }

  Widget _buildInfoSheet() {
    final f = widget.file;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle + title
          GestureDetector(
            onTap: () => setState(() => _infoExpanded = !_infoExpanded),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            f.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          _infoExpanded
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_up_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_infoExpanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                children: [
                  _InfoRow(label: 'Size',       value: f.formattedSize),
                  _InfoRow(label: 'Type',       value: f.mimeType),
                  _InfoRow(label: 'Source',     value: f.sourceLabel),
                  _InfoRow(label: 'Confidence', value: '${f.confidence}% — ${f.confidenceLabel}'),
                  if (f.modifiedDate != null)
                    _InfoRow(
                      label: 'Last Modified',
                      value: _formatDate(f.modifiedDate!),
                    ),
                  if (f.path.isNotEmpty)
                    _InfoRow(
                      label: 'Original Path',
                      value: f.path,
                      mono: true,
                      maxLines: 2,
                    ),
                ],
              ),
            ),
          ],

          // Action buttons
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: f.isRecovered
                  ? _buildShareRow()
                  : _buildRecoverRow(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoverRow() {
    return Consumer<RecoveryProvider>(
      builder: (_, recovery, __) {
        final status = recovery.statusOf(widget.file.id);
        final isRecovering = status == RecoveryStatus.recovering;
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isRecovering ? null : _share,
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Share'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _GradientButton(
                onTap: isRecovering ? null : () => _recover(recovery),
                child: isRecovering
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.download_rounded,
                              color: Colors.black, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Recover File',
                            style: GoogleFonts.inter(
                              color: Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildShareRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 18),
                const SizedBox(width: 8),
                Text(
                  'File Recovered',
                  style: GoogleFonts.inter(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        _GradientButton(
          onTap: _share,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.share_rounded, color: Colors.black, size: 18),
              const SizedBox(width: 6),
              Text(
                'Share',
                style: GoogleFonts.inter(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _recover(RecoveryProvider recovery) async {
    final path = await recovery.recoverFile(widget.file);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            path != null ? 'Recovered to: $path' : 'Recovery failed',
            style: GoogleFonts.inter(fontSize: 13),
          ),
        ),
      );
    }
  }

  Future<void> _share() async {
    final recovery = context.read<RecoveryProvider>();
    await recovery.shareFile(widget.file);
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  final int maxLines;

  const _InfoRow({
    required this.label,
    required this.value,
    this.mono     = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: mono
                  ? GoogleFonts.robotoMono(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    )
                  : GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NonPreviewable extends StatelessWidget {
  final RecoveredFile file;
  const _NonPreviewable({required this.file});

  @override
  Widget build(BuildContext context) {
    final icon = switch (file.fileType) {
      'audio'    => Icons.audiotrack_rounded,
      'document' => Icons.description_rounded,
      'archive'  => Icons.folder_zip_rounded,
      _          => Icons.insert_drive_file_rounded,
    };
    final color = switch (file.fileType) {
      'audio'    => AppColors.warning,
      'document' => AppColors.secondary,
      _          => AppColors.textMuted,
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 80, color: color.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            file.name.split('.').last.toUpperCase(),
            style: GoogleFonts.inter(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Preview not available',
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoControls extends StatefulWidget {
  final VideoPlayerController controller;
  const _VideoControls({required this.controller});

  @override
  State<_VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<_VideoControls> {
  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    return GestureDetector(
      onTap: () => setState(() {
        ctrl.value.isPlaying ? ctrl.pause() : ctrl.play();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Icon(
          ctrl.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.38),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _GradientButton({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: onTap != null ? AppGradients.primary : null,
          color: onTap == null ? AppColors.card : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: child,
      ),
    );
  }
}
