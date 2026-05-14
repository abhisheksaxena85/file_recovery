import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/storage_volume.dart';
import '../models/scan_progress.dart';
import '../providers/scanner_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/scan_wave_animator.dart';
import 'results_screen.dart';

class ScanScreen extends StatefulWidget {
  final StorageVolume volume;

  const ScanScreen({super.key, required this.volume});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  late Timer _elapsedTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Refresh elapsed display every second
    _elapsedTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) { if (mounted) setState(() {}); },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
  }

  Future<void> _startScan() async {
    final scanner = context.read<ScannerProvider>();
    await scanner.startScan(widget.volume.path);
  }

  @override
  void dispose() {
    _elapsedTimer.cancel();
    super.dispose();
  }

  void _onScanDone(ScanProgress progress, ScannerProvider scanner) {
    if (_navigated) return;
    if (progress.status == ScanStatus.done ||
        progress.status == ScanStatus.error ||
        progress.status == ScanStatus.cancelled) {
      _navigated = true;
      Future.microtask(() {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const ResultsScreen(),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ScannerProvider>(
      builder: (_, scanner, __) {
        final progress = scanner.progress;
        _onScanDone(progress, scanner);

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(gradient: AppGradients.background),
            child: SafeArea(
              child: Column(
                children: [
                  _buildAppBar(scanner, progress),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 32),
                          _buildRadar(progress),
                          const SizedBox(height: 40),
                          _buildStats(progress),
                          const SizedBox(height: 24),
                          _buildProgress(progress),
                          const SizedBox(height: 24),
                          _buildCurrentPath(progress),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                  _buildStopButton(scanner, progress),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(ScannerProvider scanner, ScanProgress progress) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textSecondary),
            onPressed: () async {
              await scanner.stopScan();
              if (mounted) Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scanning Storage',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  widget.volume.description,
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _StatusBadge(status: progress.status),
        ],
      ),
    );
  }

  Widget _buildRadar(ScanProgress progress) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ScanWaveAnimator(
          isActive: progress.isActive,
          size: 260,
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${progress.filesFound}',
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 40,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'files found',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStats(ScanProgress progress) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.timer_outlined,
            label: 'Elapsed',
            value: progress.elapsedFormatted,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.find_in_page_rounded,
            label: 'Found',
            value: '${progress.filesFound}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.storage_rounded,
            label: 'Volume',
            value: widget.volume.isPrimary ? 'Internal' : 'External',
          ),
        ),
      ],
    );
  }

  Widget _buildProgress(ScanProgress progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              progress.message.isEmpty ? 'Initializing…' : progress.message,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            backgroundColor: AppColors.cardBorder,
            valueColor: AlwaysStoppedAnimation<Color>(
              progress.status == ScanStatus.done
                  ? AppColors.success
                  : progress.status == ScanStatus.error
                      ? AppColors.error
                      : AppColors.primary,
            ),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentPath(ScanProgress progress) {
    if (progress.currentPath.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_open_rounded,
                  size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                'Currently Scanning',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            progress.currentPath,
            style: GoogleFonts.robotoMono(
              color: AppColors.primary.withValues(alpha: 0.8),
              fontSize: 10,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStopButton(ScannerProvider scanner, ScanProgress progress) {
    if (!progress.isActive) return const SizedBox(height: 24);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: OutlinedButton.icon(
          onPressed: () async {
            await scanner.stopScan();
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const ResultsScreen()),
              );
            }
          },
          icon: const Icon(Icons.stop_circle_rounded, size: 18),
          label: const Text('Stop & View Results'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            side: const BorderSide(color: AppColors.error, width: 1.5),
            foregroundColor: AppColors.error,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ScanStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ScanStatus.scanning  => ('Scanning', AppColors.primary),
      ScanStatus.carving   => ('Carving', AppColors.warning),
      ScanStatus.done      => ('Done', AppColors.success),
      ScanStatus.error     => ('Error', AppColors.error),
      ScanStatus.cancelled => ('Stopped', AppColors.textMuted),
      _                    => ('Idle', AppColors.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == ScanStatus.scanning || status == ScanStatus.carving) ...[
            SizedBox(
              width: 8,
              height: 8,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
          ] else ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        gradient: AppGradients.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
