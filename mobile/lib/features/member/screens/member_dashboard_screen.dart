import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderProxyBox;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../bloc/member_bloc.dart';
import '../bloc/member_event.dart';
import '../bloc/member_state.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/models/booking.dart';
import '../../../core/models/clinic_partner.dart';
import '../../../core/models/member.dart';
import '../../../core/models/paw_points.dart';
import '../../../core/models/reimbursement.dart';
import '../../../core/services/api_service.dart';
import '../../../core/models/pet.dart';
import '../../../core/widgets/mp_button.dart';
import '../../../core/widgets/paw_points_strip.dart';
import '../../../core/widgets/pet_avatar.dart';
import '../../../core/widgets/tier_badge.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_event.dart';
import '../../../theme.dart';
import 'add_pet_screen.dart';
import 'pet_form_screen.dart';
import 'payout_details_screen.dart';
import 'benefits_screen.dart';
import 'events_screen.dart';
import 'notifications_screen.dart';
import 'paw_points_screen.dart';
import 'pet_profile_screen.dart';
import 'plan_selection_screen.dart';
import 'reimbursement_screen.dart';

/// Height the floating nav overlays: bar (62) + lifted action (16) + the
/// margin under it. Scrollables add this so nothing ends up unreachable
/// beneath the capsule.
const double kNavClearance = 96;

String _capFirst(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _formatDate(DateTime d) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
  return '${weekdays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
}

/// Home and Account render the member profile from the SHARED [MemberBloc],
/// which also serves wallet, promos, notifications, bookings and PawPoints —
/// including a notification-count poll that fires every 60s for the whole life
/// of the shell. Those tabs must rebuild ONLY for member-lifecycle states:
/// without this filter they rebuild on every unrelated emission, and because a
/// [MemberFailure] is not cached the way a loaded member is, the next unrelated
/// state (`NotificationsCount`, `MobileConfigLoaded`, `ReimbursementLoaded`, …)
/// flips `state is MemberFailure` back to false and collapses the error view
/// into a PERMANENT loading skeleton — the profile then never surfaces its own
/// failure or Retry button. Gating rebuilds here keeps a failure (and a loaded
/// member) on screen regardless of the churn from the other tabs.
bool _isMemberProfileState(MemberState s) =>
    s is MemberInitial ||
    s is MemberLoading ||
    s is MemberLoaded ||
    s is MemberFailure ||
    s is PetOperationSuccess ||
    s is PayoutSaveSuccess ||
    s is ProfilePhotoSaveSuccess;

class MemberDashboardScreen extends StatelessWidget {
  const MemberDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MemberBloc()
        ..add(MemberLoadRequested())
        ..add(MobileConfigRequested()),
      child: const _MemberShell(),
    );
  }
}

class _MemberShell extends StatefulWidget {
  const _MemberShell();

  @override
  State<_MemberShell> createState() => _MemberShellState();
}

class _MemberShellState extends State<_MemberShell> {
  int _currentIndex = 0;
  // Slot 2 is flag-driven: the Book tab when booking_enabled is ON, otherwise
  // the Events & Promos tab. Default false (Events) is the safe state and
  // matches the backend default — no clinic-booking UI shows until partner
  // clinics exist. Sourced from MobileConfigRequested (dispatched at bloc
  // creation) via the MobileConfigLoaded state. Keep this in lockstep with
  // _MpNavBar's slot-2 nav item.
  bool _bookingEnabled = false;
  int _unreadNotifications = 0;
  Timer? _notifTimer;

  @override
  void initState() {
    super.initState();
    // Unread-count badge on the bell: fetch once, then poll every 60s while the
    // shell is alive. Timer cancelled in dispose. (No push/FCM yet — polling
    // only, so nothing fires while the app is closed; email covers that.)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<MemberBloc>().add(NotificationsCountRequested());
      }
    });
    _notifTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) {
        context.read<MemberBloc>().add(NotificationsCountRequested());
      }
    });
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MemberBloc, MemberState>(
      listenWhen: (_, current) =>
          current is MobileConfigLoaded || current is NotificationsCount,
      listener: (context, state) {
        if (state is MobileConfigLoaded &&
            state.bookingEnabled != _bookingEnabled) {
          setState(() => _bookingEnabled = state.bookingEnabled);
        } else if (state is NotificationsCount &&
            state.unread != _unreadNotifications) {
          setState(() => _unreadNotifications = state.unread);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          // The app bar is navy in both themes now, so the white wordmark is
          // unconditional — the light/dark branch here was picking a navy
          // wordmark for a navy bar.
          title: Image.asset(
            'assets/images/logo-full-white-metro.png',
            height: 40,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
          ),
          actions: [
            Badge.count(
              count: _unreadNotifications,
              isLabelVisible: _unreadNotifications > 0,
              child: IconButton(
                icon: const Icon(Icons.notifications_outlined),
                color: AppColors.white,
                tooltip: 'Notifications',
                onPressed: () async {
                  final bloc = context.read<MemberBloc>();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: bloc,
                        child: const NotificationsScreen(),
                      ),
                    ),
                  );
                  // Some may now be read — refresh the badge on return.
                  if (mounted) bloc.add(NotificationsCountRequested());
                },
              ),
            ),
          ],
        ),
        // The capsule floats OVER the content rather than sitting in a
        // reserved strip beneath it — the page runs under it and stays
        // partly visible, which is what makes it read as a floating object.
        // Every scrollable below therefore ends with kNavClearance of
        // padding so its last item can still be scrolled clear of the bar.
        extendBody: true,
        body: Stack(
          children: [
            IndexedStack(
              index: _currentIndex,
              children: [
                _HomeTab(bookingEnabled: _bookingEnabled),
                _bookingEnabled ? const _BookTab() : const EventsTab(),
                const BenefitsTab(),
                const _AccountTab(),
              ],
            ),
            // Fades content out as it scrolls under the capsule. Stops at
            // 88% rather than solid: the page staying partly visible behind
            // the bar is the whole point of extendBody, and an opaque scrim
            // would just be the reserved strip again, drawn differently.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 110,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Theme.of(
                          context,
                        ).scaffoldBackgroundColor.withValues(alpha: 0),
                        Theme.of(
                          context,
                        ).scaffoldBackgroundColor.withValues(alpha: 0.88),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _MpNavBar(
          currentIndex: _currentIndex,
          bookingEnabled: _bookingEnabled,
          onTap: (i) => setState(() => _currentIndex = i),
          onClaim: _openClaim,
        ),
      ),
    );
  }

  /// The raised nav action: open the reimbursement Submit form directly,
  /// sharing the shell's MemberBloc. Refresh the wallet on return so a new
  /// claim's pending amount shows on the Wallet tab and Home card.
  Future<void> _openClaim() async {
    final bloc = context.read<MemberBloc>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: const ReimbursementScreen(initialTab: 1), // Submit
        ),
      ),
    );
    if (mounted) bloc.add(ReimbursementsLoadRequested());
  }
}

// ── Tabs ───────────────────────────────────────────────────────────────────

class _HomeTab extends StatefulWidget {
  final bool bookingEnabled;
  const _HomeTab({this.bookingEnabled = false});
  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  Member? _member;
  // Cached separately from the volatile bloc state so the view renders from
  // these fields, not from `state is X`. That keeps the masking fix intact
  // (see [_isMemberProfileState]) even though we now also rebuild on
  // ReimbursementLoaded to pick up the pet card's Benefit Wallet numbers.
  Wallet? _wallet;
  PawPointsBalance? _pawPoints;
  String? _failure;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlocConsumer<MemberBloc, MemberState>(
      // Member-lifecycle states drive the view; ReimbursementLoaded only
      // refreshes the cached wallet (booking/sessions are on standby — the pet
      // card now shows the Benefit Wallet). Other shared-bloc churn is ignored
      // so a MemberFailure never collapses back into a skeleton.
      buildWhen: (_, state) =>
          _isMemberProfileState(state) ||
          state is ReimbursementLoaded ||
          state is PawPointsLoaded,
      listenWhen: (_, state) =>
          state is MemberLoaded ||
          state is PetOperationSuccess ||
          state is PetOperationFailure,
      listener: (context, state) {
        if (state is MemberLoaded) {
          // Source the Home extras off the shared bloc (no new endpoints):
          // the pet card's per-pet Benefit Wallet + the PawPoints strip balance.
          context.read<MemberBloc>().add(ReimbursementsLoadRequested());
          context.read<MemberBloc>().add(PawPointsBalanceLoadRequested());
        }
        if (state is PetOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.pets_rounded, size: 18, color: AppColors.text),
                  const SizedBox(width: 10),
                  Expanded(child: Text(state.message)),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.gold,
              duration: const Duration(seconds: 3),
            ),
          );
        } else if (state is PetOperationFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              behavior: SnackBarBehavior.floating,
              backgroundColor: cs.error,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is MemberLoaded) {
          _member = state.member;
          _failure = null;
        }
        if (state is PetOperationSuccess) _member = state.member;
        if (state is MemberFailure) _failure = state.message;
        if (state is ReimbursementLoaded) _wallet = state.wallet;
        if (state is PawPointsLoaded) _pawPoints = state.balance;

        Widget child;
        if (_member != null) {
          child = _Dashboard(
            key: const ValueKey('dashboard'),
            member: _member!,
            wallet: _wallet,
            pawPoints: _pawPoints,
            bookingEnabled: widget.bookingEnabled,
          );
        } else if (_failure != null) {
          child = _ErrorView(
            key: const ValueKey('error'),
            message: _failure!,
            onRetry: () =>
                context.read<MemberBloc>().add(MemberLoadRequested()),
          );
        } else {
          child = const _DashboardSkeleton(key: ValueKey('loading'));
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: child,
        );
      },
    );
  }
}

class _BookTab extends StatefulWidget {
  const _BookTab();

  @override
  State<_BookTab> createState() => _BookTabState();
}

class _BookTabState extends State<_BookTab> {
  Member? _member;
  List<Booking> _bookings = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MemberBloc>().add(BookingsLoadRequested());
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MemberBloc, MemberState>(
      listener: (context, state) {
        if (state is BookingSubmitSuccess) {
          final petName = _member?.pets.length == 1
              ? _capFirst(_member!.pets.first.name)
              : null;
          final svc = state.booking.serviceType.name;
          final msg = petName != null
              ? "$petName's $svc is booked for ${state.booking.timeSlot}."
              : '$svc booked for ${state.booking.timeSlot}.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.pets_rounded,
                    size: 18,
                    color: AppColors.text,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      msg,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.gold,
              duration: const Duration(seconds: 3),
            ),
          );
          context.read<MemberBloc>().add(BookingsLoadRequested());
        } else if (state is BookingSubmitFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_friendlyBookingError(state.message)),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        } else if (state is BookingCancelSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Booking cancelled.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.read<MemberBloc>().add(BookingsLoadRequested());
        } else if (state is BookingCancelFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is MemberLoaded) _member = state.member;
        if (state is PetOperationSuccess) _member = state.member;
        if (state is BookingsLoaded) _bookings = state.bookings;

        if (_member == null) {
          if (state is MemberLoading || state is MemberInitial) {
            return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            );
          }
          if (state is MemberFailure) {
            return _ErrorView(
              message: state.message,
              onRetry: () =>
                  context.read<MemberBloc>().add(MemberLoadRequested()),
            );
          }
          return const SizedBox.shrink();
        }

        return _BookingView(
          member: _member!,
          bookings: _bookings,
          isSubmitting: state is BookingSubmitting,
          isFailure: state is BookingSubmitFailure,
        );
      },
    );
  }

  String _friendlyBookingError(String raw) {
    if (raw.toLowerCase().contains('slot') ||
        raw.toLowerCase().contains('time')) {
      return 'That time slot is no longer available. Please choose another.';
    }
    if (raw.toLowerCase().contains('session') ||
        raw.toLowerCase().contains('credit')) {
      return 'No sessions remaining for this service.';
    }
    return 'Could not submit your booking. Please try again.';
  }
}

