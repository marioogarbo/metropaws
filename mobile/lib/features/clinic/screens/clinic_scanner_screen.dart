import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/blocs/theme_cubit.dart';
import '../bloc/clinic_bloc.dart';
import '../bloc/clinic_event.dart';
import '../bloc/clinic_state.dart';
import '../../../core/models/clinic_scan_result.dart';
import '../../../core/models/clinic_booking.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/widgets/camera_scan_page.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_event.dart';
import '../../../theme.dart';

class ClinicScannerScreen extends StatefulWidget {
  const ClinicScannerScreen({super.key});

  @override
  State<ClinicScannerScreen> createState() => _ClinicScannerScreenState();
}

class _ClinicScannerScreenState extends State<ClinicScannerScreen> {
  int _currentIndex = 0;
  bool _showResult = false;
  late final ClinicBloc _clinicBloc;

  @override
  void initState() {
    super.initState();
    _clinicBloc = ClinicBloc();
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _clinicBloc.add(ClinicScheduleRequested(date: today));
  }

  @override
  void dispose() {
    _clinicBloc.close();
    super.dispose();
  }

  void _onTabTap(int i) {
    if (_showResult) _clinicBloc.add(ClinicReset());
    setState(() {
      _currentIndex = i;
      _showResult = false;
    });
  }

