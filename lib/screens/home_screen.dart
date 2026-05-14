import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/storage_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/storage_card.dart';
import 'scan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  Map<Permission, PermissionStatus> _permStatuses = {};
  bool _permChecked = false;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    await _checkPermissions();
    if (mounted) {
      context.read<StorageProvider>().loadVolumes();
    }
  }

  Future<void> _checkPermissions() async {
    final Map<Permission, PermissionStatus> statuses = {};
    if (mounted) {
      statuses[Permission.storage] = await Permission.storage.status;
      if (mounted) {
        statuses[Permission.manageExternalStorage] =
            await Permission.manageExternalStorage.status;
      }
    }
    if (mounted) {
      setState(() {
        _permStatuses = statuses;
        _permChecked  = true;
      });
    }
  }

  Future<void> _requestPermissions() async {
    // Request storage permissions (iOS mediaLibrary not included on Android)
    final results = await [
      Permission.storage,
      Permission.manageExternalStorage,
    ].request();

    if (mounted) setState(() => _permStatuses = results);

    if (mounted) {
      context.read<StorageProvider>().loadVolumes();
    }
  }

  bool get _hasBasicPermission =>
      _permStatuses[Permission.storage]?.isGranted == true ||
      _permStatuses[Permission.manageExternalStorage]?.isGranted == true;

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: CustomScrollView(
              slivers: [
                _buildHeader(),
                if (_permChecked && !_hasBasicPermission)
                  _buildPermissionBanner(),
                _buildSectionLabel('Storage Volumes'),
                _buildStorageList(),
                _buildSectionLabel('Scan Options'),
                _buildScanOptions(),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildStartButton(),
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppGradients.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.storage_rounded,
                      color: Colors.black, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DataRevive',
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Select storage & start recovery',
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: AppColors.textSecondary),
                  onPressed: () {
                    _checkPermissions();
                    context.read<StorageProvider>().loadVolumes();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            _PermissionStatusRow(
              hasPermission: _hasBasicPermission,
              onRequest: _requestPermissions,
              checked: _permChecked,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionBanner() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_rounded,
                color: AppColors.error, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Storage permission is required to scan for deleted files.',
                style: GoogleFonts.inter(
                  color: AppColors.error,
                  fontSize: 13,
                ),
              ),
            ),
            TextButton(
              onPressed: _requestPermissions,
              child: Text(
                'Grant',
                style: GoogleFonts.inter(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildStorageList() {
    return SliverToBoxAdapter(
      child: Consumer<StorageProvider>(
        builder: (_, sp, __) {
          if (sp.loading) {
            return const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
          if (sp.error != null) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: _ErrorCard(message: sp.error!),
            );
          }
          if (sp.volumes.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No storage volumes detected',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            );
          }
          return Column(
            children: sp.volumes
                .map((v) => StorageCard(
                      volume: v,
                      isSelected: sp.selected?.id == v.id,
                      onTap: () => sp.selectVolume(v),
                    ))
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildScanOptions() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: const [
            _ScanOptionTile(
              icon: Icons.find_in_page_rounded,
              title: 'MediaStore Trash Scan',
              subtitle: 'Recovers recently deleted media from Android Recycle Bin',
              badge: 'Recommended',
              badgeColor: AppColors.success,
            ),
            SizedBox(height: 8),
            _ScanOptionTile(
              icon: Icons.search_rounded,
              title: 'Deep File Scan',
              subtitle: 'Scans LOST.DIR, trash folders, and hidden locations',
              badge: 'All Devices',
              badgeColor: AppColors.primary,
            ),
            SizedBox(height: 8),
            _ScanOptionTile(
              icon: Icons.memory_rounded,
              title: 'Block-Level Scan',
              subtitle: 'Raw disk carving for maximum recovery (root required)',
              badge: 'Root Only',
              badgeColor: AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return Consumer<StorageProvider>(
      builder: (_, sp, __) {
        final enabled = sp.selected != null && _hasBasicPermission;
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.95),
            border: const Border(
              top: BorderSide(color: AppColors.divider, width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                gradient: enabled ? AppGradients.primary : null,
                color: enabled ? null : AppColors.card,
                borderRadius: BorderRadius.circular(18),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: enabled ? _startScan : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.radar_rounded,
                          color: enabled ? Colors.black : AppColors.textMuted,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          sp.selected == null
                              ? 'Select a Storage First'
                              : 'Start Recovery Scan',
                          style: GoogleFonts.inter(
                            color: enabled ? Colors.black : AppColors.textMuted,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _startScan() {
    final sp = context.read<StorageProvider>();
    if (sp.selected == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScanScreen(volume: sp.selected!),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _PermissionStatusRow extends StatelessWidget {
  final bool hasPermission;
  final VoidCallback onRequest;
  final bool checked;

  const _PermissionStatusRow({
    required this.hasPermission,
    required this.onRequest,
    required this.checked,
  });

  @override
  Widget build(BuildContext context) {
    if (!checked) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: hasPermission
            ? AppColors.success.withValues(alpha: 0.08)
            : AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasPermission
              ? AppColors.success.withValues(alpha: 0.25)
              : AppColors.warning.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.shield_outlined,
            size: 18,
            color: hasPermission ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasPermission
                  ? 'Storage permission granted — ready to scan'
                  : 'Storage permission needed for full recovery',
              style: GoogleFonts.inter(
                color:
                    hasPermission ? AppColors.success : AppColors.warning,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (!hasPermission) ...[
            GestureDetector(
              onTap: onRequest,
              child: Text(
                'Allow',
                style: GoogleFonts.inter(
                  color: AppColors.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.warning,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScanOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;

  const _ScanOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppGradients.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: badgeColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: GoogleFonts.inter(
                          color: badgeColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: AppColors.error,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
