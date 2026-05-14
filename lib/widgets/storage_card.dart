import 'package:flutter/material.dart';
import '../models/storage_volume.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class StorageCard extends StatelessWidget {
  final StorageVolume volume;
  final bool isSelected;
  final VoidCallback onTap;

  const StorageCard({
    super.key,
    required this.volume,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.secondary.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : AppGradients.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StorageIcon(volume: volume, isSelected: isSelected),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        volume.description,
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _Badge(
                            label: volume.isPrimary ? 'Internal' : 'External',
                            color: volume.isPrimary
                                ? AppColors.secondary
                                : AppColors.warning,
                          ),
                          const SizedBox(width: 6),
                          if (volume.isRemovable)
                            _Badge(label: 'Removable', color: AppColors.accent),
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.cardBorder,
                      width: 2,
                    ),
                    color: isSelected ? AppColors.primary : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.black)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Usage bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: volume.usedFraction,
                backgroundColor: AppColors.cardBorder,
                valueColor: AlwaysStoppedAnimation<Color>(
                  volume.usedFraction > 0.85
                      ? AppColors.error
                      : volume.usedFraction > 0.65
                          ? AppColors.warning
                          : AppColors.primary,
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatChip(
                  icon: Icons.storage_rounded,
                  label: volume.formattedTotal,
                  hint: 'Total',
                ),
                _StatChip(
                  icon: Icons.folder_open_rounded,
                  label: volume.formattedUsed,
                  hint: 'Used',
                ),
                _StatChip(
                  icon: Icons.cloud_done_rounded,
                  label: volume.formattedFree,
                  hint: 'Free',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StorageIcon extends StatelessWidget {
  final StorageVolume volume;
  final bool isSelected;

  const _StorageIcon({required this.volume, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final icon = volume.isRemovable
        ? Icons.sd_card_rounded
        : Icons.storage_rounded;
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: isSelected ? AppGradients.primary : null,
        color: isSelected ? null : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? Colors.transparent : AppColors.cardBorder,
        ),
      ),
      child: Icon(
        icon,
        color: isSelected ? Colors.black : AppColors.primary,
        size: 26,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;

  const _StatChip({required this.icon, required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(
              hint,
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
