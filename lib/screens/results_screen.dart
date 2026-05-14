import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/recovered_file.dart';
import '../providers/scanner_provider.dart';
import '../providers/recovery_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/recovered_file_card.dart';
import '../widgets/filter_bar.dart';
import 'preview_screen.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  String _activeFilter = 'all';
  bool _isGrid = true;

  List<RecoveredFile> _filtered(List<RecoveredFile> all) {
    if (_activeFilter == 'all') return all;
    return all.where((f) => f.fileType == _activeFilter).toList();
  }

  Map<String, int> _buildCounts(List<RecoveredFile> all) {
    final counts = <String, int>{'all': all.length};
    for (final f in all) {
      counts[f.fileType] = (counts[f.fileType] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ScannerProvider, RecoveryProvider>(
      builder: (_, scanner, recovery, __) {
        final all      = scanner.results;
        final filtered = _filtered(all);
        final counts   = _buildCounts(all);

        return Scaffold(
          body: Container(
            decoration:
                const BoxDecoration(gradient: AppGradients.background),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(context, all, recovery),
                  const SizedBox(height: 12),
                  FilterBar(
                    active: _activeFilter,
                    counts: counts,
                    onChanged: (f) => setState(() => _activeFilter = f),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? _EmptyState(filter: _activeFilter)
                        : _isGrid
                            ? _GridView(
                                files: filtered,
                                recovery: recovery,
                                onTap: (f) => _openPreview(context, f),
                                onRecover: (f) => _recover(context, f, recovery),
                              )
                            : _ListView(
                                files: filtered,
                                recovery: recovery,
                                onTap: (f) => _openPreview(context, f),
                                onRecover: (f) => _recover(context, f, recovery),
                              ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: all.isNotEmpty
              ? _RecoverAllFab(
                  onTap: () => _recoverAll(context, all, recovery),
                )
              : null,
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    List<RecoveredFile> all,
    RecoveryProvider recovery,
  ) {
    final recovered = all.where((f) => f.isRecovered).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recovery Results',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${all.length} files found · $recovered recovered',
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Toggle grid / list
          IconButton(
            icon: Icon(
              _isGrid ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: AppColors.textSecondary,
            ),
            onPressed: () => setState(() => _isGrid = !_isGrid),
          ),
        ],
      ),
    );
  }

  void _openPreview(BuildContext context, RecoveredFile file) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PreviewScreen(file: file)),
    );
  }

  Future<void> _recover(
    BuildContext context,
    RecoveredFile file,
    RecoveryProvider recovery,
  ) async {
    final path = await recovery.recoverFile(file);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                path != null ? Icons.check_circle_rounded : Icons.error_rounded,
                color: path != null ? AppColors.success : AppColors.error,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  path != null
                      ? 'Recovered: ${file.name}'
                      : 'Failed to recover: ${recovery.lastError}',
                  style: GoogleFonts.inter(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _recoverAll(
    BuildContext context,
    List<RecoveredFile> files,
    RecoveryProvider recovery,
  ) async {
    final unrecovered = files.where((f) => !f.isRecovered).toList();
    if (unrecovered.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recover All Files'),
        content: Text(
          'This will attempt to recover ${unrecovered.length} files to your device storage. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await recovery.recoverAll(unrecovered);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Recovery complete — check your Files app',
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                  ),
                );
              }
            },
            child: const Text('Recover All'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _GridView extends StatelessWidget {
  final List<RecoveredFile> files;
  final RecoveryProvider recovery;
  final ValueChanged<RecoveredFile> onTap;
  final ValueChanged<RecoveredFile> onRecover;

  const _GridView({
    required this.files,
    required this.recovery,
    required this.onTap,
    required this.onRecover,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.72,
      ),
      itemCount: files.length,
      itemBuilder: (_, i) => RecoveredFileCard(
        file: files[i],
        onTap: () => onTap(files[i]),
        onRecover: () => onRecover(files[i]),
      ),
    );
  }
}

class _ListView extends StatelessWidget {
  final List<RecoveredFile> files;
  final RecoveryProvider recovery;
  final ValueChanged<RecoveredFile> onTap;
  final ValueChanged<RecoveredFile> onRecover;

  const _ListView({
    required this.files,
    required this.recovery,
    required this.onTap,
    required this.onRecover,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: files.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final f = files[i];
        return GestureDetector(
          onTap: () => onTap(f),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppGradients.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: f.isRecovered
                    ? AppColors.success.withValues(alpha: 0.3)
                    : AppColors.cardBorder,
              ),
            ),
            child: Row(
              children: [
                _FileTypeIcon(file: f),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _ConfidenceChip(confidence: f.confidence),
                          const SizedBox(width: 6),
                          Text(
                            f.formattedSize,
                            style: GoogleFonts.inter(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '· ${f.sourceLabel}',
                            style: GoogleFonts.inter(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (f.isRecovered)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: AppColors.success, size: 16),
                  )
                else
                  GestureDetector(
                    onTap: () => onRecover(f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: AppGradients.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Recover',
                        style: GoogleFonts.inter(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FileTypeIcon extends StatelessWidget {
  final RecoveredFile file;
  const _FileTypeIcon({required this.file});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (file.fileType) {
      'image'    => (Icons.image_rounded, AppColors.primary),
      'video'    => (Icons.videocam_rounded, AppColors.accent),
      'audio'    => (Icons.audiotrack_rounded, AppColors.warning),
      'document' => (Icons.description_rounded, AppColors.secondary),
      'archive'  => (Icons.folder_zip_rounded, AppColors.textSecondary),
      _          => (Icons.insert_drive_file_rounded, AppColors.textMuted),
    };
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _ConfidenceChip extends StatelessWidget {
  final int confidence;
  const _ConfidenceChip({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final color = confidence >= 85
        ? AppColors.success
        : confidence >= 60
            ? AppColors.warning
            : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$confidence%',
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            filter == 'all'
                ? 'No deleted files found'
                : 'No ${filter}s found',
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try scanning a different storage or\ngranting full storage access.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecoverAllFab extends StatelessWidget {
  final VoidCallback onTap;
  const _RecoverAllFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onTap,
      backgroundColor: Colors.transparent,
      elevation: 0,
      label: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: AppGradients.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.download_rounded, color: Colors.black, size: 20),
            const SizedBox(width: 8),
            Text(
              'Recover All',
              style: GoogleFonts.inter(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
