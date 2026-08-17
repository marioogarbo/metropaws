import 'dart:async';
import 'dart:math' as math;

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'theme.dart';
import 'core/blocs/theme_cubit.dart';
import 'core/services/theme_storage.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_event.dart';
import 'features/auth/bloc/auth_state.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/member/screens/member_dashboard_screen.dart';
import 'features/admin/screens/scanner_screen.dart';
import 'features/clinic/screens/clinic_scanner_screen.dart';
import 'features/payments/payment_deep_link.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Wrap secure storage read in try-catch so that a Keystore failure on
  // certain Android devices (OEM custom ROMs, corrupted Keystore) doesn't
  // prevent runApp() from being called — which would leave users on a
  // permanent white screen instead of reaching the login page.
  ThemeMode initialTheme = ThemeMode.system;
  try {
    initialTheme = await ThemeStorage.getThemeMode();
  } catch (_) {
    // Fall back to system theme; user can change it after launch.
  }
  runApp(MetroPawsApp(initialTheme: initialTheme));
}

class MetroPawsApp extends StatefulWidget {
  final ThemeMode initialTheme;
  const MetroPawsApp({super.key, required this.initialTheme});

  @override
  State<MetroPawsApp> createState() => _MetroPawsAppState();
}

class _MetroPawsAppState extends State<MetroPawsApp> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    final initial = await _appLinks.getInitialLink();
    if (initial != null) PaymentDeepLinkChannel.tryHandle(initial);
    _linkSub = _appLinks.uriLinkStream.listen(PaymentDeepLinkChannel.tryHandle);
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthBloc()..add(AuthCheckRequested())),
        BlocProvider(create: (_) => ThemeCubit(widget.initialTheme)),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) => MaterialApp(
          title: 'MetroPaws',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          // LIGHT ONLY (client decision, 2026-08-17), regardless of the
          // device setting or anything previously saved. The dark theme and
          // ThemeCubit are kept wired but unused: dark mode is finished work
          // that may come back, and deleting it would mean rebuilding every
          // dark-surface decision. To restore, put `themeMode` back here and
          // unhide the Appearance pickers.
          themeMode: ThemeMode.light,
          // The design deliberately runs large type (28–48sp display sizes).
          // A device set to an aggressive system font scale (Samsung's "Huge"
          // / accessibility scaling can reach ~1.5–2.0×) multiplies that past
          // the point where headings, numbers and labels fit — especially on
          // narrow screens (e.g. a folded Galaxy Flip). Cap the effective
          // scale so an extreme system setting can't shatter the layout, while
          // still honouring meaningful enlargement (up to 1.3×) and any
          // smaller-text preference. This is the app-wide safety net; specific
          // screens still use Flexible/Wrap/ellipsis for the width axis.
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            minScaleFactor: 0.8,
            maxScaleFactor: 1.3,
            child: child!,
          ),
          home: const _AuthGate(),
        ),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          // Reset to system theme on logout so the login screen respects the
          // phone's current system setting rather than a stale in-app choice.
          context.read<ThemeCubit>().setMode(ThemeMode.system);
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            if (state.role == 'admin') return const ScannerScreen();
            if (state.role == 'clinic') return const ClinicScannerScreen();
            return const MemberDashboardScreen();
          }
          if (state is AuthInitial ||
              state is AuthLoading ||
              state is AuthRegistrationComplete) {
            return const _SplashScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _taglineFade;
  late final Animation<double> _dotsFade;
  late final bool _reduceMotion;
  Timer? _stageTimer1;
  Timer? _stageTimer2;
  int _stage = 0;

  @override
  void initState() {
    super.initState();
    _reduceMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      value: _reduceMotion ? 1.0 : 0.0,
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    // Logo pops in first, tagline and dots follow in sequence so the brand
    // mark reads as a deliberate reveal rather than everything arriving at once.
    _logoFade = CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutQuart),
      ),
    );
    _taglineFade = CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    _dotsFade = CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );
    if (!_reduceMotion) {
      _enterCtrl.forward();
      _pulseCtrl.repeat();
    }
    // The backend can cold-start slowly (free-tier spin-down); reassure
    // instead of leaving the screen looking frozen on a slow connection.
    _stageTimer1 = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _stage = 1);
    });
    _stageTimer2 = Timer(const Duration(seconds: 13), () {
      if (mounted) setState(() => _stage = 2);
    });
  }

  @override
  void dispose() {
    _stageTimer1?.cancel();
    _stageTimer2?.cancel();
    _enterCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  double _dotOpacity(double t, int i) {
    final phase = i / 3.0;
    final v = ((t - phase) % 1.0 + 1.0) % 1.0;
    return (0.25 + 0.75 * math.sin(v * math.pi)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 5),
            FadeTransition(
              opacity: _logoFade,
              child: ScaleTransition(
                scale: _logoScale,
                child: AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (context, child) {
                    final glow =
                        (math.sin(_pulseCtrl.value * 2 * math.pi) + 1) / 2;
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(
                              alpha: 0.06 + glow * 0.10,
                            ),
                            blurRadius: 60 + glow * 24,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: Image.asset(
                    'assets/images/logo-full-white-metro.png',
                    width: 180,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            FadeTransition(
              opacity: _taglineFade,
              child: Text(
                'PREMIUM PET CARE',
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                  color: AppColors.white.withValues(alpha: 0.62),
                  letterSpacing: 3.0,
                ),
              ),
            ),
            const Spacer(flex: 6),
            FadeTransition(
              opacity: _dotsFade,
              child: _reduceMotion
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (i) => _dot(0.6)),
                    )
                  : AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (context, _) => Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          3,
                          (i) => _dot(_dotOpacity(_pulseCtrl.value, i)),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 18,
              child: AnimatedOpacity(
                duration: _reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                opacity: _stage > 0 ? 1.0 : 0.0,
                child: Text(
                  _stage >= 2
                      ? 'Thanks for your patience, almost there.'
                      : 'Just a moment...',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    color: AppColors.white.withValues(alpha: 0.55),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _dot(double opacity) {
    return Opacity(
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.gold,
        ),
      ),
    );
  }
}