class _AccountTab extends StatefulWidget {
  const _AccountTab();
  @override
  State<_AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<_AccountTab> {
  Member? _member;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MemberBloc, MemberState>(
      // Only member-lifecycle states may drive this tab — see
      // [_isMemberProfileState]. Otherwise the shared bloc's wallet/promo/
      // notification churn collapses a MemberFailure back into a skeleton.
      buildWhen: (_, state) => _isMemberProfileState(state),
      builder: (context, state) {
        if (state is MemberLoaded) _member = state.member;
        if (state is PetOperationSuccess) _member = state.member;
        if (state is PayoutSaveSuccess) _member = state.member;
        if (state is ProfilePhotoSaveSuccess) _member = state.member;
        if (_member != null) return _AccountView(member: _member!);
        if (state is MemberFailure) {
          return _ErrorView(
            message: state.message,
            onRetry: () =>
                context.read<MemberBloc>().add(MemberLoadRequested()),
          );
        }
        return const _AccountSkeleton();
      },
    );
  }
}

// ── Home / Dashboard ───────────────────────────────────────────────────────

class _Dashboard extends StatefulWidget {
  final Member member;
  final Wallet? wallet;
  final PawPointsBalance? pawPoints;
  final bool bookingEnabled;
  const _Dashboard({
    super.key,
    required this.member,
    this.wallet,
    this.pawPoints,
    this.bookingEnabled = false,
  });

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard>
    with SingleTickerProviderStateMixin {
  int _selectedPetIndex = 0;
  late final AnimationController _enterCtrl;
  late final Animation<double> _cardFade;
  late final Animation<Offset> _cardSlide;
  late final PageController _carouselCtrl;
  // Measured natural height of each pet card, so the carousel wraps its
  // content instead of a fixed frame (which left dead space under short cards
  // like the no-plan state). The container animates to the current card's
  // height on swipe. Seeded with a sensible default until the first measure.
  final Map<int, double> _cardHeights = {};
  static const double _defaultCardHeight = 440;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _cardFade = CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
    );
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _enterCtrl,
            curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
          ),
        );
    _carouselCtrl = PageController(
      initialPage: _selectedPetIndex,
      viewportFraction: 0.92,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        _enterCtrl.value = 1.0;
      } else {
        _enterCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _carouselCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_Dashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedPetIndex >= widget.member.pets.length) {
      setState(() => _selectedPetIndex = 0);
    }
  }

  static String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _showPetOptions(BuildContext context, Pet pet) {
    final bloc = context.read<MemberBloc>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _capFirst(pet.name),
                  style: Theme.of(ctx).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.pets_outlined),
                title: const Text('View profile'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openPetProfile(context, pet);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit pet'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: bloc,
                        child: PetFormScreen(pet: pet),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(ctx).colorScheme.error,
                ),
                title: Text(
                  'Remove pet',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  showDialog<void>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: Text('Remove ${_capFirst(pet.name)}?'),
                      content: Text(
                        'This will remove ${_capFirst(pet.name)} and their health records from your account.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(dCtx);
                            bloc.add(PetDeleteRequested(pet.id));
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(dCtx).colorScheme.error,
                          ),
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showDigitalPawprint(BuildContext context, {int petIndex = 0}) {
    final pets = widget.member.pets;
    final pet = pets.isNotEmpty && petIndex < pets.length
        ? pets[petIndex]
        : null;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DigitalPawprintSheet(
        qrToken: pet?.id ?? widget.member.qrToken,
        member: widget.member,
        pet: pet,
      ),
    );
  }

  /// This pet's Benefit Wallet pools, or null while the wallet is still loading
  /// / the fetch failed (the card then simply omits the wallet block).
  WalletPet? _walletFor(String petId) {
    for (final w in widget.wallet?.pets ?? const <WalletPet>[]) {
      if (w.petId == petId) return w;
    }
    return null;
  }

  /// Opens the reimbursement flow sharing the current [MemberBloc], then
  /// refreshes the wallet on return (a new claim changes the remaining balance).
  /// Mirrors the Benefits hub's push pattern (benefits_screen.dart).
  Future<void> _openReimbursements(
    BuildContext context, {
    required int initialTab,
  }) async {
    final bloc = context.read<MemberBloc>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: ReimbursementScreen(initialTab: initialTab),
        ),
      ),
    );
    if (mounted) bloc.add(ReimbursementsLoadRequested());
  }

  /// Opens the pet's full profile (view) — hero photo, membership, details,
  /// health records, and photo completion. Editing lives inside it (the app
  /// bar pencil). Shares the bloc; refreshes the member on return so any edit
  /// or photo added there shows on the dashboard.
  Future<void> _openPetProfile(BuildContext context, Pet pet) async {
    final bloc = context.read<MemberBloc>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: PetProfileScreen(pet: pet),
        ),
      ),
    );
    if (mounted) bloc.add(MemberLoadRequested());
  }

  /// Opens the full PawPoints history & rewards screen, sharing the bloc
  /// (same push pattern as the Benefits hub's PawPoints shortcut).
  void _openPawPoints(BuildContext context) {
    final bloc = context.read<MemberBloc>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BlocProvider.value(value: bloc, child: const PawPointsScreen()),
      ),
    );
  }

  /// Opens plan selection for a plan-less pet, sharing the current bloc. On
  /// return, reloads the profile (the payment safety-net grants a paid plan)
  /// and the wallet, so a freshly activated plan surfaces on the card.
  Future<void> _openPlanSelection(BuildContext context, Pet pet) async {
    final bloc = context.read<MemberBloc>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: PlanSelectionScreen(pet: pet),
        ),
      ),
    );
    if (mounted) {
      bloc.add(MemberLoadRequested());
      bloc.add(ReimbursementsLoadRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pets = widget.member.pets;

    Future<void> navigateToAddPet() async {
      final refreshed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const AddPetScreen()),
      );
      if (refreshed == true && context.mounted) {
        context.read<MemberBloc>().add(MemberLoadRequested());
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: kNavClearance),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Member header (navy) ────────────────────────────────────
          // One block, continuing the navy app bar down into the page
          // rather than restarting the surface under it. Greeting, name,
          // Founding badge, and PawPoints are all MEMBER-level facts, so
          // they read as one zone; previously they were three unrelated
          // things floating on cream with no boundary between "who you
          // are" and "your pets", which is what made the screen feel
          // structureless. The rounded foot is where the cream content
          // field begins — the navy box, cream lining, gold seal.
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The gold paw that used to sit here is gone: gold on navy
                // is 2.9:1, and it was one of ten gold marks on a screen
                // where gold is supposed to be the rarest thing.
                Text(
                  '${_timeGreeting()},',
                  style: tt.labelLarge?.copyWith(color: AppColors.onNavyMuted),
                ),
                const SizedBox(height: 2),
                // Plan tier deliberately does NOT appear here. It was the
                // HIGHEST tier across the member's pets, so someone with one
                // Premium pet and two Standard ones read as "Premium" — and a
                // monthly subscriber three payments in, with no benefits yet,
                // read as though they had the whole plan. Tier belongs to a
                // pet, and every pet card already carries its own badge.
                // Founding membership is genuinely member-level, so it stays.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.member.firstName,
                        style: tt.displaySmall?.copyWith(
                          color: AppColors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.member.isFoundingMember) ...[
                      const SizedBox(width: 12),
                      const _FoundingBadge.onNavy(),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.onNavyDivider,
                ),
                const SizedBox(height: 6),
                // PawPoints — balance at a glance + shortcut to history and
                // rewards. Inside the header it drops its own navy pill: a
                // navy card on a navy block is a container that draws nothing.
                PawPointsStrip.onNavy(
                  balance: widget.pawPoints,
                  onTap: () => _openPawPoints(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          // ── Pets ────────────────────────────────────────────────────
          // "Add pet" lives HERE, next to the thing it adds to, not orphaned
          // at the bottom of the page under the pagination dots where it read
          // as end-of-list chrome. Adding pet 2 and 3 is also where the Pack
          // Discount lives, so burying it was costing more than tidiness.
          if (pets.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      pets.length == 1 ? 'Your pet' : 'Your pets',
                      style: tt.headlineSmall,
                    ),
                  ),
                  _AddPetAction(onTap: navigateToAddPet),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          // ── Digital Pawprint carousel ────────────────────────────────
          FadeTransition(
            opacity: _cardFade,
            child: SlideTransition(
              position: _cardSlide,
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    height:
                        _cardHeights[_selectedPetIndex] ?? _defaultCardHeight,
                    child: PageView.builder(
                      controller: _carouselCtrl,
                      onPageChanged: (i) {
                        setState(() => _selectedPetIndex = i);
                      },
                      itemCount: pets.isEmpty ? 1 : pets.length,
                      itemBuilder: (ctx, i) {
                        // OverflowBox lets each card take its natural height so
                        // _MeasureSize can report it; the container then sizes
                        // to the current card. Top-aligned so shorter cards sit
                        // at the top rather than centering in leftover space.
                        Widget wrap(Widget card) => OverflowBox(
                          minHeight: 0,
                          maxHeight: double.infinity,
                          alignment: Alignment.topCenter,
                          child: _MeasureSize(
                            onChange: (size) {
                              if (_cardHeights[i] != size.height) {
                                setState(() => _cardHeights[i] = size.height);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: card,
                            ),
                          ),
                        );
                        if (pets.isEmpty) {
                          return wrap(_NoPetsCard(onAddPet: navigateToAddPet));
                        }
                        return wrap(
                          _DigitalIdCard(
                            qrToken: pets[i].id,
                            member: widget.member,
                            pet: pets[i],
                            walletPet: _walletFor(pets[i].id),
                            bookingEnabled: widget.bookingEnabled,
                            onShowQr: () =>
                                _showDigitalPawprint(context, petIndex: i),
                            onOptions: () => _showPetOptions(context, pets[i]),
                            onFileClaim: () =>
                                _openReimbursements(context, initialTab: 1),
                            onViewClaims: () =>
                                _openReimbursements(context, initialTab: 0),
                            onSubscribe: () =>
                                _openPlanSelection(context, pets[i]),
                            onOpenProfile: () =>
                                _openPetProfile(context, pets[i]),
                          ),
                        );
                      },
                    ),
                  ),
                  if (pets.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ...List.generate(pets.length, (i) {
                          final isActive = i == _selectedPetIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: isActive ? 16 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              // Navy, not gold. Pagination is structure, not a
                              // highlight — it was spending the accent on the
                              // least important control on the screen.
                              color: isActive ? cs.primary : cs.outline,
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// "Add pet" — the trailing action on the Your pets section header. Quiet
/// (navy label, no fill) because it sits beside a heading, but a real 44px
/// target rather than the 15px footnote it replaced.
class _AddPetAction extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPetAction({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _ScaleButton(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: 'Add another pet',
        excludeSemantics: true,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 4),
                Text(
                  'Add pet',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
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

// ── Size reporter (lets the pet carousel wrap its content) ────────────────

typedef _SizeChanged = void Function(Size size);

/// Reports its child's laid-out size via [onChange]. Used to make the pet-card
/// PageView size to the current card instead of a fixed frame.
class _MeasureSize extends SingleChildRenderObjectWidget {
  final _SizeChanged onChange;
  const _MeasureSize({required this.onChange, required Widget super.child});

  @override
  _MeasureSizeRender createRenderObject(BuildContext context) =>
      _MeasureSizeRender(onChange);

  @override
  void updateRenderObject(BuildContext context, _MeasureSizeRender obj) {
    obj.onChange = onChange;
  }
}

class _MeasureSizeRender extends RenderProxyBox {
  _MeasureSizeRender(this.onChange);
  _SizeChanged onChange;
  Size? _old;

  @override
  void performLayout() {
    super.performLayout();
    final size = child?.size ?? Size.zero;
    if (_old == size) return;
    _old = size;
    // Defer to after layout — setState during layout is not allowed.
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(size));
  }
}

// ── No Pets Prompt Card ───────────────────────────────────────────────────

class _NoPetsCard extends StatelessWidget {
  final VoidCallback onAddPet;
  const _NoPetsCard({required this.onAddPet});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.secondary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: cs.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pets_rounded,
              size: 32,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome to MetroPaws!',
            style: tt.headlineSmall?.copyWith(color: cs.primary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first pet and choose a membership plan to unlock their Digital Pawprint, session tracking, and clinic access.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _ScaleButton(
            onTap: onAddPet,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: AppColors.text,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Add Your Pet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── No Services Orientation Card ─────────────────────────────────────────

class _NoServicesCard extends StatelessWidget {
  const _NoServicesCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: cs.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No sessions assigned to this pet. Ask clinic staff to activate a membership plan.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Health Card (pet profile + QR reveal) ────────────────────────────────

class _DigitalIdCard extends StatelessWidget {
  final String qrToken;
  final Member member;
  final Pet? pet;
  final VoidCallback onShowQr;
  final VoidCallback? onOptions;
  // This pet's Benefit Wallet pools (null while loading / on fetch failure).
  final WalletPet? walletPet;
  // Legacy session progress rows only render when booking is re-enabled — they
  // sit on standby, not deleted (see CLAUDE.md).
  final bool bookingEnabled;
  final VoidCallback? onFileClaim;
  final VoidCallback? onViewClaims;
  // Opens plan selection for a pet with no active plan (restores the subscribe
  // path for an existing pet).
  final VoidCallback? onSubscribe;
  // Opens the pet's full profile — tapping the pet's avatar/name on the card.
  final VoidCallback? onOpenProfile;

  const _DigitalIdCard({
    required this.qrToken,
    required this.member,
    required this.onShowQr,
    this.pet,
    this.onOptions,
    this.walletPet,
    this.bookingEnabled = false,
    this.onFileClaim,
    this.onViewClaims,
    this.onSubscribe,
    this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final planType = pet?.planType ?? 'Standard';
    final tier = tierStyleFor(planType, isDark: isDark);

    // Every colour this card paints with comes off `tier` now — no inline
    // `isLightStandard ? … : …` ternaries left. That tangle was duplicated
    // verbatim inside _DigitalPawprintSheet, which is exactly how the sheet and
    // the card drifted apart, and it derived muted ink as `white @ 0.55`, whose
    // real contrast depends on whatever pixel it lands on.
    final onCard = tier.primaryText;
    final onCardMuted = tier.mutedText;
    final dividerColor = tier.dividerColor;

    // A healthy annual plan shows the tier and NOTHING else (client decision,
    // 2026-08-18): the expiry date is not what the member opens Home to find
    // out, and plan_selection already states it where it matters — at the
    // point of upgrading or renewing.
    //
    // The two statuses that remain are not dates, they are warnings:
    //   - Expired, which stops claims working and needs to be seen.
    //   - The server's verbatim §5.7 label for monthly members, because they
    //     are NOT yet covered while vesting and the bare tier badge would
    //     imply they were. Never paraphrase it; it is a contract term.
    final w0 = walletPet;
    String? planStatusLine;
    var planStatusUrgent = false;
    if (w0 != null && w0.planExpired) {
      planStatusLine = 'Expired';
      planStatusUrgent = true;
    } else if (w0 != null && w0.isMonthly) {
      planStatusLine = w0.membershipStatusLabel;
    }

    // Hoisted: the claim link moved out of the wallet Builder into the card's
    // own actions row, so the "is there anything left to claim" test has to be
    // visible at card level now.
    final wClaim = walletPet;
    final canFileClaimNow =
        wClaim != null &&
        (wClaim.remainingCentavos > 0 || wClaim.emergencyRemainingCentavos > 0);

    final isVerified = pet?.vaxCardUrl != null;
    final petServices = pet?.petServices ?? [];
    // The Digital Pawprint QR is the pet's clinic-redemption ID; it only makes
    // sense once the pet has an active plan. A plan-less pet shows just the
    // "Choose a plan" CTA from _NoPlanBlock instead.
    final hasPlan = pet?.hasActivePlan ?? false;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        // Gradient, not a flat fill. It is the whole difference between a
        // coloured rectangle and a card catching light, and it costs nothing:
        // the two ends are tier tokens.
        gradient: tier.surfaceGradient,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: tier.borderColor, width: 1.5),
        boxShadow: tier.shadow,
      ),
      // Clipped so the watermark can bleed off the corner instead of stopping
      // short of it, which would read as a misplaced icon rather than as
      // something embossed into the card.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_cardRadius),
        child: Stack(
          children: [
            _CardWatermark(ink: onCard),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Pet identity row ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  child: Row(
                    children: [
                      // Tapping the pet's avatar/name opens their full profile — the
                      // learned "tap a pet to view them" gesture. The ⋮ menu offers
                      // the same via "View profile" for discoverability.
                      Expanded(
                        child: Semantics(
                          button: onOpenProfile != null,
                          label: onOpenProfile != null && pet != null
                              ? "View ${_capFirst(pet!.name)}'s profile"
                              : null,
                          child: GestureDetector(
                            onTap: onOpenProfile,
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              children: [
                                // 60, not 52. "Pet as Hero" is the first UX
                                // principle in PRODUCT.md, and the photo is the
                                // fastest way to tell one carousel card from the
                                // next.
                                PetAvatar(
                                  photoUrl: pet?.photoUrl,
                                  size: 60,
                                  petName: pet?.name,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pet != null
                                            ? _capFirst(pet!.name)
                                            : 'Your Pet',
                                        style: Theme.of(context)
                                            .textTheme
                                            .displaySmall
                                            ?.copyWith(
                                              color: onCard,
                                              fontWeight: FontWeight.w800,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (pet?.breed != null ||
                                          pet?.species != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          // Species is stored lowercase for older
                                          // pets ("dog"); pet_form_screen only
                                          // started offering "Dog"/"Cat" later, so
                                          // the data is mixed and the display has to
                                          // normalise it. clinic_scanner does the
                                          // same thing inline.
                                          [
                                            if (pet?.species != null)
                                              _capFirst(pet!.species!),
                                            if (pet?.breed != null)
                                              _capFirst(pet!.breed!),
                                          ].join(' · '),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(color: onCardMuted),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      // The badge alone is short enough to live in
                                      // the name column, which buys back the whole
                                      // row the full-width plan block cost. Any
                                      // status WORDING stays full-width below --
                                      // "Fully Service-Eligible" would not fit here.
                                      if (hasPlan && pet?.planType != null) ...[
                                        const SizedBox(height: 8),
                                        TierBadge(
                                          planType: pet!.planType!,
                                          small: true,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (isVerified || onOptions != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          // Top-aligned, not centred: against a three-line name
                          // column these two float mid-block and read as content.
                          // They are card chrome and belong on the top edge.
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Ink, not gold. A 16px gold tick is 2.7:1 on the
                            // Standard card — below even the 3:1 UI floor — and it
                            // was one of seven gold marks competing on one card. A
                            // vaccination tick is a trust mark, not a highlight.
                            if (isVerified)
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: 4,
                                  top: 12,
                                ),
                                child: Icon(
                                  Icons.verified_rounded,
                                  size: 16,
                                  color: onCard,
                                ),
                              ),
                            if (onOptions != null)
                              Semantics(
                                label: 'Pet options',
                                button: true,
                                child: GestureDetector(
                                  onTap: onOptions,
                                  behavior: HitTestBehavior.opaque,
                                  child: SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Icon(
                                      Icons.more_vert,
                                      size: 18,
                                      color: onCardMuted,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),

                // Plan status: only renders when there is something to warn
                // about (expired, or a monthly member still vesting). A healthy
                // annual plan says its piece with the tier badge above and spends no
                // vertical space here.
                if (planStatusLine != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                    child: Text(
                      planStatusLine,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        // tier.warning, not AppColors.error: #DC2626 measures 2.6:1
                        // on the De Luxe navy card, so "Expired" — the one line on
                        // this card that stops claims working — was the least
                        // readable thing on it for exactly the members who need it.
                        color: planStatusUrgent ? tier.warning : onCardMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                // ── Benefit Wallet — the pet's membership value now that booking/
                //    sessions are on standby. Legacy session rows still render below
                //    when booking_enabled flips back on (they're standby, not dead).
                Builder(
                  builder: (context) {
                    // A pet with no active plan has no wallet yet — prompt to
                    // subscribe (the pet's identity + QR still show above/below).
                    if (!(pet?.hasActivePlan ?? false)) {
                      return _NoPlanBlock(
                        petName: pet?.name ?? 'your pet',
                        tier: tier,
                        onSubscribe: onSubscribe,
                      );
                    }

                    final w = walletPet;
                    final showSessions =
                        bookingEnabled && petServices.isNotEmpty;

                    // A pool with a 0 total isn't offered on this plan — skip it.
                    //
                    // The FIRST pool rendered takes the display-size figure. That is
                    // Preventive Wellness wherever a plan funds it (₱2,000–₱7,000 vs
                    // Emergency's ₱300–₱1,500, per scripts/seed.py), and Emergency
                    // only on the hypothetical plan that funds emergency alone —
                    // rather than hardcoding "preventive is the big one" and leaving
                    // such a card with no primary figure at all.
                    final walletRows = <Widget>[];
                    if (w != null) {
                      if (w.walletCentavos > 0) {
                        walletRows.add(
                          _WalletMeter(
                            available: w.preventiveAvailable,
                            label: 'Preventive Wellness',
                            totalCentavos: w.walletCentavos,
                            remainingCentavos: w.remainingCentavos,
                            tier: tier,
                            primary: true,
                            onTap: onViewClaims,
                          ),
                        );
                      }
                      if (w.emergencyWalletCentavos > 0) {
                        walletRows.add(
                          _WalletMeter(
                            available: w.emergencyAvailable,
                            label: 'Emergency',
                            totalCentavos: w.emergencyWalletCentavos,
                            remainingCentavos: w.emergencyRemainingCentavos,
                            tier: tier,
                            primary: walletRows.isEmpty,
                            onTap: onViewClaims,
                          ),
                        );
                      }
                    }
                    final hasWallet = walletRows.isNotEmpty;

                    // Nothing to show yet (wallet loading / fetch failed, booking off)
                    // → render header + QR only, no spinner or placeholder.
                    if (!hasWallet && !showSessions) {
                      return const SizedBox.shrink();
                    }

                    final labelStyle = Theme.of(context).textTheme.labelSmall
                        ?.copyWith(
                          color: onCardMuted,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          fontSize: 10,
                        );

                    // The "BENEFIT WALLET" heading is gone while the wallet is the
                    // only block. A peso figure under the words "Preventive Wellness"
                    // does not need a title telling you it is a wallet, and the ~24px
                    // it cost is what pays for the balance being readable at arm's
                    // length. The headings come back the moment there are TWO blocks
                    // to tell apart — which is the only job they were doing.
                    final needsHeadings = hasWallet && showSessions;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Divider(height: 1, color: dividerColor),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (hasWallet) ...[
                                if (needsHeadings)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text(
                                      'BENEFIT WALLET',
                                      style: labelStyle,
                                    ),
                                  ),
                                ...walletRows,
                              ],
                              if (showSessions) ...[
                                if (hasWallet) const SizedBox(height: 6),
                                if (needsHeadings)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text(
                                      'SESSIONS AVAILABLE',
                                      style: labelStyle,
                                    ),
                                  ),
                                ...petServices.map(
                                  (s) => _SessionProgressRow(
                                    service: s,
                                    tier: tier,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // ── Show Digital Pawprint CTA — active plans only ────────────
                if (hasPlan) ...[
                  // Spacing, not a third divider. Three horizontal rules turned this
                  // card into a small document; air separates the CTA instead.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                    child: _ScaleButton(
                      onTap: onShowQr,
                      child: Container(
                        // minHeight, not height: the 48px box clipped the label at
                        // large font scales. This keeps the 44px touch floor and
                        // lets the button grow to two lines instead of truncating
                        // the one action the card exists for.
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          // The CTA is a tier signal now: navy on Standard, brushed
                          // metal on De Luxe, gold foil on Premium. One identical
                          // gold button on all three tiers was the third element
                          // making the cards interchangeable, and it left De Luxe
                          // with a gold button under a gold balance figure while
                          // handing the top tier nothing of its own.
                          //
                          // Shape, size, radius, icon and label are unchanged across
                          // tiers — this is the card's skin, not a second button
                          // vocabulary.
                          color: tier.ctaFill,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code_rounded,
                              size: 18,
                              color: tier.ctaLabel,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Show Digital Pawprint',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: tier.ctaLabel,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Both secondary actions share one row instead of stacking into
                  // two 44px strips. Wrap, not Row: "Plan ends soon -- Renew now"
                  // beside "File a claim" does not fit at 329dp, and Wrap drops to a
                  // second line only when it must rather than always.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 2, 18, 6),
                    child: Wrap(
                      spacing: 18,
                      children: [
                        if (canFileClaimNow && onFileClaim != null)
                          _FileClaimLink(ink: onCard, onTap: onFileClaim!),
                        // The only path to plan selection for a pet that already has
                        // a plan. Copy is status-aware from the local activation date
                        // (display only; the server enforces eligibility).
                        if (onSubscribe != null)
                          _PlanActionLink(
                            activatedAt: pet?.planActivatedAt,
                            onCardMuted: onCardMuted,
                            warning: tier.warning,
                            onTap: onSubscribe!,
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Corner radius shared by the pet card and its clip, so the border and the
/// clipped watermark can't round differently. 18, not 16: the card grew a real
/// shadow and a gradient, and a slightly softer corner is what stops the two
/// from reading as a hard plastic tile.
const double _cardRadius = 18;

/// The emboss on the pet card: one paw print, tilted right and set flush into
/// the top-right corner.
///
/// GENERAL — one paw for every pet (client decision, 2026-08-20). It keeps the
/// full paw drawing (heart-shaped metacarpal pad, four splayed toes) and simply
/// omits the NAILS; a clawless print is the neutral form, and the earlier plain
/// oval-pad version threw away the pad shape along with the claws, which is not
/// what "general" meant. It is a brand texture, not a species read-out — the
/// breed line two rows away already says "Dog" or "Cat" in words.
///
/// Hand-painted rather than `Icons.pets` because the paw is TILTED and has to
/// sit flush in the corner: the painter measures the rotated print and fits it
/// to its box exactly, so "flush" costs no toes. A rotated icon would push its
/// own diagonal past the box and the corner would cut the print instead.
///
/// INK, never gold — the same rule the paw trail follows: gold marks money and
/// actions, and spending it on decoration costs the signal. 6% is a CEILING,
/// not a starting point: at 7% the tightest pair on the card (De Luxe muted ink
/// over the stamp) drops to 4.59:1, so raising the alpha breaks AA before it
/// looks better.
class _CardWatermark extends StatelessWidget {
  final Color ink;

  const _CardWatermark({required this.ink});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: _pawInset,
      right: _pawInset,
      // Excluded from the semantics tree and from hit testing: it is a surface,
      // not content, and a screen reader announcing "paw print" over a
      // membership card is noise.
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: CustomPaint(
            size: const Size(_pawSize, _pawSize),
            painter: _PawEmbossPainter(color: ink.withValues(alpha: 0.06)),
          ),
        ),
      ),
    );
  }
}

const double _pawSize = 132;

/// How far the print runs off the card's top and right edges. Negative, so the
/// paw rides the edge rather than sitting inside it — the emboss carries on
/// past the corner the way a stamp on a physical card does.
///
/// The two numbers move TOGETHER. The inset is a fixed pixel bite out of a
/// print whose size sets how much of it that is: -14 of 132px trims the outer
/// tips and keeps the pad plus the whole toe arc; the same -14 on a 90px print
/// would eat a toe. Measured geometries that stopped reading as a paw: 220px at
/// -46 (pad + two toe fragments) and 140px at -58 (bare pad — a lopsided
/// teardrop, which shipped briefly before being caught on a real device).
const double _pawInset = -14;

/// Clockwise, so the print leans to the right.
const double _pawTilt = 0.34;

/// One paw print — heart-shaped pad plus four toes, no nails — rotated by
/// [_pawTilt] and scaled so its rotated bounds fill the painter's box.
///
/// Fitting to the ROTATED bounds is the whole trick. Sizing to the upright paw
/// and rotating afterwards throws the diagonal outside the box, and every
/// attempt that did so lost toes to the card edge: 140px at -58/-46 left only
/// the bare pad (a lopsided teardrop that reads as a smudge, which shipped
/// briefly before being caught on a real device), and 172px at -16/-22 cut the
/// right-hand toe.
class _PawEmbossPainter extends CustomPainter {
  final Color color;

  const _PawEmbossPainter({required this.color});

  /// `(centre, width, height, tilt)` in unit space — four toes arched over the
  /// pad, the outer pair set lower and splayed, as a real gait leaves them.
  static const _toes = [
    (Offset(-0.375, -0.04), 0.26, 0.36, -0.44),
    (Offset(-0.135, -0.30), 0.28, 0.39, -0.15),
    (Offset(0.135, -0.30), 0.28, 0.39, 0.15),
    (Offset(0.375, -0.04), 0.26, 0.36, 0.44),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final paw = _pawPath();
    final bounds = paw.getBounds();
    if (bounds.isEmpty) return;

    final sx = size.width / bounds.width;
    final sy = size.height / bounds.height;
    final scale = sx < sy ? sx : sy;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale, scale);
    canvas.translate(-bounds.center.dx, -bounds.center.dy);
    canvas.drawPath(paw, Paint()..color = color);
    canvas.restore();
  }

  /// The whole print as ONE path so it can be measured and rotated as a unit.
  Path _pawPath() {
    final paw = Path()..addPath(_padPath(), Offset.zero);
    for (final (at, w, h, tilt) in _toes) {
      paw.addPath(_tiltedOval(w, h, tilt), at);
    }
    return paw.transform((Matrix4.identity()..rotateZ(_pawTilt)).storage);
  }

  /// The metacarpal pad: an oval notched at the top and split into two lobes at
  /// the bottom — the heart shape that makes a print read as a paw pad rather
  /// than as a fifth toe.
  Path _padPath() {
    const at = Offset(0, 0.30);
    const w = 0.76, h = 0.58;
    final l = at.dx - w / 2, r = at.dx + w / 2;
    final t = at.dy - h / 2, b = at.dy + h / 2;
    return Path()
      ..moveTo(at.dx, t + h * 0.12)
      ..cubicTo(at.dx - w * 0.14, t - h * 0.06, l, t + h * 0.16, l, at.dy)
      ..cubicTo(l, b - h * 0.10, l + w * 0.20, b, at.dx - w * 0.16, b)
      ..cubicTo(at.dx - w * 0.05, b - h * 0.14, at.dx, b - h * 0.14, at.dx, b)
      ..cubicTo(
        at.dx + w * 0.05,
        b - h * 0.14,
        at.dx + w * 0.16,
        b,
        r - w * 0.20,
        b,
      )
      ..cubicTo(r, b, r, b - h * 0.10, r, at.dy)
      ..cubicTo(
        r,
        t + h * 0.16,
        at.dx + w * 0.14,
        t - h * 0.06,
        at.dx,
        t + h * 0.12,
      )
      ..close();
  }

  Path _tiltedOval(double w, double h, double tilt) {
    final oval = Path()
      ..addOval(Rect.fromCenter(center: Offset.zero, width: w, height: h));
    return oval.transform((Matrix4.identity()..rotateZ(tilt)).storage);
  }

  @override
  bool shouldRepaint(_PawEmbossPainter old) => old.color != color;
}

// ── Upgrade / renew link (pet card, active plans) ─────────────────────────

/// Quiet status-aware plan action under the QR CTA: "Upgrade plan" while the
/// plan is comfortably active, "Renew now" in the final 30 days, and a louder
/// "Plan expired — Renew" once the year has ended. Mirrors the server's
/// plan_status thresholds for display; eligibility itself is server-enforced.
class _PlanActionLink extends StatelessWidget {
  final DateTime? activatedAt;
  final Color onCardMuted;

  /// The card's contrast-safe alarm ink. Was `AppColors.gold`, which is 2.7:1
  /// on the Standard card and 4.6:1 on navy — so "Plan expired — Renew", the
  /// most urgent line the card can show, was rendered in the one colour that
  /// could not carry it.
  final Color warning;
  final VoidCallback onTap;

  const _PlanActionLink({
    required this.activatedAt,
    required this.onCardMuted,
    required this.warning,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Legacy plans without an activation date never expire — plain upgrade.
    String label = 'Upgrade plan';
    bool urgent = false;
    if (activatedAt != null) {
      final expires = activatedAt!.add(const Duration(days: 365));
      final now = DateTime.now();
      if (now.isAfter(expires)) {
        label = 'Plan expired — Renew';
        urgent = true;
      } else if (now.isAfter(expires.subtract(const Duration(days: 30)))) {
        label = 'Plan ends soon — Renew now';
        urgent = true;
      }
    }

    return _ScaleButton(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: label,
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                urgent ? Icons.autorenew_rounded : Icons.trending_up_rounded,
                size: 15,
                color: urgent ? warning : onCardMuted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: urgent ? warning : onCardMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Press-scale wrapper ───────────────────────────────────────────────────

class _ScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _ScaleButton({required this.child, required this.onTap});

  @override
  State<_ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<_ScaleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: _pressed ? Curves.easeIn : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

// ── Digital Pawprint Bottom Sheet ─────────────────────────────────────────

class _DigitalPawprintSheet extends StatefulWidget {
  final String qrToken;
  final Member member;
  final Pet? pet;

  const _DigitalPawprintSheet({
    required this.qrToken,
    required this.member,
    this.pet,
  });

  @override
  State<_DigitalPawprintSheet> createState() => _DigitalPawprintSheetState();
}

class _DigitalPawprintSheetState extends State<_DigitalPawprintSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 440),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        MediaQuery.of(context).disableAnimations
            ? _ctrl.value = 1.0
            : _ctrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _petSubtitle() {
    final pet = widget.pet;
    if (pet == null) return '';
    return [
      if (pet.breed != null) _capFirst(pet.breed!),
      if (pet.computedAge != null)
        '${pet.computedAge!} yr${pet.computedAge! != 1 ? "s" : ""}',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final planType =
        widget.pet?.planType ?? widget.member.planType ?? 'Standard';
    final tier = tierStyleFor(planType, isDark: isDark);

    // Read from `tier`, like the card does. These four lines used to be
    // copy-pasted from _DigitalIdCard, so the sheet kept the old derivation
    // whenever the card's changed — and it is the same membership card, opened.
    final onCard = tier.primaryText;
    final onCardMuted = tier.mutedText;

    final qrSize = (MediaQuery.of(context).size.width * 0.55).clamp(0.0, 220.0);

    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        // Same gradient and edge as the Home card it was opened from, so the
        // sheet reads as that card enlarged rather than as a different object.
        gradient: tier.surfaceGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: tier.borderColor, width: 1.5),
        // Cast UPWARD — the sheet rises from the bottom edge, so its shadow
        // has to fall on the content above it, which is the opposite of the
        // card's. Only the offsets differ from `tier.shadow`.
        boxShadow: [
          for (final s in tier.shadow)
            BoxShadow(
              color: s.color,
              blurRadius: s.blurRadius,
              offset: Offset(0, -s.offset.dy),
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: tier.meterTrack,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Brand label + close button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            // A Row, not a Stack. The Stack let the centred label run
            // underneath the close button — at 329dp it rendered as
            // "METROPAWS STANDARD MEMBE✕", unreadable and broken-looking,
            // because a Positioned sibling contributes nothing to the label's
            // constraints. The leading spacer mirrors the button so the label
            // stays optically centred rather than shunted left by it.
            child: Row(
              children: [
                const SizedBox(width: 44),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // tier.accent, not raw gold: this lockup was painted gold
                      // on every tier, and gold on the white Standard sheet is
                      // 2.5:1 — the brand's own name was the least legible text
                      // on the screen for the tier most members are on. The
                      // sheet carries no balance figure, so the accent is free
                      // here and the lockup is the right thing to spend it on.
                      Icon(Icons.shield_rounded, size: 13, color: tier.accent),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          // The tier word is dropped when space is short: the
                          // TierBadge directly below already states it, so the
                          // long form was spending 8 characters to repeat
                          // itself.
                          context.isTight
                              ? 'METROPAWS MEMBER'
                              : 'METROPAWS ${(widget.member.planType ?? 'Standard').toUpperCase()} MEMBER',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: tier.accent,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, size: 18, color: onCardMuted),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Pet identity
          PetAvatar(
            photoUrl: widget.pet?.photoUrl,
            size: 88,
            petName: widget.pet?.name,
          ),
          const SizedBox(height: 12),
          Text(
            widget.pet != null ? _capFirst(widget.pet!.name) : 'Your Pet',
            style: Theme.of(
              context,
            ).textTheme.displayMedium?.copyWith(color: onCard),
          ),
          if (_petSubtitle().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              _petSubtitle(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: onCardMuted,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 8),
          TierBadge(planType: widget.member.planType ?? 'Standard'),
          if (widget.member.isFoundingMember) ...[
            const SizedBox(height: 8),
            const _FoundingBadge(),
          ],
          const SizedBox(height: 24),

          // QR block — animated
          FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _showFullScreenQr(context, widget.qrToken);
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: widget.qrToken,
                    version: QrVersions.auto,
                    size: qrSize,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Show this to clinic staff · tap to expand',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: onCardMuted),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24 + bottomPad),
        ],
      ),
    );
  }
}

/// A slim progress track, shared by the wallet meters and the standby session
/// rows so the two can never drift apart again.
///
/// The fill is the card's own INK, not the accent: the bar is structure (how
/// much is left), and the FIGURE above it is the money. Both in the accent made
/// the meter the loudest thing on a card whose CTA is also accented.
class _MeterBar extends StatelessWidget {
  final double progress;
  final TierStyle tier;
  final double height;

  /// True once the pool is spent. An empty track and a still-loading track look
  /// identical, so a spent pool tints its track instead of just going blank.
  final bool depleted;

  const _MeterBar({
    required this.progress,
    required this.tier,
    this.height = 6,
    this.depleted = false,
  });

  @override
  Widget build(BuildContext context) {
    // 0.35, not 0.22: a spent pool's track separates from a normal one almost
    // entirely by HUE (their luminance is 1.14:1 apart), and at 0.22 the tint
    // was too faint for that hue to register as a state at all.
    final track = depleted
        ? tier.warning.withValues(alpha: 0.35)
        : tier.meterTrack;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: progress),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final trackW = constraints.maxWidth;
            return ClipRRect(
              // Fully rounded, not radius 4. At 6-7px tall a 4px corner reads
              // as a clipped rectangle; a pill reads as a gauge.
              borderRadius: BorderRadius.circular(height),
              child: SizedBox(
                height: height,
                width: trackW,
                child: Stack(
                  children: [
                    Container(height: height, width: trackW, color: track),
                    if (value > 0)
                      Container(
                        height: height,
                        width: trackW * value,
                        decoration: BoxDecoration(
                          // Always full-strength ink. A dimmed fill was 2.03:1
                          // against its own track on the De Luxe card — below
                          // the 3:1 UI floor — so a FULL bar was nearly
                          // indistinguishable from an empty one, and a pool
                          // with every peso still in it read as spent.
                          color: tier.primaryText,
                          borderRadius: BorderRadius.circular(height),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Legacy prepaid-session row. Standby, not dead — it renders only while
/// `booking_enabled` is on (see CLAUDE.md), and shares [_MeterBar] with the
/// live wallet meters so the two visuals stay identical when booking returns.
class _SessionProgressRow extends StatelessWidget {
  final PetService service;
  final TierStyle tier;

  const _SessionProgressRow({required this.service, required this.tier});

  @override
  Widget build(BuildContext context) {
    final total = service.totalSessions.clamp(1, 999);
    final remaining = service.remainingSessions.clamp(0, total);
    final isDepleted = remaining == 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  service.serviceType.name,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: tier.mutedText,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$remaining/$total',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  // Sessions are not money, so they take ink rather than the
                  // accent — which the old row spent on a raw `AppColors.gold`
                  // count that measured 2.7:1 on the Standard card anyway.
                  color: isDepleted ? tier.mutedText : tier.primaryText,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          _MeterBar(
            progress: remaining / total,
            tier: tier,
            depleted: isDepleted,
          ),
        ],
      ),
    );
  }
}

// ── Benefit Wallet meter (Home pet card) ─────────────────────────────────

/// One peso-denominated wallet pool on the Home pet card.
///
/// Two sizes, set by [primary]. The plan's main pool gets a display-size
/// balance (the card's second-loudest element after the pet's name); the
/// smaller pool gets a single compact row. Before this both pools were rendered
/// at 12sp, which left the card with no hierarchy at all between its heading
/// and its content — every line the same size, which is what made a membership
/// card read as a form.
///
/// Pool-agnostic: the caller passes the label and the pool's totals. Money
/// stays in centavos until [pesoFromCentavos] at the display edge.
class _WalletMeter extends StatelessWidget {
  final String label;
  final int totalCentavos;
  final int remainingCentavos;
  final TierStyle tier;

  /// True for the pool that carries the card's headline figure.
  final bool primary;
  final VoidCallback? onTap;

  /// False while a monthly subscriber has not vested this pool. The Home card
  /// is the first thing a member sees, so showing the balance in the accent
  /// here is the loudest possible claim that the money is theirs to spend.
  final bool available;

  const _WalletMeter({
    this.available = true,
    required this.label,
    required this.totalCentavos,
    required this.remainingCentavos,
    required this.tier,
    required this.primary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final safeRemaining = remainingCentavos < 0 ? 0 : remainingCentavos;
    final isDepleted = safeRemaining == 0;
    final progress = totalCentavos <= 0
        ? 0.0
        : (safeRemaining / totalCentavos).clamp(0.0, 1.0);
    final spendable = available && !isDepleted;

    final labelText = Text(
      label,
      style: tt.labelSmall?.copyWith(
        color: tier.mutedText,
        fontWeight: FontWeight.w600,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final ceilingStyle = tt.labelSmall?.copyWith(color: tier.mutedText);
    final ceiling = 'left of ${pesoFromCentavos(totalCentavos)}';

    // ── The unvested case: no figure at all ──────────────────────────────
    // A monthly member three payments in has a real balance they cannot spend.
    // Printing it at display size and then captioning it "Not available yet"
    // says both things at once and lets the bigger one win, so the wording
    // carries it and the number waits until it is theirs.
    if (!available) {
      return Padding(
        padding: EdgeInsets.only(bottom: primary ? 16 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            labelText,
            const SizedBox(height: 2),
            Text(
              'Not available yet · ${pesoFromCentavos(totalCentavos)} vesting',
              style: tt.labelSmall?.copyWith(
                color: tier.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _MeterBar(progress: 0, tier: tier, height: primary ? 7 : 4),
          ],
        ),
      );
    }

    // The accent is the HEADLINE figure's alone. Painting the secondary pool
    // in it too gave the Premium card three gold elements — headline, Emergency
    // figure, CTA — and three things claiming to be the one worth looking at is
    // the same as none.
    final amountColor = !spendable
        ? tier.mutedText
        : (primary ? tier.accent : tier.primaryText);

    // ── Primary pool — the balance is the headline ───────────────────────
    if (primary) {
      final figure = Text(
        pesoFromCentavos(safeRemaining),
        style: tt.headlineSmall?.copyWith(
          color: amountColor,
          fontWeight: FontWeight.w800,
          // Tabular digits so the figure doesn't shuffle sideways as it
          // animates down after a claim is approved.
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );

      // The ceiling drops to its own line when the row is squeezed — by a
      // narrow screen OR by scaled-up text. A 20sp figure plus an 18-character
      // tail does not share one line at 320dp, and shrinking the figure to make
      // it fit would undo the whole point of it.
      final headline = context.isTight
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                figure,
                Text(ceiling, style: ceilingStyle),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                figure,
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    ceiling,
                    style: ceilingStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );

      return _wrapTap(
        context,
        safeRemaining,
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              labelText,
              const SizedBox(height: 2),
              headline,
              const SizedBox(height: 9),
              _MeterBar(
                progress: progress,
                tier: tier,
                height: 7,
                depleted: isDepleted,
              ),
            ],
          ),
        ),
      );
    }

    // ── Secondary pool — one compact row ─────────────────────────────────
    return _wrapTap(
      context,
      safeRemaining,
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: labelText),
                const SizedBox(width: 10),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: pesoFromCentavos(safeRemaining),
                        style: tt.labelMedium?.copyWith(
                          color: amountColor,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      TextSpan(text: ' left', style: ceilingStyle),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            // 5px against the primary's 7px. Height and the block's layout are
            // the ONLY things that rank the two pools now. Opacity is not
            // available for ranking: muted already means "not spendable" on
            // this card (a depleted or unvested pool), so dimming a healthy
            // pool to say "less important" said "you cannot spend this"
            // instead — the same visual carrying two meanings.
            _MeterBar(
              progress: progress,
              tier: tier,
              height: 5,
              depleted: isDepleted,
            ),
          ],
        ),
      ),
    );
  }

  /// Announces the pool in full — including the ceiling the compact row
  /// abbreviates — and makes the block tappable when the caller gave it a
  /// destination.
  Widget _wrapTap(BuildContext context, int safeRemaining, Widget child) {
    final semantic = Semantics(
      label:
          '$label wallet, ${pesoFromCentavos(safeRemaining)} of '
          '${pesoFromCentavos(totalCentavos)} remaining',
      button: onTap != null,
      child: child,
    );
    if (onTap == null) return semantic;
    return _ScaleButton(onTap: onTap!, child: semantic);
  }
}

/// Quiet text link on the pet card that opens the reimbursement Submit flow.
/// Deliberately unfilled so it doesn't compete with the "Show Digital
/// Pawprint" CTA above it.
class _FileClaimLink extends StatelessWidget {
  /// The card's ink — not its accent. The accent belongs to the balance figure
  /// this link sits under; giving both the same colour made two elements claim
  /// to be the one thing worth looking at. Weight carries the link instead.
  final Color ink;
  final VoidCallback onTap;
  const _FileClaimLink({required this.ink, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _ScaleButton(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: 'File a claim',
        // SizedBox, not Container+alignment: an aligned Container expands to
        // the full width it is offered, which inside a Wrap means one link per
        // line no matter how much room is left.
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline, size: 16, color: ink),
              const SizedBox(width: 6),
              Text(
                'File a claim',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── No-plan empty state (Home pet card) ──────────────────────────────────

/// Shown on the pet card when the pet has no active plan: a friendly prompt +
/// a "Choose a plan" CTA that opens plan selection. Painted with the tier-skin
/// colors so it reads as part of the card, matching the wallet/session blocks.
class _NoPlanBlock extends StatelessWidget {
  final String petName;
  final TierStyle tier;
  final VoidCallback? onSubscribe;

  const _NoPlanBlock({
    required this.petName,
    required this.tier,
    this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: tier.dividerColor),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Column(
            children: [
              // A plan-less pet always renders the Standard skin (there is no
              // tier to read yet), so this is the matte gold — raw `gold` was
              // 2.7:1 on the white card it actually appears on.
              Icon(
                Icons.workspace_premium_outlined,
                size: 30,
                color: tier.accent,
              ),
              const SizedBox(height: 10),
              Text(
                'No active plan',
                style: tt.titleMedium?.copyWith(
                  color: tier.primaryText,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                "Subscribe to unlock ${_capFirst(petName)}'s Benefit Wallet "
                'and claim back clinic costs.',
                style: tt.bodyMedium?.copyWith(color: tier.mutedText),
                textAlign: TextAlign.center,
              ),
              if (onSubscribe != null) ...[
                const SizedBox(height: 16),
                _ScaleButton(
                  onTap: onSubscribe!,
                  child: Container(
                    // minHeight, not height — same reason as the QR CTA: a
                    // fixed 48px box clips the label once text is scaled up.
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      // Matches the QR CTA on the same card, so a pet with a
                      // plan and a pet without one share one button vocabulary.
                      color: tier.ctaFill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.workspace_premium,
                          size: 18,
                          color: tier.ctaLabel,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Choose a plan',
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: tt.labelLarge?.copyWith(
                              color: tier.ctaLabel,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Founding Member Badge ─────────────────────────────────────────────────

class _FoundingBadge extends StatelessWidget {
  /// Solid-gold, compact treatment for navy surfaces (the Home header, beside
  /// the member's name). A tinted gold-on-navy pill would be gold text at
  /// 2.9:1 — invisible at 10sp. Filled gold with dark text is 6.1:1, and it is
  /// one of the few places gold is genuinely earned: not every member is a
  /// Founding Member, so the badge stays rare enough to be worth the accent.
  ///
  /// The default constructor is the roomier light-surface variant used inside
  /// the Digital Pawprint sheet.
  final bool _onNavy;

  const _FoundingBadge() : _onNavy = false;

  const _FoundingBadge.onNavy() : _onNavy = true;

  @override
  Widget build(BuildContext context) {
    // On light surfaces the label was gold-on-white at 2.7:1. goldDark is the
    // token that exists for exactly this (small text on a gold surface).
    final inkColor = _onNavy ? AppColors.text : AppColors.goldDark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _onNavy ? 8 : 10,
        vertical: _onNavy ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: _onNavy
            ? AppColors.gold
            : AppColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: _onNavy
            ? null
            : Border.all(
                color: AppColors.gold.withValues(alpha: 0.4),
                width: 1,
              ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: _onNavy ? 10 : 12, color: inkColor),
          SizedBox(width: _onNavy ? 3 : 4),
          Text(
            'Founding Member',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: inkColor,
              fontWeight: FontWeight.w700,
              fontSize: _onNavy ? 10 : 11,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

void _showFullScreenQr(BuildContext context, String qrToken) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'DIGITAL PAWPRINT',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.navy,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            QrImageView(
              data: qrToken,
              version: QrVersions.auto,
              size: 300,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 16),
            Text(
              'Show this to clinic staff',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: AppColors.navy),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Booking Tab ────────────────────────────────────────────────────────────

class _BookingView extends StatefulWidget {
  final Member member;
  final List<Booking> bookings;
  final bool isSubmitting;
  final bool isFailure;

  const _BookingView({
    required this.member,
    required this.bookings,
    required this.isSubmitting,
    this.isFailure = false,
  });

  @override
  State<_BookingView> createState() => _BookingViewState();
}

class _BookingViewState extends State<_BookingView> {
  PetService? _selectedService;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  int? _selectedSlot;
  List<ClinicPartner> _clinics = [];
  ClinicPartner? _selectedClinic;
  Pet? _selectedPet;

  static const _morningSlots = ['8:00 AM', '9:00 AM', '10:00 AM', '11:00 AM'];
  static const _afternoonSlots = ['1:00 PM', '2:00 PM', '3:00 PM', '4:00 PM'];
  static const _slots = [
    '8:00 AM',
    '9:00 AM',
    '10:00 AM',
    '11:00 AM',
    '1:00 PM',
    '2:00 PM',
    '3:00 PM',
    '4:00 PM',
  ];

  List<PetService> get _bookableServices => _selectedPet?.petServices ?? [];

  @override
  void initState() {
    super.initState();
    _selectedPet = widget.member.pets.isNotEmpty
        ? widget.member.pets.first
        : null;
    _selectedService = null;
    context.read<MemberBloc>().add(BookingsLoadRequested());
    _loadClinics();
  }

  Future<void> _loadClinics() async {
    try {
      final clinics = await ApiService.getClinics();
      if (mounted) {
        setState(() {
          _clinics = clinics;
        });
      }
    } catch (_) {}
  }

  void _pickClinic(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ClinicPickerSheet(
        clinics: _clinics,
        selectedClinic: _selectedClinic,
        onSelected: (clinic) {
          setState(() => _selectedClinic = clinic);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  static IconData _iconForService(String name) {
    final n = name.toLowerCase();
    if (n.contains('groom')) return Icons.content_cut;
    if (n.contains('vaccin')) return Icons.vaccines;
    if (n.contains('consult')) return Icons.medical_services_outlined;
    if (n.contains('pickup') || n.contains('pick-up') || n.contains('vip'))
      return Icons.directions_car_outlined;
    if (n.contains('dental') || n.contains('teeth'))
      return Icons.medical_information_outlined;
    if (n.contains('bath')) return Icons.shower_outlined;
    if (n.contains('board') || n.contains('stay')) return Icons.home_outlined;
    if (n.contains('check') || n.contains('exam'))
      return Icons.health_and_safety_outlined;
    return Icons.pets_rounded;
  }

  @override
  void didUpdateWidget(_BookingView old) {
    super.didUpdateWidget(old);
    if (old.isSubmitting && !widget.isSubmitting && !widget.isFailure) {
      setState(() {
        _selectedSlot = null;
        _selectedDate = DateTime.now().add(const Duration(days: 1));
      });
    }
    if (!old.isFailure && widget.isFailure) {
      setState(() => _selectedSlot = null);
    }
  }

  void _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
            primary: AppColors.navy,
            onPrimary: AppColors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedSlot = null;
      });
    }
  }

  void _submit() {
    if (_selectedService == null ||
        _selectedSlot == null ||
        _selectedClinic == null)
      return;
    _showBookingConfirmation();
  }

  void _showBookingConfirmation() {
    final service = _selectedService!;
    final clinic = _selectedClinic!;
    final slot = _slots[_selectedSlot!];
    final usesCredit = service.remainingSessions > 0;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BookingConfirmSheet(
        pet: _selectedPet,
        member: widget.member,
        service: service,
        clinic: clinic,
        date: _selectedDate,
        timeSlot: slot,
        usesCredit: usesCredit,
        onConfirm: () {
          Navigator.pop(ctx);
          context.read<MemberBloc>().add(
            BookingRequested(
              serviceTypeId: service.serviceType.id,
              clinicId: clinic.id,
              bookingDate: _selectedDate,
              timeSlot: slot,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeGrid(
    BuildContext context,
    List<String> slotGroup,
    int offset,
  ) {
    final cs = Theme.of(context).colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.0,
      ),
      itemCount: slotGroup.length,
      itemBuilder: (context, i) {
        final slotIndex = offset + i;
        final isSelected = _selectedSlot == slotIndex;
        return GestureDetector(
          onTap: widget.isSubmitting
              ? null
              : () => setState(() => _selectedSlot = slotIndex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected ? cs.primary : cs.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? cs.primary : cs.outline,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Center(
              child: Text(
                slotGroup[i],
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : cs.onSurface,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final canSubmit =
        _selectedService != null &&
        _selectedSlot != null &&
        _selectedClinic != null &&
        !widget.isSubmitting;

    final usesCredit = (_selectedService?.remainingSessions ?? 0) > 0;

    final upcoming = widget.bookings
        .where(
          (b) =>
              b.status != BookingStatus.cancelled &&
              !b.bookingDate.isBefore(DateTime.now()),
        )
        .toList();

    String? disabledReason;
    if (_selectedService == null) {
      disabledReason = 'Select a service to continue';
    } else if (_selectedClinic == null) {
      disabledReason = 'Select a clinic to continue';
    } else if (_selectedSlot == null) {
      disabledReason = 'Select a time slot to continue';
    }

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Screen title ───────────────────────────────────────────────
              Text(
                _selectedPet != null
                    ? 'Book for ${_capFirst(_selectedPet!.name)}'
                    : 'Book a Session',
                style: tt.displaySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Covered sessions are confirmed instantly. Other service requests are reviewed by our team.',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 24),

              // ── Upcoming bookings ──────────────────────────────────────────
              if (upcoming.isNotEmpty) ...[
                Text('Upcoming', style: tt.headlineSmall),
                const SizedBox(height: 10),
                ...upcoming.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _BookingCard(
                      booking: b,
                      member: widget.member,
                      onCancel: b.status == BookingStatus.pending
                          ? () => _confirmCancel(context, b)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        size: 18,
                        color: cs.secondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No upcoming sessions. Your next booking will appear here.',
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // ── Pet selector ───────────────────────────────────────────────
              if (widget.member.pets.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.pets_rounded, size: 13, color: AppColors.gold),
                    const SizedBox(width: 6),
                    Text(
                      'BOOKING FOR',
                      style: tt.labelSmall?.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: widget.member.pets.map((pet) {
                      final isSelected = pet.id == _selectedPet?.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: widget.isSubmitting
                              ? null
                              : () => setState(() {
                                  _selectedPet = pet;
                                  final valid = pet.petServices;
                                  if (_selectedService != null &&
                                      !valid.any(
                                        (s) => s.id == _selectedService!.id,
                                      )) {
                                    _selectedService = null;
                                    _selectedSlot = null;
                                  }
                                }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? cs.primary : cs.surface,
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: isSelected ? cs.primary : cs.outline,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PetAvatar(
                                  photoUrl: pet.photoUrl,
                                  size: 22,
                                  petName: pet.name,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _capFirst(pet.name),
                                  style: tt.labelLarge?.copyWith(
                                    color: isSelected
                                        ? Colors.white
                                        : cs.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── Service picker ─────────────────────────────────────────────
              Text('Service', style: tt.headlineSmall),
              const SizedBox(height: 10),
              if (_bookableServices.isEmpty)
                const _NoServicesCard()
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.86,
                  ),
                  itemCount: _bookableServices.length,
                  itemBuilder: (context, i) {
                    final s = _bookableServices[i];
                    final isSelected = s.id == _selectedService?.id;
                    final hasCredit = s.remainingSessions > 0;
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    final cardBg = isSelected
                        ? AppColors.navy
                        : (isDark ? AppDarkColors.surface : cs.surface);
                    final borderColor = isSelected
                        ? AppColors.gold.withValues(alpha: 0.55)
                        : (isDark ? AppDarkColors.border : cs.outline);
                    final iconColor = isSelected
                        ? AppColors.gold
                        : (isDark ? AppDarkColors.subtext : AppColors.grey);
                    final nameColor = isSelected
                        ? AppColors.gold
                        : (isDark ? AppDarkColors.subtext : AppColors.grey);
                    final countColor = isSelected
                        ? (hasCredit
                              ? AppColors.gold.withValues(alpha: 0.65)
                              : AppColors.white.withValues(alpha: 0.3))
                        : (isDark
                              ? AppDarkColors.subtext.withValues(alpha: 0.6)
                              : AppColors.grey.withValues(alpha: 0.6));
                    return Semantics(
                      label:
                          '${s.serviceType.name}, '
                          '${s.remainingSessions} of ${s.totalSessions} sessions'
                          '${isSelected ? ', selected' : ''}',
                      button: true,
                      selected: isSelected,
                      child: GestureDetector(
                        onTap: widget.isSubmitting
                            ? null
                            : () => setState(
                                () => _selectedService = isSelected ? null : s,
                              ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: borderColor,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _iconForService(s.serviceType.name),
                                size: 26,
                                color: iconColor,
                              ),
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Text(
                                  s.serviceType.name,
                                  style: tt.labelSmall?.copyWith(
                                    color: nameColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    letterSpacing: 0.1,
                                    height: 1.3,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${s.remainingSessions}/${s.totalSessions}',
                                style: tt.labelSmall?.copyWith(
                                  color: countColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

              if (_bookableServices.isNotEmpty) ...[
                // ── Session credit chip (after service selection) ───────────────
                if (_selectedService != null && usesCredit) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: cs.secondary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 15,
                          color: cs.secondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_selectedService!.remainingSessions} ${_selectedService!.serviceType.name} session${_selectedService!.remainingSessions == 1 ? '' : 's'} covered',
                          style: tt.labelSmall?.copyWith(
                            color: cs.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),

                // ── Clinic picker ──────────────────────────────────────────────
                Text('Clinic', style: tt.headlineSmall),
                const SizedBox(height: 10),
                if (_clinics.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outline),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Loading clinics…',
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Semantics(
                    label: _selectedClinic != null
                        ? 'Clinic: ${_selectedClinic!.clinicName}. Tap to change.'
                        : 'Select a clinic',
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: widget.isSubmitting
                          ? null
                          : () => _pickClinic(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedClinic != null
                              ? cs.secondaryContainer
                              : cs.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedClinic != null
                                ? cs.secondary
                                : cs.outline,
                            width: _selectedClinic != null ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (_selectedClinic != null) ...[
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.gold.withValues(
                                      alpha: 0.45,
                                    ),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    _clinicInitials(
                                      _selectedClinic!.clinicName,
                                    ),
                                    style: tt.labelSmall?.copyWith(
                                      color: AppColors.gold,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedClinic!.clinicName,
                                      style: tt.labelLarge?.copyWith(
                                        color: cs.secondary,
                                      ),
                                    ),
                                    if (_selectedClinic!.address != null)
                                      Text(
                                        _selectedClinic!.address!,
                                        style: tt.bodyMedium?.copyWith(
                                          fontSize: 12,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              Icon(
                                Icons.location_on_outlined,
                                size: 18,
                                color: AppColors.gold.withValues(alpha: 0.45),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Select a clinic',
                                  style: tt.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                            Icon(
                              Icons.expand_more_rounded,
                              size: 20,
                              color: _selectedClinic != null
                                  ? AppColors.gold.withValues(alpha: 0.55)
                                  : cs.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── Date + Time ────────────────────────────────────────────────
                const SizedBox(height: 32),
                Text('Date', style: tt.headlineSmall),
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: widget.isSubmitting ? null : _pickDate,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatDate(_selectedDate),
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: AppColors.gold.withValues(alpha: 0.55),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                Text('Time', style: tt.headlineSmall),
                const SizedBox(height: 10),
                Text(
                  'Morning',
                  style: tt.labelLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _buildTimeGrid(context, _morningSlots, 0),
                const SizedBox(height: 20),
                Text(
                  'Afternoon',
                  style: tt.labelLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _buildTimeGrid(context, _afternoonSlots, _morningSlots.length),
                const SizedBox(height: 16),
                Text(
                  'Our team will reach out to confirm your visit.',
                  style: tt.bodyMedium?.copyWith(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(top: BorderSide(color: cs.outline)),
              ),
              child: widget.isSubmitting
                  ? Center(child: CircularProgressIndicator(color: cs.primary))
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_selectedSlot != null && _selectedPet != null) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                PetAvatar(
                                  photoUrl: _selectedPet!.photoUrl,
                                  size: 24,
                                  petName: _selectedPet!.name,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${_capFirst(_selectedPet!.name)} · ${_formatDate(_selectedDate)} · ${_slots[_selectedSlot!]}',
                                    style: tt.bodyMedium?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        MpButton(
                          label: usesCredit
                              ? 'Book a Session'
                              : 'Request Booking',
                          onPressed: canSubmit ? _submit : null,
                          gold: usesCredit,
                        ),
                        if (!canSubmit && disabledReason != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            disabledReason,
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmCancel(BuildContext context, Booking booking) {
    final bloc = context.read<MemberBloc>();
    showDialog<void>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Cancel this booking?'),
        content: Text(
          booking.creditUsed
              ? 'Your session will be returned to your membership plan.'
              : 'This booking will be cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dCtx);
              bloc.add(BookingCancelRequested(booking.id));
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dCtx).colorScheme.error,
            ),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final Member member;
  final VoidCallback? onCancel;

  const _BookingCard({
    required this.booking,
    required this.member,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isPending = booking.status == BookingStatus.pending;
    final isConfirmedWithCredit =
        booking.status == BookingStatus.confirmed && booking.creditUsed;

    final statusLabel = isPending
        ? 'Awaiting confirmation'
        : (booking.creditUsed ? 'Session confirmed' : 'Confirmed');
    final statusColor = isConfirmedWithCredit
        ? AppColors.gold
        : isPending
        ? cs.secondary
        : cs.primary;
    final statusBg = isConfirmedWithCredit
        ? AppColors.goldLight
        : isPending
        ? cs.secondaryContainer
        : cs.surfaceContainerHighest;

    final tier = tierStyleFor(member.planType ?? 'Standard', isDark: isDark);
    final cardColor = isDark ? tier.cardSurface : cs.surface;
    final borderColor = isDark ? tier.borderColor : cs.outline;

    // Show pet avatar only when unambiguous (single pet)
    final pet = member.pets.length == 1 ? member.pets.first : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pet != null) ...[
                PetAvatar(photoUrl: pet.photoUrl, size: 36, petName: pet.name),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.serviceType.name,
                      style: tt.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (pet != null)
                      Text(
                        _capFirst(pet.name),
                        style: tt.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: tt.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.access_time_outlined,
                size: 13,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                '${_formatDate(booking.bookingDate)} · ${booking.timeSlot}',
                style: tt.bodyMedium?.copyWith(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (booking.clinic != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 13,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    booking.clinic!.clinicName,
                    style: tt.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (onCancel != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: cs.error,
                  minimumSize: const Size(44, 36),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                child: Text(
                  'Cancel booking',
                  style: tt.labelSmall?.copyWith(
                    color: cs.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Booking Confirmation Sheet ─────────────────────────────────────────────

String _clinicInitials(String name) {
  final words = name.split(' ').where((w) => w.isNotEmpty).toList();
  if (words.length >= 2) return '${words[0][0]}${words[1][0]}'.toUpperCase();
  return name.substring(0, name.length < 2 ? name.length : 2).toUpperCase();
}

// ── Clinic Picker Bottom Sheet ────────────────────────────────────────────

class _ClinicPickerSheet extends StatefulWidget {
  final List<ClinicPartner> clinics;
  final ClinicPartner? selectedClinic;
  final ValueChanged<ClinicPartner> onSelected;

  const _ClinicPickerSheet({
    required this.clinics,
    required this.selectedClinic,
    required this.onSelected,
  });

  @override
  State<_ClinicPickerSheet> createState() => _ClinicPickerSheetState();
}

class _ClinicPickerSheetState extends State<_ClinicPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<ClinicPartner> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.clinics;
    _searchCtrl.addListener(_onSearch);
  }

  void _onSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.clinics
          : widget.clinics
                .where(
                  (c) =>
                      c.clinicName.toLowerCase().contains(q) ||
                      (c.address?.toLowerCase().contains(q) ?? false),
                )
                .toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppDarkColors.surface : AppColors.white;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outline.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text('Choose a Clinic', style: tt.headlineSmall),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: tt.bodyMedium?.copyWith(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'Search clinics…',
                hintStyle: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                        onPressed: () => _searchCtrl.clear(),
                        tooltip: 'Clear',
                      )
                    : null,
                filled: true,
                fillColor: isDark
                    ? AppDarkColors.elevated
                    : AppColors.greyLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Results
          Flexible(
            child: _filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 32,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No clinics match "${_searchCtrl.text}"',
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + bottomPad),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: cs.outline.withValues(alpha: 0.3),
                    ),
                    itemBuilder: (context, i) {
                      final clinic = _filtered[i];
                      final isSelected = clinic.id == widget.selectedClinic?.id;
                      return InkWell(
                        onTap: () => widget.onSelected(clinic),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.navy
                                      : (isDark
                                            ? AppDarkColors.elevated
                                            : cs.surfaceContainerHighest),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    _clinicInitials(clinic.clinicName),
                                    style: tt.labelSmall?.copyWith(
                                      color: isSelected
                                          ? AppColors.gold
                                          : cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      clinic.clinicName,
                                      style: tt.labelLarge?.copyWith(
                                        color: isSelected
                                            ? cs.primary
                                            : cs.onSurface,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                      ),
                                    ),
                                    if (clinic.address != null)
                                      Text(
                                        clinic.address!,
                                        style: tt.bodyMedium?.copyWith(
                                          fontSize: 12,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: AppColors.gold,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _BookingConfirmSheet extends StatelessWidget {
  final Pet? pet;
  final Member member;
  final PetService service;
  final ClinicPartner clinic;
  final DateTime date;
  final String timeSlot;
  final bool usesCredit;
  final VoidCallback onConfirm;

  const _BookingConfirmSheet({
    required this.pet,
    required this.member,
    required this.service,
    required this.clinic,
    required this.date,
    required this.timeSlot,
    required this.usesCredit,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomPad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (pet != null) ...[
                PetAvatar(
                  photoUrl: pet!.photoUrl,
                  size: 56,
                  petName: pet!.name,
                ),
                const SizedBox(height: 10),
                Text(
                  _capFirst(pet!.name),
                  style: tt.displaySmall?.copyWith(color: AppColors.navy),
                ),
                const SizedBox(height: 20),
              ] else ...[
                const Icon(Icons.pets_rounded, size: 40, color: AppColors.gold),
                const SizedBox(height: 16),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: usesCredit
                      ? AppColors.goldLight
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _ConfirmRow(
                      icon: Icons.spa_outlined,
                      label: 'Service',
                      value: service.serviceType.name,
                    ),
                    const SizedBox(height: 10),
                    _ConfirmRow(
                      icon: Icons.location_on_outlined,
                      label: 'Clinic',
                      value: clinic.clinicName,
                    ),
                    const SizedBox(height: 10),
                    _ConfirmRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Date',
                      value: _formatDate(date),
                    ),
                    const SizedBox(height: 10),
                    _ConfirmRow(
                      icon: Icons.access_time_outlined,
                      label: 'Time',
                      value: timeSlot,
                    ),
                  ],
                ),
              ),
              if (usesCredit) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.goldLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 16,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '1 ${service.serviceType.name} session will be applied.',
                          style: tt.labelSmall?.copyWith(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              MpButton(
                label: pet != null
                    ? 'Confirm ${_capFirst(pet!.name)}\'s Session'
                    : 'Confirm Booking',
                onPressed: onConfirm,
                gold: usesCredit,
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: cs.onSurfaceVariant,
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: Text(
                  'Go back',
                  style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ConfirmRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 10),
        Text(label, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: tt.labelLarge?.copyWith(color: cs.onSurface),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Account Tab ────────────────────────────────────────────────────────────

class _AccountView extends StatelessWidget {
  final Member member;
  const _AccountView({required this.member});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20 + kNavClearance),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + name header
          Center(
            child: Column(
              children: [
                _AccountAvatar(member: member),
                const SizedBox(height: 12),
                Text(
                  member.fullName,
                  style: Theme.of(context).textTheme.headlineMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Contact info
          _AccountSection(
            children: [
              if (member.phone != null)
                _AccountRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: member.phone!,
                ),
              if (member.address != null)
                _AccountRow(
                  icon: Icons.location_on_outlined,
                  label: 'Address',
                  value: member.address!,
                ),
              _AccountRow(
                icon: Icons.calendar_today_outlined,
                label: 'Member since',
                value:
                    '${member.joinedAt.day} ${_month(member.joinedAt.month)} ${member.joinedAt.year}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Payout method — where approved reimbursements are sent
          _AccountSection(
            children: [
              _AccountRow(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Payout method',
                value: _payoutSummary(member),
                // Gold nudge when nothing is set yet — it's an action to take.
                valueColor: member.hasPayoutMethod ? null : AppColors.gold,
                onTap: () {
                  final bloc = context.read<MemberBloc>();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: bloc,
                        child: PayoutDetailsScreen(member: member),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Appearance picker removed 2026-08-17: the app is LIGHT ONLY, so a
          // control that cannot change anything would be worse than none.
          // main.dart pins ThemeMode.light; ThemeCubit and buildDarkTheme()
          // are still wired, so restoring this means putting the picker back
          // and returning `themeMode` to the MaterialApp.
          const SizedBox(height: 12),
          // Documents — open in the browser (URLs follow the build ENV)
          _AccountSection(
            children: [
              _AccountRow(
                icon: Icons.menu_book_outlined,
                label: 'Member Manual',
                value: '',
                onTap: () => _launchUrl(context, ApiConstants.manualUrl),
              ),
              _AccountRow(
                icon: Icons.description_outlined,
                label: 'Membership Agreement',
                value: '',
                onTap: () => _launchUrl(context, ApiConstants.agreementUrl),
              ),
              _AccountRow(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                value: '',
                onTap: () => _launchUrl(context, ApiConstants.privacyUrl),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Sign out
          _AccountSection(
            children: [
              _AccountRow(
                icon: Icons.logout,
                label: 'Sign out',
                value: '',
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Sign out?'),
                      content: const Text(
                        "You'll need to sign in again to access your account.",
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
          // App version — helps support, and flags a non-prod build in the field
          Center(
            child: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox(height: 16);
                final info = snap.data!;
                final envSuffix = ApiConstants.isProd
                    ? ''
                    : ' · ${ApiConstants.env}';
                return Text(
                  'MetroPaws v${info.version} (${info.buildNumber})$envSuffix',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the link. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _payoutSummary(Member m) {
    switch (m.payoutMethod) {
      case 'gcash':
        return 'GCash';
      case 'bank':
        return (m.payoutBankName ?? '').isNotEmpty
            ? 'Bank · ${m.payoutBankName}'
            : 'Bank transfer';
      case 'cash':
        return 'Cash pickup';
      default:
        return 'Add payout method';
    }
  }

  String _month(int m) => const [
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
  ][m - 1];
}

/// The member's profile avatar: shows their photo (falling back to initials),
/// with a gold camera badge to change it. Tapping picks a photo and uploads it
/// via [ProfilePhotoUpdateRequested]; a spinner overlays while saving, and a
/// failure surfaces a snackbar. Mirrors the pet photo-pick rules (JPG/PNG, 5MB).
class _AccountAvatar extends StatelessWidget {
  final Member member;
  const _AccountAvatar({required this.member});

  static const _maxPhotoBytes = 5 * 1024 * 1024; // 5 MB
  static const _allowedExts = {'jpg', 'jpeg', 'png'};

  Future<void> _pickAndUpload(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final bloc = context.read<MemberBloc>();
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    final ext = picked.name.split('.').last.toLowerCase();
    if (!_allowedExts.contains(ext)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Only JPG and PNG files are allowed.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final bytes = await picked.readAsBytes();
    if (bytes.length > _maxPhotoBytes) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Photo must be under 5 MB.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    bloc.add(ProfilePhotoUpdateRequested(photoBytes: bytes, photoExt: ext));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MemberBloc, MemberState>(
      // Only the photo-save lifecycle drives this widget; the rest of the
      // shared-bloc churn is handled by the parent tab.
      listenWhen: (_, s) => s is ProfilePhotoSaveFailure,
      listener: (context, state) {
        if (state is ProfilePhotoSaveFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      buildWhen: (_, s) =>
          s is ProfilePhotoSaving ||
          s is ProfilePhotoSaveSuccess ||
          s is ProfilePhotoSaveFailure,
      builder: (context, state) {
        final saving = state is ProfilePhotoSaving;
        final photoUrl = member.photoUrl;

        return Semantics(
          button: true,
          label: 'Profile photo. Double tap to change it.',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: saving ? null : () => _pickAndUpload(context),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.navy,
                    border: Border.all(color: AppColors.gold, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: photoUrl != null
                      ? Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _initials(context),
                          loadingBuilder: (ctx, child, progress) =>
                              progress == null ? child : _initials(context),
                        )
                      : _initials(context),
                ),
                if (saving)
                  Positioned.fill(
                    child: ClipOval(
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.45),
                        child: const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.gold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.photo_camera_rounded,
                      size: 15,
                      color: AppColors.text,
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

  Widget _initials(BuildContext context) => Center(
    child: Text(
      '${member.firstName[0]}${member.lastName[0]}',
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
        color: AppColors.gold,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _AccountSection extends StatelessWidget {
  final List<Widget> children;
  const _AccountSection({required this.children});

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

class _AccountRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool destructive;
  // Overrides the muted value color — used to gold-highlight an unset payout.
  final Color? valueColor;

  const _AccountRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.destructive = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final errorRed = Theme.of(context).colorScheme.error;
    final textColor = destructive ? errorRed : cs.onSurface;
    final iconColor = destructive ? errorRed : cs.onSurfaceVariant;
    // A chevron marks rows that navigate or open something; destructive
    // actions (Sign out) and static info rows (Phone) get none.
    final showChevron = onTap != null && !destructive;

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
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: valueColor ?? cs.onSurfaceVariant,
                    fontWeight: valueColor != null ? FontWeight.w600 : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            if (showChevron) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Dashboard Skeleton ─────────────────────────────────────────────────────

class _DashboardSkeleton extends StatefulWidget {
  const _DashboardSkeleton({super.key});

  @override
  State<_DashboardSkeleton> createState() => _DashboardSkeletonState();
}

class _DashboardSkeletonState extends State<_DashboardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blockColor = isDark ? AppDarkColors.elevated : AppColors.greyLight;

    Widget block({
      double width = double.infinity,
      required double height,
      double radius = 8,
    }) {
      return AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) =>
            Opacity(opacity: 0.45 + _pulse.value * 0.35, child: child),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: blockColor,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      );
    }

    // Placeholders that sit ON the navy header can't use greyLight — they'd be
    // brighter than the finished content. A white wash reads as "text loading"
    // against navy the way greyLight does against cream.
    Widget navyBlock({
      double width = double.infinity,
      required double height,
      double radius = 8,
    }) {
      return AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) =>
            Opacity(opacity: 0.35 + _pulse.value * 0.25, child: child),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.30),
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: kNavClearance),
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mirrors _Dashboard's navy header, so the AnimatedSwitcher crossfade
          // is content appearing rather than the whole page changing shape.
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                navyBlock(width: 110, height: 14, radius: 7),
                const SizedBox(height: 8),
                navyBlock(width: 190, height: 30, radius: 10),
                const SizedBox(height: 12),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.onNavyDivider,
                ),
                const SizedBox(height: 14),
                navyBlock(height: 30, radius: 8),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: block(width: 120, height: 20, radius: 8),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: block(height: 420, radius: 16),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Account Skeleton ──────────────────────────────────────────────────────

class _AccountSkeleton extends StatefulWidget {
  const _AccountSkeleton();

  @override
  State<_AccountSkeleton> createState() => _AccountSkeletonState();
}

class _AccountSkeletonState extends State<_AccountSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blockColor = isDark ? AppDarkColors.elevated : AppColors.greyLight;

    Widget block({
      double width = double.infinity,
      required double height,
      double radius = 8,
    }) {
      return AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) =>
            Opacity(opacity: 0.45 + _pulse.value * 0.35, child: child),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: blockColor,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20 + kNavClearance),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + name
          Center(
            child: Column(
              children: [
                block(width: 80, height: 80, radius: 40),
                const SizedBox(height: 12),
                block(width: 160, height: 22, radius: 8),
                const SizedBox(height: 8),
                block(width: 72, height: 22, radius: 11),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Info rows section
          block(height: 140, radius: 12),
          const SizedBox(height: 12),
          // Appearance section
          block(height: 88, radius: 12),
          const SizedBox(height: 12),
          // Sign out section
          block(height: 52, radius: 12),
        ],
      ),
    );
  }
}

// ── Error view ─────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets, size: 48, color: cs.outline),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

// ── Bottom Nav Bar ─────────────────────────────────────────────────────────

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

class _MpNavBar extends StatelessWidget {
  final int currentIndex;
  final bool bookingEnabled;
  final ValueChanged<int> onTap;
  // The raised center action — files a claim. It's an ACTION (pushes the Submit
  // form), not a tab, so it has no IndexedStack index.
  final VoidCallback onClaim;

  const _MpNavBar({
    required this.currentIndex,
    required this.bookingEnabled,
    required this.onTap,
    required this.onClaim,
  });

  // Slot 2 mirrors the shell's IndexedStack: Book when booking_enabled is ON,
  // otherwise Events & Promos. Must stay in lockstep with _MemberShellState's
  // children list order.
  List<_NavItem> get _tabs => [
    const _NavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
    ),
    bookingEnabled
        ? const _NavItem(
            icon: Icons.calendar_month_outlined,
            selectedIcon: Icons.calendar_month,
            label: 'Book',
          )
        : const _NavItem(
            icon: Icons.celebration_outlined,
            selectedIcon: Icons.celebration,
            label: 'Events',
          ),
    const _NavItem(
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
      label: 'Wallet',
    ),
    const _NavItem(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'Account',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // The capsule is navy. It was white-on-cream, so the only thing separating
    // the bar from the page was a shadow, and it left navy — the primary —
    // appearing once on the whole screen while gold did the structural work.
    // Navy here anchors the bottom, isolates the gold action, and supplies the
    // 30% band of the 60/30/10 split alongside the app bar and Home header.
    final bgColor = isDark ? AppDarkColors.elevated : AppColors.navy;
    // Gold on navy is 2.9:1 and fails even the 3:1 icon floor, so the active
    // tab is white, not gold. That's the point: gold belongs to the raised
    // Claim circle only, which makes it the single unmissable thing down here.
    final activeColor = AppColors.white;
    final inactiveColor = AppColors.onNavyMuted;
    // The page shows through the ring, so the circle reads as punched out of
    // the bar rather than stuck to it — and the ring, not the gold itself,
    // is what delineates the control against navy.
    final ringColor = Theme.of(context).scaffoldBackgroundColor;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final tabs = _tabs;

    // Four labelled tabs plus a 52px circle is the tightest thing in the app.
    // At 320dp the default insets leave ~50px of content per tab and "Account"
    // ellipsises to "Accoun…". Reclaiming the outer margin and the inter-tab
    // padding buys back ~9px each, which is the difference between a readable
    // label and a truncated one. Nothing is hidden — on a nav bar the label IS
    // the affordance, and these users span a wide age range.
    final tight = context.isNarrow;
    final sideInset = tight ? 8.0 : 16.0;
    final tabPad = tight ? 2.0 : 4.0;

    // Shared by the four tabs AND by the Claim caption's spacer, so the two
    // can never fall out of alignment when one is tweaked.
    final iconSize = tight ? 23.0 : 25.0;
    const labelSize = 10.0;

    Widget tabItem(int index, _NavItem tab) {
      final isSelected = index == currentIndex;
      return Expanded(
        // GestureDetector, not InkWell: the ink splash paints a rectangle that
        // escapes the capsule's rounded ends, so tapping Home or Account showed
        // a square corner poking out of the pill. The animated indicator below
        // is the tap feedback, so nothing is lost by dropping the ripple.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap(index),
          // Padding, not Center: the indicator fills the tab slot so it comes
          // out WIDER than it is tall — an oval. Hugging the content made it
          // roughly square, and a large radius on a square is a circle, not a
          // capsule. Filling the slot also hands the label the full width, which
          // is what stops "Account" ellipsizing.
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: tabPad, vertical: 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                // The indicator wraps the icon AND the label as one pill,
                // rather than sitting behind the icon alone — the two are one
                // control, and a pill around half of it reads as a stray chip.
                color: isSelected
                    ? activeColor.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSelected ? tab.selectedIcon : tab.icon,
                    size: iconSize,
                    color: isSelected ? activeColor : inactiveColor,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tab.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: labelSize,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected ? activeColor : inactiveColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Geometry for the floating bar. The lift is part of the bar's own height
    // rather than a transform: a child pushed outside its parent's box stops
    // receiving taps in the overflowing region, so the button would look
    // raised and then ignore the top half of every press.
    const barHeight = 62.0;
    const lift = 18.0;
    const circle = 52.0;

    // The raised gold action — visually distinct from the tabs so it reads as
    // "the thing to do", not a destination. Files a claim (opens Submit).
    final claimButton = Semantics(
      button: true,
      label: 'File a claim',
      child: InkWell(
        onTap: onClaim,
        customBorder: const CircleBorder(),
        child: Container(
          width: circle,
          height: circle,
          decoration: BoxDecoration(
            color: AppColors.gold,
            shape: BoxShape.circle,
            // Page-colored, not bar-colored: gold against navy is 2.9:1, so
            // the gold edge alone would not delineate the control. The cream
            // ring is 7.4:1 on navy and does that job, while reading as the
            // page showing through a hole in the bar.
            border: Border.all(color: ringColor, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.38),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.post_add, size: 24, color: AppColors.text),
        ),
      ),
    );

    return Padding(
      // Inset on every side so the bar reads as a lifted object with the page
      // running underneath, not a chrome strip welded to the bottom edge.
      padding: EdgeInsets.fromLTRB(
        sideInset,
        0,
        sideInset,
        (bottomPad > 0 ? bottomPad : 12) + 10,
      ),
      child: SizedBox(
        height: barHeight + lift,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: barHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(barHeight / 2),
                  // Two layers, because one blur cannot do both jobs. The
                  // tight shadow anchors the capsule to the surface; the wide,
                  // lower one is what actually reads as height. A single
                  // mid-blur shadow just looks like a soft edge. Navy-tinted
                  // rather than black now that the bar itself is navy — a
                  // neutral black shadow under a colored object reads as dirt.
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navy.withValues(
                        alpha: isDark ? 0.40 : 0.22,
                      ),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                    BoxShadow(
                      color: AppColors.navy.withValues(
                        alpha: isDark ? 0.50 : 0.28,
                      ),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                // Two tabs, a gap the raised action sits over, then two tabs.
                child: Row(
                  children: [
                    tabItem(0, tabs[0]),
                    tabItem(1, tabs[1]),
                    SizedBox(
                      width: circle + (tight ? 0 : 4),
                      // Mirrors a tab's column — an empty box where the icon
                      // would be, then the same 2px gap — so the caption lands
                      // on exactly the same baseline as the other four instead
                      // of being nudged there by a hand-tuned padding.
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(height: iconSize),
                            const SizedBox(height: 2),
                            Text(
                              'Claim',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    fontSize: labelSize,
                                    fontWeight: FontWeight.w700,
                                    // Navy-on-navy would have vanished; the
                                    // gold circle above it is what marks this
                                    // as the action, not the caption's color.
                                    color: activeColor,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    tabItem(2, tabs[2]),
                    tabItem(3, tabs[3]),
                  ],
                ),
              ),
            ),
            Positioned(top: 0, child: claimButton),
          ],
        ),
      ),
    );
  }
}
