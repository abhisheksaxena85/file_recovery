import 'package:flutter/material.dart';
import '../models/recovered_file.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class FilterTab {
  final String key;
  final String label;
  final IconData icon;

  const FilterTab({required this.key, required this.label, required this.icon});
}

const kFilterTabs = [
  FilterTab(key: 'all',      label: 'All',        icon: Icons.apps_rounded),
  FilterTab(key: 'image',    label: 'Images',      icon: Icons.image_rounded),
  FilterTab(key: 'video',    label: 'Videos',      icon: Icons.videocam_rounded),
  FilterTab(key: 'audio',    label: 'Audio',       icon: Icons.audiotrack_rounded),
  FilterTab(key: 'document', label: 'Documents',   icon: Icons.description_rounded),
  FilterTab(key: 'archive',  label: 'Archives',    icon: Icons.folder_zip_rounded),
];

class FilterBar extends StatelessWidget {
  final String active;
  final Map<String, int> counts;
  final ValueChanged<String> onChanged;

  const FilterBar({
    super.key,
    required this.active,
    required this.counts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: kFilterTabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final tab = kFilterTabs[i];
          final isActive = tab.key == active;
          final count = counts[tab.key] ?? 0;
          if (tab.key != 'all' && count == 0) return const SizedBox.shrink();

          return GestureDetector(
            onTap: () => onChanged(tab.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: isActive ? AppGradients.primary : null,
                color: isActive ? null : AppColors.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isActive ? Colors.transparent : AppColors.cardBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tab.icon,
                    size: 14,
                    color: isActive ? Colors.black : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tab.label,
                    style: GoogleFonts.inter(
                      color: isActive ? Colors.black : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.black.withValues(alpha: 0.2)
                            : AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: GoogleFonts.inter(
                          color: isActive ? Colors.black : AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
