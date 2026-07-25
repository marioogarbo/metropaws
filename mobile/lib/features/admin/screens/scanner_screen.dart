import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../../../core/widgets/camera_scan_page.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_event.dart';
import '../../../theme.dart';
import 'deploy_service_screen.dart';

class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (_) => AdminBloc(), child: const _AdminShell());
  }
}

// ── Admin shell with bottom nav ────────────────────────────────────────────

class _AdminShell extends StatefulWidget {
  const _AdminShell();

  @override
  State<_AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<_AdminShell> {
  int _currentIndex = 0;

  static const _tabs = [
    _NavItem(
      icon: Icons.qr_code_scanner_outlined,
      selectedIcon: Icons.qr_code_scanner,
      label: 'Scanner',
    ),
    _NavItem(
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
      label: 'Activity',
    ),
    _NavItem(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'Account',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: IndexedStack(
        index: _currentIndex,
        children: const [_ScannerTab(), _ActivityTab(), _AccountTab()],
      ),
      bottomNavigationBar: _AdminNavBar(
        currentIndex: _currentIndex,
        tabs: _tabs,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ── Scanner tab ────────────────────────────────────────────────────────────

class _ScannerTab extends StatefulWidget {
  const _ScannerTab();

  @override
  State<_ScannerTab> createState() => _ScannerTabState();
}

class _ScannerTabState extends State<_ScannerTab>
    with SingleTickerProviderStateMixin {
  final _tokenCtrl = TextEditingController();
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _lookup() {
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) return;
    context.read<AdminBloc>().add(AdminScanRequested(token));
  }

  Future<void> _openCamera() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const CameraScanPage()),
    );
    if (scanned != null && scanned.isNotEmpty && mounted) {
      _tokenCtrl.text = scanned;
      context.read<AdminBloc>().add(AdminScanRequested(scanned));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<AdminBloc, AdminState>(
      listener: (context, state) {
        if (state is AdminScanSuccess) {
          if (!context.mounted) return;
          final adminBloc = context.read<AdminBloc>();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: adminBloc,
                child: DeployServiceScreen(
                  member: state.member,
                  serviceTypes: state.serviceTypes,
                ),
              ),
            ),
          ).then((_) => adminBloc.add(AdminReset()));
        }
        if (state is AdminFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(state.message)),
                ],
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          context.read<AdminBloc>().add(AdminReset());
        }
      },
      builder: (context, state) {
        final loading = state is AdminLoading;
        return Column(
          children: [
            _ScannerHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        _kHeaderHeight -
                        _kNavBarHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),
                        _ScanFrame(
                          pulse: _pulse,
                          loading: loading,
                          onTap: _openCamera,
                        ),
                        const SizedBox(height: 32),
                        _TokenInputSection(
                          ctrl: _tokenCtrl,
                          loading: loading,
                          isDark: isDark,
                          onSubmit: _lookup,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

const _kHeaderHeight = 88.0;
const _kNavBarHeight = 80.0;

// ── Activity tab ───────────────────────────────────────────────────────────

class _ActivityTab extends StatelessWidget {
  const _ActivityTab();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        _SimpleHeader(title: 'ACTIVITY', subtitle: 'Service deployment log'),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    size: 32,
                    color: AppColors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No activity yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Shields you deploy today will appear here.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Account tab ────────────────────────────────────────────────────────────

class _AccountTab extends StatelessWidget {
  const _AccountTab();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        _SimpleHeader(title: 'ACCOUNT', subtitle: 'Staff session'),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppDarkColors.surface : AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outline),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.navy,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Staff Account',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'MetroPaws Wellness Club',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _AccountAction(
                  icon: Icons.logout_rounded,
                  label: 'Sign out',
                  destructive: true,
                  isDark: isDark,
                  onTap: () =>
                      context.read<AuthBloc>().add(AuthLogoutRequested()),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool destructive;
  final bool isDark;
  final VoidCallback onTap;

  const _AccountAction({
    required this.icon,
    required this.label,
    required this.destructive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = destructive ? AppColors.error : AppColors.navy;

    return Material(
      color: isDark ? AppDarkColors.surface : AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outline),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 14),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared header widgets ──────────────────────────────────────────────────

class _ScannerHeader extends StatelessWidget {
  const _ScannerHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.navy,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: _kHeaderHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MEMBER SCANNER',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              fontSize: 15,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'MetroPaws Wellness Club',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SimpleHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SimpleHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.navy,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: _kHeaderHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Nav bar ────────────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class _AdminNavBar extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> tabs;
  final ValueChanged<int> onTap;

  const _AdminNavBar({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppColors.gold : AppColors.navy;
    final inactiveColor = isDark ? AppDarkColors.subtext : AppColors.grey;
    final bgColor = isDark ? AppDarkColors.surface : AppColors.surface;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: const Border(
          top: BorderSide(color: AppColors.gold, width: 1.5),
        ),
      ),
      child: SizedBox(
        height: 64 + bottomPad,
        child: Row(
          children: List.generate(tabs.length, (i) {
            final isSelected = i == currentIndex;
            final tab = tabs[i];
            return Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomPad),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isSelected ? tab.selectedIcon : tab.icon,
                        size: 24,
                        color: isSelected ? activeColor : inactiveColor,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tab.label,
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected ? activeColor : inactiveColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── QR scan frame ──────────────────────────────────────────────────────────

class _ScanFrame extends StatelessWidget {
  final Animation<double> pulse;
  final bool loading;
  final VoidCallback onTap;

  const _ScanFrame({
    required this.pulse,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        GestureDetector(
          onTap: loading ? null : onTap,
          child: SizedBox(
            width: 240,
            height: 240,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                ..._buildCorners(),
                Center(
                  child: loading
                      ? const CircularProgressIndicator(
                          color: AppColors.navy,
                          strokeWidth: 2.5,
                        )
                      : AnimatedBuilder(
                          animation: pulse,
                          builder: (_, __) => Opacity(
                            opacity: 0.4 + pulse.value * 0.4,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.camera_alt_rounded,
                                  size: 52,
                                  color: AppColors.navy.withValues(alpha: 0.55),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Tap to scan',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: AppColors.navy.withValues(
                                          alpha: 0.65,
                                        ),
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'or enter token below',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: AppColors.grey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: pulse,
              builder: (_, __) => Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: loading
                      ? AppColors.gold
                      : Color.lerp(
                          AppColors.success.withValues(alpha: 0.4),
                          AppColors.success,
                          pulse.value,
                        ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              loading ? 'Looking up member…' : 'Camera scan or enter token',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildCorners() {
    const arm = 28.0;
    const thick = 3.0;
    const br = 5.0;
    const pad = 16.0;
    const color = AppColors.navy;

    return [
      Positioned(
        top: pad,
        left: pad,
        child: _Corner(
          arm: arm,
          thick: thick,
          br: br,
          color: color,
          top: true,
          left: true,
        ),
      ),
      Positioned(
        top: pad,
        right: pad,
        child: _Corner(
          arm: arm,
          thick: thick,
          br: br,
          color: color,
          top: true,
          left: false,
        ),
      ),
      Positioned(
        bottom: pad,
        left: pad,
        child: _Corner(
          arm: arm,
          thick: thick,
          br: br,
          color: color,
          top: false,
          left: true,
        ),
      ),
      Positioned(
        bottom: pad,
        right: pad,
        child: _Corner(
          arm: arm,
          thick: thick,
          br: br,
          color: color,
          top: false,
          left: false,
        ),
      ),
    ];
  }
}

class _Corner extends StatelessWidget {
  final double arm;
  final double thick;
  final double br;
  final Color color;
  final bool top;
  final bool left;

  const _Corner({
    required this.arm,
    required this.thick,
    required this.br,
    required this.color,
    required this.top,
    required this.left,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: arm,
      height: arm,
      child: CustomPaint(
        painter: _CornerPainter(
          thick: thick,
          br: br,
          color: color,
          top: top,
          left: left,
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final double thick;
  final double br;
  final Color color;
  final bool top;
  final bool left;

  _CornerPainter({
    required this.thick,
    required this.br,
    required this.color,
    required this.top,
    required this.left,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thick
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    final path = Path();
    final w = size.width;
    final h = size.height;

    if (top && left) {
      path.moveTo(0, h);
      path.lineTo(0, br);
      path.quadraticBezierTo(0, 0, br, 0);
      path.lineTo(w, 0);
    } else if (top && !left) {
      path.moveTo(0, 0);
      path.lineTo(w - br, 0);
      path.quadraticBezierTo(w, 0, w, br);
      path.lineTo(w, h);
    } else if (!top && left) {
      path.moveTo(0, 0);
      path.lineTo(0, h - br);
      path.quadraticBezierTo(0, h, br, h);
      path.lineTo(w, h);
    } else {
      path.moveTo(0, h);
      path.lineTo(w - br, h);
      path.quadraticBezierTo(w, h, w, h - br);
      path.lineTo(w, 0);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}

// ── Token input section ────────────────────────────────────────────────────

class _TokenInputSection extends StatelessWidget {
  final TextEditingController ctrl;
  final bool loading;
  final bool isDark;
  final VoidCallback onSubmit;

  const _TokenInputSection({
    required this.ctrl,
    required this.loading,
    required this.isDark,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter QR Token',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Paste or type the token from the member's Digital Pawprint.",
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: ctrl,
          onSubmitted: (_) => onSubmit(),
          enabled: !loading,
          style: GoogleFonts.sourceCodePro(
            color: cs.onSurface,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: 'e.g. MP-AW-26-05-P',
            hintStyle: GoogleFonts.sourceCodePro(
              color: cs.onSurfaceVariant.withValues(alpha: 0.55),
              fontWeight: FontWeight.w400,
              fontSize: 13,
            ),
            prefixIcon: const Icon(Icons.tag_rounded, size: 18),
            prefixIconColor: AppColors.grey,
            suffixIcon: loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.navy,
                      ),
                    ),
                  )
                : null,
            filled: true,
            fillColor: isDark ? AppDarkColors.elevated : AppColors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cs.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cs.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: loading ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.navy.withValues(alpha: 0.45),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Look Up Member',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