  Future<void> _openScanner() async {
    final token = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const CameraScanPage()),
    );
    if (token == null || token.isEmpty || !mounted) return;
    _clinicBloc.add(ClinicScanRequested(token));
    setState(() => _showResult = true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocProvider.value(
      value: _clinicBloc,
      child: BlocListener<ClinicBloc, ClinicState>(
        listener: (context, state) {
          if (state is ClinicInitial && _showResult) {
            setState(() => _showResult = false);
          }
          if (state is ClinicFailure && _showResult) {
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
            _clinicBloc.add(ClinicReset());
          }
        },
        child: Scaffold(
          backgroundColor: isDark ? AppDarkColors.bg : AppColors.surface,
          body: Stack(
            children: [
              // Keep IndexedStack always alive so home tab state
              // (filter, loaded schedule) survives scan result views.
              IndexedStack(
                index: _currentIndex,
                children: [
                  _ClinicHomeTab(onScanTap: _openScanner),
                  const _ClinicAccountTab(),
                ],
              ),
              if (_showResult)
                RepaintBoundary(
                  child: ColoredBox(
                    color: isDark ? AppDarkColors.bg : AppColors.surface,
                    child: BlocBuilder<ClinicBloc, ClinicState>(
                      buildWhen: (_, curr) =>
                          curr is ClinicLoading ||
                          curr is ClinicScanSuccess ||
                          curr is ClinicFailure,
                      builder: (context, state) {
                        if (state is ClinicScanSuccess) {
                          return _PetRecordView(
                            result: state.result,
                            isDark: isDark,
                          );
                        }
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.navy,
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: _ClinicNavBar(
            currentIndex: _currentIndex,
            onTap: _onTabTap,
            onQrTap: _openScanner,
          ),
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

const _kHeaderHeight = 88.0;

class _ClinicHeader extends StatelessWidget {
  final String? title;
  final String subtitle;
  final Widget? trailing;
  const _ClinicHeader({this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final hasTitle = title != null;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E3D6B), Color(0xFF1C2545)],
        ),
        border: Border(
          bottom: BorderSide(
            color: AppColors.gold.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: _kHeaderHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
            child: Row(
              children: [
                if (hasTitle) ...[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.30),
                        width: 0.75,
                      ),
                    ),
                    child: const Icon(
                      Icons.local_hospital_rounded,
                      color: AppColors.gold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasTitle)
                        Text(
                          title!,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                fontSize: 15,
                              ),
                        )
                      else
                        Image.asset(
                          'assets/images/logo-full-white-metro.png',
                          height: 28,
                          fit: BoxFit.contain,
                          alignment: Alignment.centerLeft,
                        ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Scan input view ───────────────────────────────────────────────────────────

class _ScanInputView extends StatefulWidget {
  final bool loading;
  final bool isDark;
  const _ScanInputView({required this.loading, required this.isDark});

  @override
  State<_ScanInputView> createState() => _ScanInputViewState();
}

class _ScanInputViewState extends State<_ScanInputView>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !MediaQuery.of(context).disableAnimations) {
        _pulseCtrl.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _lookup() {
    final token = _ctrl.text.trim();
    if (token.isEmpty) return;
    context.read<ClinicBloc>().add(ClinicScanRequested(token));
  }

  Future<void> _openCamera() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const CameraScanPage()),
    );
    if (scanned != null && scanned.isNotEmpty && mounted) {
      _ctrl.text = scanned;
      context.read<ClinicBloc>().add(ClinicScanRequested(scanned));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        const _ClinicHeader(subtitle: 'Partner Clinic Access'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 32),
                // QR frame
                GestureDetector(
                  onTap: widget.loading ? null : _openCamera,
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        Center(
                          child: widget.loading
                              ? const CircularProgressIndicator(
                                  color: AppColors.navy,
                                  strokeWidth: 2.5,
                                )
                              : AnimatedBuilder(
                                  animation: _pulse,
                                  builder: (context, a) => Opacity(
                                    opacity: 0.4 + _pulse.value * 0.4,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.qr_code_scanner_rounded,
                                          size: 52,
                                          color: AppColors.navy.withValues(
                                            alpha: 0.55,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'Tap to scan QR',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                color: AppColors.navy
                                                    .withValues(alpha: 0.7),
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'or enter token below',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
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
                const SizedBox(height: 32),
                // Token input
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter QR Token',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Paste or type the token from the member's Digital Pawprint.",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _ctrl,
                      onSubmitted: (_) => _lookup(),
                      enabled: !widget.loading,
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
                        filled: true,
                        fillColor: widget.isDark
                            ? AppDarkColors.elevated
                            : AppColors.white,
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
                          borderSide: const BorderSide(
                            color: AppColors.navy,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: widget.loading ? null : _lookup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.navy.withValues(
                            alpha: 0.45,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: widget.loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Look Up Pet Records',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Pet record view ───────────────────────────────────────────────────────────

class _PetRecordView extends StatelessWidget {
  final ClinicScanResult result;
  final bool isDark;

  const _PetRecordView({required this.result, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        _ClinicHeader(
          subtitle: 'Partner Clinic Access',
          trailing: TextButton(
            onPressed: () => context.read<ClinicBloc>().add(ClinicReset()),
            child: Text(
              'Scan Another',
              style: GoogleFonts.montserrat(
                color: AppColors.gold,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
        _ValidMemberStamp(
          memberName: '${result.firstName} ${result.lastName}',
          planType: result.planType,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Member banner
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${result.firstName} ${result.lastName}',
                              style: GoogleFonts.montserrat(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            if (result.planType != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                '${result.planType} Plan',
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (result.email != null) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(
                                    Icons.email_outlined,
                                    size: 11,
                                    color: Colors.white.withValues(alpha: 0.65),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      result.email!,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        color: Colors.white.withValues(
                                          alpha: 0.75,
                                        ),
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (result.phone != null) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    Icons.phone_outlined,
                                    size: 11,
                                    color: Colors.white.withValues(alpha: 0.65),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    result.phone!,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      color: Colors.white.withValues(
                                        alpha: 0.75,
                                      ),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Member-level sessions available
                if (result.services.isNotEmpty) ...[
                  _ClinicSectionHeader(
                    title: 'SESSIONS AVAILABLE',
                    icon: Icons.event_available_rounded,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  ...result.services.map(
                    (svc) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SessionRow(service: svc, isDark: isDark),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (result.pets.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(
                            Icons.pets_rounded,
                            size: 48,
                            color: AppColors.grey,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No pets registered',
                            style: GoogleFonts.montserrat(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppDarkColors.subtext
                                  : AppColors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...result.pets.map(
                    (pet) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _PetCard(pet: pet, isDark: isDark, cs: cs),
                    ),
                  ),

                // Bookings at this clinic
                if (result.bookings.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _ClinicSectionHeader(
                    title: 'APPOINTMENTS',
                    icon: Icons.calendar_month_rounded,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  ...result.bookings.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ScanBookingRow(booking: b, isDark: isDark),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Pet card ──────────────────────────────────────────────────────────────────

class _PetCard extends StatelessWidget {
  final ClinicPet pet;
  final bool isDark;
  final ColorScheme cs;

  const _PetCard({required this.pet, required this.isDark, required this.cs});

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppDarkColors.surface : AppColors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pet header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _PetAvatarCircle(
                  photoUrl: pet.photoUrl != null
                      ? '${ApiConstants.baseUrl}${pet.photoUrl}'
                      : null,
                  name: pet.name,
                  size: 52,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet.name,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppDarkColors.text
                                  : AppColors.text,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (pet.breed != null || pet.species != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (pet.species != null)
                              pet.species![0].toUpperCase() +
                                  pet.species!.substring(1),
                            if (pet.breed != null) pet.breed!,
                          ].join(' · '),
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: isDark
                                ? AppDarkColors.subtext
                                : AppColors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (pet.vaxCardUrl != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          '💉 Vax ✓',
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    if (pet.computedAge != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${pet.computedAge!} yrs',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: isDark
                              ? AppDarkColors.subtext
                              : AppColors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Additional info row
          if (pet.weightKg != null || pet.sex != null || pet.notes != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (pet.sex != null)
                    _InfoChip(
                      label: pet.sex![0].toUpperCase() + pet.sex!.substring(1),
                      isDark: isDark,
                    ),
                  if (pet.weightKg != null)
                    _InfoChip(
                      label: '${pet.weightKg!.toStringAsFixed(1)} kg',
                      isDark: isDark,
                    ),
                ],
              ),
            ),

          // Per-pet session balances
          if (pet.petServices.isNotEmpty) ...[
            Divider(
              height: 1,
              color: isDark ? AppDarkColors.border : AppColors.greyLight,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.event_available_rounded,
                    size: 14,
                    color: isDark ? AppDarkColors.subtext : AppColors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'PET SESSIONS',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppDarkColors.subtext : AppColors.grey,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                children: pet.petServices
                    .map(
                      (svc) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _PetSessionRow(service: svc, isDark: isDark),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],

          // Service history divider
          Divider(
            height: 1,
            color: isDark ? AppDarkColors.border : AppColors.greyLight,
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 15,
                  color: isDark ? AppDarkColors.subtext : AppColors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  'SERVICE HISTORY',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppDarkColors.subtext : AppColors.grey,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Text(
                  '${pet.serviceLogs.length} visit${pet.serviceLogs.length == 1 ? '' : 's'}',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    color: isDark ? AppDarkColors.subtext : AppColors.grey,
                  ),
                ),
              ],
            ),
          ),

          if (pet.serviceLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                'No service history yet.',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  color: isDark ? AppDarkColors.subtext : AppColors.grey,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                children: pet.serviceLogs.map((log) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.navy.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.medical_services_rounded,
                            size: 16,
                            color: AppColors.navy.withValues(alpha: 0.65),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log.serviceTypeName,
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppDarkColors.text
                                      : AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                _formatDate(log.loggedAt.toLocal()),
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppDarkColors.subtext
                                      : AppColors.grey,
                                ),
                              ),
                              if (log.notes != null &&
                                  log.notes!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  log.notes!,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppDarkColors.subtext
                                        : AppColors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final bool isDark;
  const _InfoChip({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppDarkColors.elevated : AppColors.greyLight,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: GoogleFonts.montserrat(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? AppDarkColors.subtext : AppColors.grey,
        ),
      ),
    );
  }
}

// ── Valid member stamp (full-width green banner) ───────────────────────────

class _ValidMemberStamp extends StatelessWidget {
  final String memberName;
  final String? planType;
  const _ValidMemberStamp({required this.memberName, this.planType});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.success,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VALID MEMBER',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  memberName,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          if (planType != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                planType!,
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Pet avatar with initials fallback ─────────────────────────────────────

class _PetAvatarCircle extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double size;
  const _PetAvatarCircle({required this.name, this.photoUrl, this.size = 52});

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final cacheSize = (size * dpr).ceil();
      return ClipOval(
        child: Image.network(
          photoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: cacheSize,
          cacheHeight: cacheSize,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.navyLight,
              ),
            );
          },
          errorBuilder: (context, e, s) => _initial(),
        ),
      );
    }
    return _initial();
  }

  Widget _initial() {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.navyLight,
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.4,
          fontFamily: 'Montserrat',
        ),
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────

class _ClinicSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isDark;
  const _ClinicSectionHeader({
    required this.title,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: isDark ? AppDarkColors.subtext : AppColors.grey,
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark ? AppDarkColors.subtext : AppColors.grey,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

// ── Member-level session row ───────────────────────────────────────────────

class _SessionRow extends StatelessWidget {
  final ClinicMemberService service;
  final bool isDark;
  const _SessionRow({required this.service, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final remaining = service.remainingSessions;
    final total = service.totalSessions;
    final hasRemaining = remaining > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppDarkColors.surface : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasRemaining
              ? AppColors.success.withValues(alpha: 0.4)
              : (isDark ? AppDarkColors.border : AppColors.greyLight),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: hasRemaining
                  ? AppColors.success.withValues(alpha: 0.1)
                  : (isDark ? AppDarkColors.elevated : AppColors.greyLight),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              hasRemaining ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 20,
              color: hasRemaining ? AppColors.success : AppColors.grey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              service.serviceTypeName,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppDarkColors.text : AppColors.text,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$remaining / $total',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: hasRemaining ? AppColors.success : AppColors.grey,
                ),
              ),
              Text(
                'remaining',
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  color: AppColors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Per-pet session row ────────────────────────────────────────────────────

class _PetSessionRow extends StatelessWidget {
  final ClinicPetService service;
  final bool isDark;
  const _PetSessionRow({required this.service, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final remaining = service.remainingSessions;
    final total = service.totalSessions;
    final hasRemaining = remaining > 0;

    return Row(
      children: [
        Icon(
          hasRemaining
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 14,
          color: hasRemaining ? AppColors.success : AppColors.grey,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            service.serviceTypeName,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? AppDarkColors.text : AppColors.text,
            ),
          ),
        ),
        Text(
          '$remaining / $total sessions',
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: hasRemaining ? AppColors.success : AppColors.grey,
          ),
        ),
      ],
    );
  }
}

// ── Schedule tab ─────────────────────────────────────────────────────────────

class _ScheduleTab extends StatefulWidget {
  const _ScheduleTab();

  @override
  State<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<_ScheduleTab> {
  // 0 = Today, 1 = Tomorrow, 2 = All
  int _filterIndex = 0;

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String _tomorrowStr() {
    final t = DateTime.now().add(const Duration(days: 1));
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  String? get _dateFilter {
    if (_filterIndex == 0) return _todayStr();
    if (_filterIndex == 1) return _tomorrowStr();
    return null;
  }

  void _fetch() {
    context.read<ClinicBloc>().add(ClinicScheduleRequested(date: _dateFilter));
  }

  void _setFilter(int i) {
    setState(() => _filterIndex = i);
    context.read<ClinicBloc>().add(
      ClinicScheduleRequested(
        date: i == 0
            ? _todayStr()
            : i == 1
            ? _tomorrowStr()
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ClinicHeader(title: 'SCHEDULE', subtitle: 'Booking Appointments'),
          _buildFilterRow(isDark),
          Expanded(
            child: BlocConsumer<ClinicBloc, ClinicState>(
              listenWhen: (_, curr) => curr is ClinicBookingActionError,
              listener: (context, state) {
                if (state is ClinicBookingActionError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              },
              buildWhen: (prev, curr) =>
                  curr is ClinicScheduleLoading ||
                  curr is ClinicScheduleLoaded ||
                  curr is ClinicScheduleError,
              builder: (context, state) {
                if (state is ClinicScheduleLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.navy),
                  );
                }
                if (state is ClinicScheduleError) {
                  return _buildError(state.message, isDark);
                }
                if (state is ClinicScheduleLoaded) {
                  if (state.bookings.isEmpty) {
                    return _buildEmpty(isDark);
                  }
                  return RefreshIndicator(
                    color: AppColors.navy,
                    onRefresh: () async => _fetch(),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: state.bookings.length,
                      itemBuilder: (_, i) =>
                          _BookingCard(booking: state.bookings[i]),
                    ),
                  );
                }
                // Initial state — waiting for first tab visit
                return _buildEmpty(isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(bool isDark) {
    final labels = ['Today', 'Tomorrow', 'All'];
    return Container(
      color: isDark ? AppDarkColors.surface : AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isActive = _filterIndex == i;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _setFilter(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.navy : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isActive
                        ? AppColors.navy
                        : isDark
                        ? AppDarkColors.border
                        : AppColors.greyLight,
                  ),
                ),
                child: Text(
                  labels[i],
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? AppColors.white
                        : isDark
                        ? AppDarkColors.text
                        : AppColors.grey,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 48,
            color: isDark ? AppDarkColors.subtext : AppColors.greyLight,
          ),
          const SizedBox(height: 12),
          Text(
            'No bookings scheduled',
            style: GoogleFonts.montserrat(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? AppDarkColors.text : AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Switch to "All" to see every upcoming appointment.',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 13,
              color: isDark ? AppDarkColors.subtext : AppColors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: isDark ? AppDarkColors.subtext : AppColors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: isDark ? AppDarkColors.text : AppColors.text,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _fetch,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scan booking row (read-only — shown in scan result) ───────────────────────

class _ScanBookingRow extends StatelessWidget {
  final ClinicBooking booking;
  final bool isDark;
  const _ScanBookingRow({required this.booking, required this.isDark});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusLabel;
    switch (booking.status) {
      case 'confirmed':
        statusColor = AppColors.success;
        statusLabel = 'Confirmed';
      case 'cancelled':
        statusColor = AppColors.grey;
        statusLabel = 'Cancelled';
      default:
        statusColor = const Color(0xFFD97706);
        statusLabel = 'Pending';
    }

    final d = booking.bookingDate;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppDarkColors.bg : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppDarkColors.border : AppColors.greyLight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.serviceTypeName,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppDarkColors.text : AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$dateStr · ${booking.timeSlot}',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: isDark ? AppDarkColors.subtext : AppColors.grey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              statusLabel,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Booking card (schedule tab — with confirm/cancel actions) ─────────────────

class _BookingCard extends StatelessWidget {
  final ClinicBooking booking;
  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color statusColor;
    String statusLabel;
    switch (booking.status) {
      case 'confirmed':
        statusColor = AppColors.success;
        statusLabel = 'Confirmed';
      case 'cancelled':
        statusColor = AppColors.grey;
        statusLabel = 'Cancelled';
      default:
        statusColor = const Color(0xFFD97706);
        statusLabel = 'Pending';
    }

    return BlocBuilder<ClinicBloc, ClinicState>(
      buildWhen: (prev, curr) =>
          curr is ClinicBookingActionInProgress ||
          curr is ClinicScheduleLoaded ||
          curr is ClinicBookingActionError,
      builder: (context, state) {
        final isLoading =
            state is ClinicBookingActionInProgress &&
            state.bookingId == booking.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? AppDarkColors.surface : AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppDarkColors.border : AppColors.greyLight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time column
                    Container(
                      width: 60,
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? AppDarkColors.bg : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        booking.timeSlot,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Details column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  booking.member.fullName,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppDarkColors.text
                                        : AppColors.text,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            booking.serviceTypeName,
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppDarkColors.subtext
                                  : AppColors.grey,
                            ),
                          ),
                          if (booking.notes != null &&
                              booking.notes!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              booking.notes!,
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: isDark
                                    ? AppDarkColors.subtext
                                    : AppColors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                // Confirm / Cancel actions for pending bookings
                if (booking.status == 'pending') ...[
                  const SizedBox(height: 12),
                  if (isLoading)
                    const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.navy,
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _BookingActionButton(
                            label: 'Confirm',
                            color: AppColors.success,
                            onTap: () => context.read<ClinicBloc>().add(
                              ClinicBookingConfirmRequested(booking.id),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _BookingActionButton(
                            label: 'Decline',
                            color: AppColors.grey,
                            onTap: () => context.read<ClinicBloc>().add(
                              ClinicBookingCancelRequested(booking.id),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BookingActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _BookingActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ── Clinic bottom nav bar ─────────────────────────────────────────────────────

class _ClinicNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onQrTap;

  const _ClinicNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.onQrTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppColors.gold : AppColors.navy;
    final inactiveColor = isDark ? AppDarkColors.subtext : AppColors.grey;
    final bgColor = isDark ? AppDarkColors.surface : AppColors.white;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    const barH = 64.0;
    const fabSize = 52.0;
    const overhang = 16.0;

    Widget buildTab(
      int index,
      IconData icon,
      IconData selectedIcon,
      String label,
    ) {
      final isSelected = index == currentIndex;
      return Expanded(
        child: InkWell(
          onTap: () => onTap(index),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomPad),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: isSelected ? 1.0 : 0.0,
                  child: Container(
                    width: 20,
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: activeColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Icon(
                  isSelected ? selectedIcon : icon,
                  size: 22,
                  color: isSelected ? activeColor : inactiveColor,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? activeColor : inactiveColor,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: barH + bottomPad + overhang,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Bar floor
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: barH + bottomPad,
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  buildTab(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
                  const SizedBox(width: fabSize + 8),
                  buildTab(
                    1,
                    Icons.person_outline_rounded,
                    Icons.person_rounded,
                    'Account',
                  ),
                ],
              ),
            ),
          ),
          // Center raised scanner button
          Positioned(
            top: 0,
            child: GestureDetector(
              onTap: onQrTap,
              child: Container(
                width: fabSize,
                height: fabSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.navy,
                  border: Border.all(color: bgColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navy.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Clinic account tab ────────────────────────────────────────────────────────

class _ClinicAccountTab extends StatelessWidget {
  const _ClinicAccountTab();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ClinicHeader(subtitle: 'Account'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Role identity card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.gold, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.local_hospital_rounded,
                          color: AppColors.gold,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Partner Clinic',
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              'Verified Partner',
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.gold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Appearance section
                _ClinicAccountSection(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.contrast_outlined,
                                size: 20,
                                color: cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Appearance',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: cs.onSurface),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          BlocBuilder<ThemeCubit, ThemeMode>(
                            builder: (context, mode) =>
                                SegmentedButton<ThemeMode>(
                                  style: SegmentedButton.styleFrom(
                                    selectedBackgroundColor: AppColors.navy,
                                    selectedForegroundColor: Colors.white,
                                    backgroundColor: cs.surfaceContainerHighest,
                                    foregroundColor: cs.onSurfaceVariant,
                                    textStyle: const TextStyle(fontSize: 13),
                                  ),
                                  segments: const [
                                    ButtonSegment(
                                      value: ThemeMode.light,
                                      label: Text('Light'),
                                      icon: Icon(
                                        Icons.light_mode_outlined,
                                        size: 15,
                                      ),
                                    ),
                                    ButtonSegment(
                                      value: ThemeMode.system,
                                      label: Text('System'),
                                      icon: Icon(
                                        Icons.brightness_auto_outlined,
                                        size: 15,
                                      ),
                                    ),
                                    ButtonSegment(
                                      value: ThemeMode.dark,
                                      label: Text('Dark'),
                                      icon: Icon(
                                        Icons.dark_mode_outlined,
                                        size: 15,
                                      ),
                                    ),
                                  ],
                                  selected: {mode},
                                  onSelectionChanged: (selected) => context
                                      .read<ThemeCubit>()
                                      .setMode(selected.first),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Sign out
                _ClinicAccountSection(
                  children: [
                    _ClinicAccountRow(
                      icon: Icons.logout,
                      label: 'Sign out',
                      value: '',
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Sign out?'),
                            content: const Text(
                              "You'll need to sign in again to access your partner account.",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.error,
                                ),
                                child: const Text('Sign out'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true && context.mounted) {
                          context.read<AuthBloc>().add(AuthLogoutRequested());
                        }
                      },
                      destructive: true,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Account section container ─────────────────────────────────────────────────

class _ClinicAccountSection extends StatelessWidget {
  final List<Widget> children;
  const _ClinicAccountSection({required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: children
            .expand(
              (w) => [
                w,
                if (w != children.last)
                  Divider(height: 1, indent: 52, color: cs.outline),
              ],
            )
            .toList(),
      ),
    );
  }
}

// ── Account row ───────────────────────────────────────────────────────────────

class _ClinicAccountRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool destructive;

  const _ClinicAccountRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textColor = destructive ? cs.error : cs.onSurface;
    final iconColor = destructive ? cs.error : cs.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: textColor),
              ),
            ),
            if (value.isNotEmpty)
              Flexible(
                child: Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Clinic home tab ───────────────────────────────────────────────────────────

class _ClinicHomeTab extends StatefulWidget {
  final VoidCallback onScanTap;

  const _ClinicHomeTab({required this.onScanTap});

  @override
  State<_ClinicHomeTab> createState() => _ClinicHomeTabState();
}

class _ClinicHomeTabState extends State<_ClinicHomeTab> {
  int _filterIndex = 0;

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String _tomorrowStr() {
    final t = DateTime.now().add(const Duration(days: 1));
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  String? get _dateFilter {
    if (_filterIndex == 0) return _todayStr();
    if (_filterIndex == 1) return _tomorrowStr();
    return null;
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _setFilter(int i) {
    setState(() => _filterIndex = i);
    context.read<ClinicBloc>().add(
      ClinicScheduleRequested(
        date: i == 0
            ? _todayStr()
            : i == 1
            ? _tomorrowStr()
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const filterLabels = ['Today', 'Tomorrow', 'All'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ClinicHeader(subtitle: 'Partner Dashboard'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting
                Text(
                  _greeting(),
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grey,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Partner Clinic',
                  style: GoogleFonts.montserrat(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppDarkColors.text : AppColors.text,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 24),

                // Scan Member CTA
                GestureDetector(
                  onTap: widget.onScanTap,
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.qr_code_scanner_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Scan Member',
                                style: GoogleFonts.montserrat(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Look up a pet record by QR code',
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.65),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Appointments section header
                Row(
                  children: [
                    Text(
                      'APPOINTMENTS',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.grey,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.read<ClinicBloc>().add(
                        ClinicScheduleRequested(date: _dateFilter),
                      ),
                      child: const Icon(
                        Icons.refresh_rounded,
                        color: AppColors.grey,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Filter pills
                Row(
                  children: List.generate(filterLabels.length, (i) {
                    final isActive = _filterIndex == i;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => _setFilter(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.navy
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: isActive
                                  ? AppColors.navy
                                  : isDark
                                  ? AppDarkColors.border
                                  : AppColors.greyLight,
                            ),
                          ),
                          child: Text(
                            filterLabels[i],
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? AppColors.white
                                  : isDark
                                  ? AppDarkColors.text
                                  : AppColors.grey,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),

                // Booking list
                BlocBuilder<ClinicBloc, ClinicState>(
                  buildWhen: (_, curr) =>
                      curr is ClinicScheduleLoading ||
                      curr is ClinicScheduleLoaded ||
                      curr is ClinicScheduleError,
                  builder: (context, state) {
                    if (state is ClinicScheduleLoading) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.navy,
                          ),
                        ),
                      );
                    }
                    if (state is ClinicScheduleError) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 36,
                                color: AppColors.grey,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                state.message,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  color: AppColors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    if (state is ClinicScheduleLoaded) {
                      if (state.bookings.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 40,
                                  color: isDark
                                      ? AppDarkColors.subtext
                                      : AppColors.greyLight,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'No bookings scheduled',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppDarkColors.text
                                        : AppColors.text,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Switch to "All" to see every upcoming appointment.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppDarkColors.subtext
                                        : AppColors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: state.bookings
                            .map((b) => _BookingCard(booking: b))
                            .toList(),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
