import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/plan.dart';
import '../../../core/models/plan_quote.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/agreement_checkbox.dart';
import '../../../core/widgets/cadence_toggle.dart';
import '../../../core/widgets/mp_button.dart';
import '../../../core/widgets/mp_error_banner.dart';
import '../../../core/widgets/mp_help_sheet.dart';
import '../../../core/widgets/mp_text_field.dart';
import '../../../core/widgets/scale_button.dart';
import '../../../theme.dart';

const _kMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Quick-pick breeds offered under the breed field once a pet type is chosen.
/// They are a shortcut, never a constraint — the field stays free text, because
/// no list survives contact with a real membership. Aspin and Puspin lead each
/// list on purpose: they are the most common pets in Metro Manila, and a member
/// should not have to decide what to call them before they can continue.
const _kDogBreeds = [
  'Aspin', 'Shih Tzu', 'Poodle', 'Chihuahua', 'Beagle',
  'Golden Retriever', 'Labrador Retriever', 'Pomeranian', 'Mixed breed',
];
const _kCatBreeds = [
  'Puspin', 'Persian', 'Siamese', 'British Shorthair',
  'Bengal', 'Maine Coon', 'Mixed breed',
];

String _peso(int amount) => '₱${amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

// Strips technical backend details from plan-activation errors so members
// never see config/infra strings like "PAYMONGO_SECRET_KEY is not set".
String _friendlyPlanError(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('paymongo') ||
      lower.contains('secret') ||
      lower.contains('not set') ||
      lower.contains('provider') ||
      lower.contains('payment provider') ||
      lower.contains('config') ||
      lower.contains('environment')) {
    return "We can't complete online payment right now. "
        'Please contact MetroPaws to activate your membership.';
  }
  return raw;
}

/// The images registration collects. The first three are the identity photos
/// required by MP-FRM-PET-001 (slots 1-3); the vaccination card is optional and
/// starts the pet's health record. Holding them in one enum is what lets a
/// single picker serve all four — the four near-identical `_pickX` methods this
/// replaced meant the size check had to be remembered in four places.
enum _Shot { face, fullBody, withOwner, vaxCard }

class _Picked {
  const _Picked(this.bytes, this.ext);
  final Uint8List bytes;
  final String ext;
}

class AddPetScreen extends StatefulWidget {
  const AddPetScreen({super.key});

  @override
  State<AddPetScreen> createState() => _AddPetScreenState();
}

class _AddPetScreenState extends State<AddPetScreen> {
  // The flow is Details → Photos → Plan → Done. Photos used to share the first
  // step with all ten detail fields, which put the single largest ask — three
  // pictures — above a name field the member had not filled in yet, and left
  // the vaccination card alone on a step of its own. The steps are balanced
  // now: identity, then evidence, then money.
  static const _stepDetails = 0;
  static const _stepPhotos = 1;
  static const _stepPlan = 2;
  static const _stepDone = 3;

  static const _requiredShots = [_Shot.face, _Shot.fullBody, _Shot.withOwner];

  int _step = _stepDetails;
  bool _isLoading = false;
  String? _error;

  // Pet details
  final _formKey = GlobalKey<FormState>();
  final _scrollCtrl = ScrollController();
  final _nameCtrl = TextEditingController();
  final _breedCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  final _breedFocus = FocusNode();
  final _weightFocus = FocusNode();

  // Anchors for "carry the view to the first thing that's wrong". An error
  // rendered two screens below the fold is the same as no error at all.
  final _nameKey = GlobalKey();
  final _speciesKey = GlobalKey();
  final _sexKey = GlobalKey();
  final _breedKey = GlobalKey();
  final _birthKey = GlobalKey();
  final _weightKey = GlobalKey();

  String? _species;
  String? _sex;

  int? _birthMonth;
  int? _birthYear;
  int? _birthDay;

  /// Gates the birth group's error until Continue is pressed. Nothing here can
  /// be half-entered — every value arrives from a picker — so there is no
  /// mid-typing state to nag about.
  bool _birthChecked = false;

  final Map<_Shot, _Picked> _shots = {};

  /// Set when Continue is pressed on the photos step with a slot still empty,
  /// so the missing rows mark themselves. The old flow reported this in a
  /// snackbar, which named no slot and was gone before the member looked up.
  bool _shotsChecked = false;

  // Plan selection
  List<Plan> _plans = [];
  Map<String, PlanQuote> _quotes = {};
  bool _plansLoading = true;
  String? _selectedPlanId;

  /// 'annual' or 'monthly'. Registration is the other place a plan is
  /// bought, so it has to offer the same choice as PlanSelectionScreen --
  /// a member who signs up here would otherwise never see monthly at all.
  String _cadence = 'annual';
  bool _agreementAccepted = false;

  // Post-activation payment tracking. The payment id MUST be kept: polling
  // GET /payments/{id} is what reconciles + activates the plan server-side
  // when the webhook never reaches this environment. Losing it once left a
  // PayMongo-paid plan stuck on "No active plan" (2026-07-07).
  String? _checkoutUrl;
  String? _paymentId;
  bool _paid = false;
  Timer? _pollTimer;
  bool _checkingPayment = false;
  StreamSubscription<Uri>? _linkSub;

  // Guards against double-tap and retry-after-partial-failure
  bool _activating = false;
  String? _createdPetId;

  @override
  void initState() {
    super.initState();
    _loadPlans();
    // Catch the metropaws://payment/... deep link fired by the backend's
    // return page after PayMongo checkout, so returning to the app verifies
    // the payment immediately instead of waiting for the next poll tick.
    _linkSub = AppLinks().uriLinkStream.listen((uri) {
      if (!mounted) return;
      if (uri.scheme == 'metropaws' && uri.host == 'payment') {
        _checkPayment();
      }
    });
  }

  Future<void> _loadPlans() async {
    try {
      final results = await Future.wait([
        ApiService.fetchPlans(),
        // Pack Discount quotes (no petId — this pet doesn't exist yet, so
        // every current pet anchors). Enhancement only: on failure plans
        // render at full price and the backend still discounts at checkout.
        ApiService.fetchPlanQuotes()
            .then<List<PlanQuote>>((q) => q)
            .catchError((_) => <PlanQuote>[]),
      ]);
      if (mounted) {
        setState(() {
          _plans = results[0] as List<Plan>;
          _quotes = {
            for (final q in results[1] as List<PlanQuote>) q.planId: q,
          };
          _plansLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _plansLoading = false);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _linkSub?.cancel();
    _scrollCtrl.dispose();
    _nameCtrl.dispose();
    _breedCtrl.dispose();
    _weightCtrl.dispose();
    _notesCtrl.dispose();
    _nameFocus.dispose();
    _breedFocus.dispose();
    _weightFocus.dispose();
    super.dispose();
  }

  // ─── Navigation ─────────────────────────────────────────────────────────

  String get _petName => _nameCtrl.text.trim();

  bool get _hasInput =>
      _petName.isNotEmpty ||
      _breedCtrl.text.trim().isNotEmpty ||
      _weightCtrl.text.trim().isNotEmpty ||
      _notesCtrl.text.trim().isNotEmpty ||
      _species != null ||
      _sex != null ||
      _birthMonth != null ||
      _birthYear != null ||
      _shots.isNotEmpty;

  /// The single exit path, shared by the app-bar arrow and the Android system
  /// back gesture. Before this the gesture bypassed the step machine entirely:
  /// three photos and ten fields in, one swipe discarded the lot, unasked.
  Future<void> _handleBack() async {
    if (_step == _stepDone) {
      Navigator.pop(context, true);
      return;
    }
    if (_step > _stepDetails) {
      setState(() {
        _step--;
        _error = null;
      });
      _resetScroll();
      return;
    }
    // The pet already exists server-side when createPet succeeded and only
    // activation failed. Leaving now must still tell the dashboard to refresh,
    // or the member lands on Home with no sign of the pet they just added.
    if (_createdPetId != null) {
      Navigator.pop(context, true);
      return;
    }
    if (!_hasInput) {
      Navigator.pop(context, false);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard this pet?'),
        content: Text(
          _petName.isEmpty
              ? "You haven't finished adding your pet. Leaving now discards "
                  'what you entered.'
              : "You haven't finished adding $_petName. Leaving now discards "
                  'what you entered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if ((discard ?? false) && mounted) Navigator.pop(context, false);
  }

  void _resetScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    });
  }

  void _nextStep() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_step == _stepDetails && !_detailsAreComplete()) return;
    if (_step == _stepPhotos && !_photosAreComplete()) return;
    setState(() {
      _step++;
      _error = null;
    });
    _resetScroll();
  }

  /// Runs the form's own validators — which paint the inline errors — and then
  /// carries the view to the first field that failed. Every one of these used
  /// to be a snackbar fired from `_nextStep`, so the message named the problem
  /// at the bottom of the screen while the field sat untouched further up.
  bool _detailsAreComplete() {
    // Arm the birth group before validating: its fields report through the
    // Form, but only once the member has been given a reason to see them.
    if (_birthError != null && !_birthChecked) {
      setState(() => _birthChecked = true);
    }
    final valid = _formKey.currentState?.validate() ?? false;
    final firstProblem = _firstIncompleteField();
    if (firstProblem != null) {
      _scrollTo(firstProblem);
      return false;
    }
    return valid;
  }

  GlobalKey? _firstIncompleteField() {
    if (_petName.isEmpty) return _nameKey;
    if (_species == null) return _speciesKey;
    if (_sex == null) return _sexKey;
    if (_breedCtrl.text.trim().isEmpty) return _breedKey;
    if (_birthError != null) return _birthKey;
    final weight = double.tryParse(_weightCtrl.text.trim());
    if (weight == null || weight <= 0 || weight > 200) return _weightKey;
    return null;
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      alignment: 0.1,
    );
  }

  bool _photosAreComplete() {
    if (_requiredShots.any((s) => _shots[s] == null)) {
      setState(() => _shotsChecked = true);
      return false;
    }
    return true;
  }

  // ─── Birth date ─────────────────────────────────────────────────────────

  /// Day 0 of the following month is the last day of this one.
  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  /// The birth group's single error. Everything arrives from a picker, so the
  /// only things left to catch are a missing choice and a date in the future —
  /// the day list is already cut to the chosen month, which is what stopped 31
  /// February reaching the backend.
  String? get _birthError {
    // The wheel always returns a month AND a year together, so the two
    // separate "choose a month" / "choose a year" branches this used to have
    // were unreachable — and they spoke as though there were still two
    // controls to point at.
    if (_birthMonth == null || _birthYear == null) {
      return 'Choose a date of birth';
    }

    final born = DateTime(_birthYear!, _birthMonth!, _birthDay ?? 1);
    final today = DateTime.now();
    if (born.isAfter(DateTime(today.year, today.month, today.day))) {
      return "That date hasn't happened yet";
    }
    return null;
  }

  /// "Pay ₱3,999 →", or a plain label if the price isn't known.
  String _payLabel() {
    final plan = _selectedPlan;
    if (plan == null) return 'Complete payment →';
    final monthly = _cadence == 'monthly' && plan.priceMonthly != null;
    final amount = monthly
        ? plan.priceMonthly!
        : (_quotes[plan.id]?.finalPhp ?? plan.price);
    return 'Pay ${_peso(amount)} →';
  }

  Plan? get _selectedPlan {
    for (final plan in _plans) {
      if (plan.id == _selectedPlanId) return plan;
    }
    return null;
  }

  /// What the three boxes add up to, in words: "11 March 2023 · about 3 years
  /// and 5 months old". Null until the group parses cleanly.
  String? _birthSummary() {
    final month = _birthMonth;
    final year = _birthYear;
    if (month == null || year == null || _birthError != null) return null;
    final day = _birthDay;
    final name = _kMonths[month - 1];
    final date = day == null ? '$name $year' : '$day $name $year';
    return '$date · ${_ageLabel(year, month, day)}';
  }

  /// Reads as an age, not a duration.
  static String _ageLabel(int year, int month, int? day) {
    final now = DateTime.now();
    final born = DateTime(year, month, day ?? 1);
    var months = (now.year - born.year) * 12 + (now.month - born.month);
    if (now.day < born.day) months--;
    if (months < 0) months = 0;
    if (months == 0) return 'under a month old';
    if (months < 12) return 'about $months months old';
    final years = months ~/ 12;
    final rest = months % 12;
    final yearPart = years == 1 ? '1 year' : '$years years';
    if (rest == 0) return 'about $yearPart old';
    final monthPart = rest == 1 ? '1 month' : '$rest months';
    return 'about $yearPart and $monthPart old';
  }

  // ─── Photos ─────────────────────────────────────────────────────────────

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// One picker for all four slots. It offers the camera as well as the
  /// gallery: a member standing next to the pet they are registering should not
  /// have to leave the app, shoot, and come back. `CAMERA` is already declared
  /// and used by the claims flow — no media permission is involved, because
  /// image_picker goes through the system photo picker.
  Future<void> _pickInto(_Shot shot) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PhotoSourceSheet(),
    );
    if (source == null || !mounted) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: shot == _Shot.vaxCard ? 90 : 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      // Reject an oversized pick here, at the slot where it was chosen, rather
      // than letting the member reach checkout before finding out.
      if (bytes.length > ApiService.maxUploadBytes) {
        if (mounted) {
          _snack('That photo is over ${ApiService.maxUploadMb} MB. '
              'Please choose a smaller one.');
        }
        return;
      }
      // picked.name (not .path) — on web, XFile.path is a blob: URL with no
      // real extension, which sends the wrong extension to the backend.
      final ext = picked.name.split('.').last.toLowerCase();
      if (mounted) {
        setState(
          () => _shots[shot] = _Picked(bytes, ext == 'png' ? 'png' : 'jpg'),
        );
      }
    } catch (_) {
      if (mounted) _snack('Could not open that photo. Please try another.');
    }
  }

  void _removeShot(_Shot shot) => setState(() => _shots.remove(shot));

  void _showPhotoHelp() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _PhotoHelpSheet(),
    );
  }

  // ─── Activation ─────────────────────────────────────────────────────────

  Future<void> _activate() async {
    if (_selectedPlanId == null) return;
    if (_activating) return; // synchronous guard — prevents double-tap before rebuild
    _activating = true;
    setState(() { _isLoading = true; _error = null; });
    try {
      // Reuse the pet ID if the first createPet succeeded but activation failed
      // on a previous attempt (prevents duplicate pets on retry).
      final String petId;
      if (_createdPetId != null) {
        petId = _createdPetId!;
      } else {
        final pet = await ApiService.createPet(
          name: _petName,
          species: _species,
          sex: _sex?.toLowerCase(),
          birthMonth: _birthMonth!,
          birthYear: _birthYear!,
          birthDay: _birthDay,
          breed: _breedCtrl.text.trim(),
          weightKg: double.tryParse(_weightCtrl.text.trim()) ?? 0,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          photoBytes: _shots[_Shot.face]!.bytes,
          photoExt: _shots[_Shot.face]!.ext,
          fullBodyBytes: _shots[_Shot.fullBody]!.bytes,
          fullBodyExt: _shots[_Shot.fullBody]!.ext,
          ownerBytes: _shots[_Shot.withOwner]!.bytes,
          ownerExt: _shots[_Shot.withOwner]!.ext,
          vaxBytes: _shots[_Shot.vaxCard]?.bytes,
          vaxExt: _shots[_Shot.vaxCard]?.ext,
        );
        _createdPetId = pet.id;
        petId = pet.id;
      }

      final paymentsEnabled = await ApiService.fetchPaymentsEnabled();
      if (paymentsEnabled) {
        final checkout = await ApiService.createCheckout(
          _selectedPlanId!,
          petId,
          cadence: _cadence,
        );
        if (mounted) {
          setState(() {
            _checkoutUrl = checkout.checkoutUrl;
            _paymentId = checkout.paymentId;
            _step = _stepDone;
          });
          _resetScroll();
        }
      } else {
        await ApiService.activatePetPlan(petId, _selectedPlanId!);
        if (mounted) {
          setState(() => _step = _stepDone);
          _resetScroll();
        }
      }
    } on ApiException catch (e) {
      if (mounted) _failWith(_friendlyPlanError(e.message));
    } catch (_) {
      if (mounted) _failWith('Something went wrong. Please try again.');
    } finally {
      _activating = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// The error banner renders at the TOP of the plan step, and the member is
  /// at the FOOT of it — they just pressed the button in the pinned footer.
  /// Without carrying them back up, a failed activation looks like the spinner
  /// simply stopped.
  void _failWith(String message) {
    setState(() => _error = message);
    _resetScroll();
  }

  Future<void> _openCheckout() async {
    final uri = Uri.parse(_checkoutUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    _startPaymentWatch();
  }

  /// Poll while the member is off paying so the plan flips to active the
  /// moment PayMongo confirms — GET /payments/{id} also reconciles
  /// server-side, so each poll is itself a grant opportunity.
  void _startPaymentWatch() {
    _pollTimer ??= Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkPayment(),
    );
    if (mounted) setState(() {}); // reflect the waiting indicator
  }

  Future<void> _checkPayment() async {
    final id = _paymentId;
    if (id == null || _paid || _checkingPayment) return;
    _checkingPayment = true;
    try {
      final payment = await ApiService.getPayment(id);
      if (payment.isPaid && mounted) {
        _pollTimer?.cancel();
        _pollTimer = null;
        setState(() => _paid = true);
      }
    } catch (_) {
      // Transient network/API error — the next poll tick retries, and the
      // backend's profile-load reconcile covers us even if polling dies.
    } finally {
      _checkingPayment = false;
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final Widget stepBody = switch (_step) {
      _stepDetails => _PetDetailsStep(
          formKey: _formKey,
          keys: _DetailKeys(
            name: _nameKey,
            species: _speciesKey,
            sex: _sexKey,
            breed: _breedKey,
            birth: _birthKey,
            weight: _weightKey,
          ),
          fields: _DetailFields(
            name: _nameCtrl,
            breed: _breedCtrl,
            weight: _weightCtrl,
            notes: _notesCtrl,
            nameFocus: _nameFocus,
            breedFocus: _breedFocus,
            weightFocus: _weightFocus,
          ),
          species: _species,
          onSpeciesChanged: (v) => setState(() => _species = v),
          sex: _sex,
          onSexChanged: (v) => setState(() => _sex = v),
          birthMonth: _birthMonth,
          birthYear: _birthYear,
          birthDay: _birthDay,
          onBirthPicked: (picked) => setState(() {
            _birthMonth = picked.month;
            _birthDay = picked.day;
            _birthYear = picked.year;
          }),
          birthError: _birthChecked ? _birthError : null,
          birthSummary: _birthSummary(),
        ),
      _stepPhotos => _PhotosStep(
          petName: _petName,
          shots: _shots,
          showMissing: _shotsChecked,
          onPick: _pickInto,
          onRemove: _removeShot,
          onHelp: _showPhotoHelp,
        ),
      _stepPlan => _PlanStep(
          plans: _plans,
          quotes: _quotes,
          plansLoading: _plansLoading,
          selectedPlanId: _selectedPlanId,
          onPlanSelected: (id) => setState(() => _selectedPlanId = id),
          cadence: _cadence,
          onCadenceChanged: (v) => setState(() => _cadence = v),
          agreementAccepted: _agreementAccepted,
          onAgreementChanged: (v) => setState(() => _agreementAccepted = v),
          error: _error,
        ),
      _ => _DoneStep(
          petName: _petName,
          // The face photo is already in memory from step 2 — showing the pet
          // they just registered costs nothing and is the whole point of
          // "Pet as Hero" at the one moment that earns it.
          facePhoto: _shots[_Shot.face]?.bytes,
          plan: _selectedPlan,
          quote: _selectedPlan == null ? null : _quotes[_selectedPlan!.id],
          cadence: _cadence,
          checkoutUrl: _checkoutUrl,
          paid: _paid,
          waiting: _pollTimer != null,
        ),
    };

    return PopScope(
      // The system back gesture is the most-used control on Android and it was
      // the only one that skipped the step machine.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          // titleMedium's ink is the body color — dark on the now-navy bar.
          // The last step is two different states: "All done!" over a screen
          // that says "One step left" was the bar contradicting the body.
          title: Text(
            _step < _stepDone
                ? 'Add a pet'
                : (_checkoutUrl != null && !_paid)
                    ? 'Almost there'
                    : 'All done!',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
          leading: _step == _stepDone
              ? const SizedBox.shrink()
              : BackButton(onPressed: _handleBack),
          automaticallyImplyLeading: false,
        ),
        // `bottom: false` because the pinned footer owns the gesture-bar inset.
        // Claiming it here as well leaves a dead cream band above the footer on
        // every gesture-navigation phone.
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (_step < _stepDone) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
                  child: _StepBar(
                    step: _step,
                    onStepTapped: (i) {
                      if (i >= _step) return;
                      setState(() {
                        _step = i;
                        _error = null;
                      });
                      _resetScroll();
                    },
                  ),
                ),
                // Header band and scrolling content are both cream, so without
                // this the body clipped against nothing: a half-line of text
                // sitting under the step labels read as a rendering fault
                // rather than as content scrolled out of view. Pairs with the
                // footer's top hairline.
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ],
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  child: stepBody,
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildFooter(context),
      ),
    );
  }

  /// The primary action lives in a pinned bar rather than at the foot of the
  /// scroll. On the details step the old button sat below ten fields and three
  /// photo tiles — roughly two screens down — so the way forward was invisible
  /// for the entire time the member was filling the form in.
  Widget _buildFooter(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final Widget primary;
    Widget? secondary;
    Widget? summary;

    switch (_step) {
      case _stepDetails:
      case _stepPhotos:
        primary = MpButton(label: 'Continue →', onPressed: _nextStep);
      case _stepPlan:
        final selected = _selectedPlan;
        if (selected != null) {
          summary = _FooterSummary(
            plan: selected,
            quote: _quotes[selected.id],
            cadence: _cadence,
          );
        }
        primary = MpButton(
          label: 'Activate plan →',
          loading: _isLoading,
          onPressed: (_selectedPlanId == null || !_agreementAccepted)
              ? null
              : _activate,
        );
      default:
        final pending = _checkoutUrl != null && !_paid;
        // Naming the amount on the button is standard at a checkout hand-off:
        // the member should never tap "pay" to find out the figure on the
        // next screen, which is a different app.
        primary = pending
            ? MpButton(label: _payLabel(), onPressed: _openCheckout)
            : MpButton(
                label: 'Back to dashboard →',
                onPressed: () => Navigator.pop(context, true),
              );
        if (pending) {
          secondary = TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Back to dashboard',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          );
        }
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline)),
      ),
      // maintainBottomViewPadding keeps the gesture-bar inset reserved while
      // the keyboard animates, so the bar doesn't change height mid-slide.
      // Under Android's edge-to-edge enforcement this padding is the only thing
      // between the button and the system navigation handle.
      child: SafeArea(
        top: false,
        maintainBottomViewPadding: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (summary != null) ...[summary, const SizedBox(height: 12)],
              primary,
              ?secondary,
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Step bar ─────────────────────────────────────────────────────────────────

class _StepBar extends StatelessWidget {
  final int step;
  final ValueChanged<int> onStepTapped;

  const _StepBar({required this.step, required this.onStepTapped});

  static const _labels = ['Details', 'Photos', 'Plan'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // One announcement for the whole bar. Read as separate nodes it came out as
    // a string of bare numerals, which tells a screen-reader user nothing.
    return Semantics(
      container: true,
      label: 'Step ${step + 1} of ${_labels.length}: ${_labels[step]}',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(_labels.length * 2 - 1, (i) {
            if (i.isOdd) {
              final done = (i ~/ 2) < step;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 2,
                    color: done ? AppColors.navy : cs.outline,
                  ),
                ),
              );
            }
            final idx = i ~/ 2;
            final isActive = idx == step;
            final isDone = idx < step;
            return InkWell(
              // A finished step is somewhere the member can go back to; one
              // they haven't reached is not, so only the former takes a tap.
              onTap: isDone ? () => onStepTapped(idx) : null,
              borderRadius: BorderRadius.circular(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isActive || isDone)
                          ? AppColors.navy
                          : Colors.transparent,
                      border: Border.all(
                        color: (isActive || isDone) ? AppColors.navy : cs.outline,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(Icons.check, color: Colors.white, size: 14)
                          : Text(
                              '${idx + 1}',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isActive ? Colors.white : cs.onSurfaceVariant,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Bound the label width so a long step name wraps to two
                  // lines instead of widening the step column and overflowing
                  // the row between the Expanded connectors on a narrow screen.
                  SizedBox(
                    width: 72,
                    child: Text(
                      _labels[idx],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        color: (isActive || isDone)
                            ? AppColors.navy
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─── Step 0: Pet details ──────────────────────────────────────────────────────

/// Scroll anchors, grouped so the step takes one parameter for them rather than
/// six positional look-alikes that are trivial to transpose at the call site.
class _DetailKeys {
  const _DetailKeys({
    required this.name,
    required this.species,
    required this.sex,
    required this.breed,
    required this.birth,
    required this.weight,
  });

  final GlobalKey name;
  final GlobalKey species;
  final GlobalKey sex;
  final GlobalKey breed;
  final GlobalKey birth;
  final GlobalKey weight;
}

/// Controllers and focus nodes for the step's text inputs. Same reasoning as
/// [_DetailKeys]: seven same-typed parameters in a row invite a silent swap.
class _DetailFields {
  const _DetailFields({
    required this.name,
    required this.breed,
    required this.weight,
    required this.notes,
    required this.nameFocus,
    required this.breedFocus,
    required this.weightFocus,
  });

  final TextEditingController name;
  final TextEditingController breed;
  final TextEditingController weight;
  final TextEditingController notes;
  final FocusNode nameFocus;
  final FocusNode breedFocus;
  final FocusNode weightFocus;
}

class _PetDetailsStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final _DetailKeys keys;
  final _DetailFields fields;
  final String? species;
  final ValueChanged<String> onSpeciesChanged;
  final String? sex;
  final ValueChanged<String> onSexChanged;
  final int? birthMonth;
  final int? birthYear;
  final int? birthDay;
  final ValueChanged<_BirthDate> onBirthPicked;

  /// The group's message, already gated — non-null means show it.
  final String? birthError;

  /// "11 March 2023 · about 3 years and 5 months old", once the group is set.
  final String? birthSummary;

  const _PetDetailsStep({
    required this.formKey,
    required this.keys,
    required this.fields,
    required this.species,
    required this.onSpeciesChanged,
    required this.sex,
    required this.onSexChanged,
    required this.birthMonth,
    required this.birthYear,
    required this.birthDay,
    required this.onBirthPicked,
    required this.birthError,
    required this.birthSummary,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Form(
      key: formKey,
      // Validation timing lives on each field, never here. A Form-level
      // `onUserInteraction` marks the ENTIRE form as interacted with the first
      // time any one field changes, so choosing a pet type turned the name,
      // breed and birth fields red at once — before the member had reached
      // them. Per-field, each one speaks only for itself.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Your pet's pawprint", style: tt.displaySmall),
          const SizedBox(height: 6),
          Text(
            'Tell us about your furry family member. Everything here is needed '
            'unless it says optional.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),

          KeyedSubtree(
            key: keys.name,
            child: MpTextField(
              controller: fields.name,
              focusNode: fields.nameFocus,
              label: 'Pet name',
              hint: 'What do you call them?',
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              onFieldSubmitted: (_) => fields.breedFocus.requestFocus(),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Please enter a name' : null,
            ),
          ),
          const SizedBox(height: 20),

          // Two options each, so both are shown rather than hidden behind a
          // menu: one tap instead of two, and no chance of a member closing the
          // sheet without realising nothing was chosen.
          KeyedSubtree(
            key: keys.species,
            child: _ChoiceField(
              label: 'Pet type',
              value: species,
              emptyError: 'Please choose a pet type',
              choices: const [_Choice('Dog'), _Choice('Cat')],
              onChanged: onSpeciesChanged,
            ),
          ),
          const SizedBox(height: 20),

          KeyedSubtree(
            key: keys.sex,
            child: _ChoiceField(
              label: 'Sex',
              value: sex,
              emptyError: 'Please choose a sex',
              choices: const [
                _Choice('Male', Icons.male_rounded),
                _Choice('Female', Icons.female_rounded),
              ],
              onChanged: onSexChanged,
            ),
          ),
          const SizedBox(height: 20),

          KeyedSubtree(
            key: keys.breed,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MpTextField(
                  controller: fields.breed,
                  focusNode: fields.breedFocus,
                  label: 'Breed',
                  hint: species == null
                      ? 'Pick a pet type first for suggestions'
                      : 'Type it, or tap one below',
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  onFieldSubmitted: (_) => fields.weightFocus.requestFocus(),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Please enter a breed'
                      : null,
                ),
                if (species != null) ...[
                  const SizedBox(height: 10),
                  _BreedShortcuts(
                    breeds: species == 'Cat' ? _kCatBreeds : _kDogBreeds,
                    onPicked: (b) {
                      fields.breed.text = b;
                      fields.weightFocus.requestFocus();
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),

          const _SectionHeading('Age and size'),
          const SizedBox(height: 16),

          KeyedSubtree(
            key: keys.birth,
            child: _BirthDateField(
              month: birthMonth,
              year: birthYear,
              day: birthDay,
              onPicked: onBirthPicked,
              errorText: birthError,
              summary: birthSummary,
            ),
          ),
          const SizedBox(height: 20),

          KeyedSubtree(
            key: keys.weight,
            child: MpTextField(
              controller: fields.weight,
              focusNode: fields.weightFocus,
              label: 'Weight',
              // The unit belongs in the field, not bolted onto the label.
              suffixText: 'kg',
              helperText: 'A close estimate is fine.',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Please enter a weight';
                final val = double.tryParse(v.trim());
                if (val == null) return 'Enter numbers only, like 12.5';
                if (val <= 0 || val > 200) return 'Enter a weight between 0 and 200 kg';
                return null;
              },
            ),
          ),
          const SizedBox(height: 20),

          MpTextField(
            controller: fields.notes,
            label: 'Notes (optional)',
            hint: 'Allergies, medication, anything a vet should know…',
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}

/// A named option in a [_ChoiceField].
class _Choice {
  const _Choice(this.label, [this.icon]);
  final String label;
  final IconData? icon;
}

/// A short set of mutually exclusive options laid out in full, wired into the
/// surrounding [Form] so a missing answer reports itself under the control
/// instead of in a snackbar at the foot of the screen.
class _ChoiceField extends StatelessWidget {
  final String label;
  final String? value;
  final List<_Choice> choices;
  final ValueChanged<String> onChanged;
  final String emptyError;

  const _ChoiceField({
    required this.label,
    required this.value,
    required this.choices,
    required this.onChanged,
    required this.emptyError,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return FormField<String>(
      initialValue: value,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (v) => v == null ? emptyError : null,
      builder: (state) {
        Widget segment(_Choice choice) {
          final selected = value == choice.label;
          return Expanded(
            child: Semantics(
              button: true,
              selected: selected,
              label: '$label: ${choice.label}',
              child: ExcludeSemantics(
                child: ScaleButton(
                  onTap: () {
                    // didChange marks the field as interacted with, which is
                    // what lets the Form's onUserInteraction mode clear the
                    // error the moment a choice is made.
                    state.didChange(choice.label);
                    onChanged(choice.label);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    constraints: const BoxConstraints(minHeight: 52),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? cs.primary : cs.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? cs.primary
                            : (state.hasError ? cs.error : cs.outline),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (choice.icon != null) ...[
                          Icon(
                            choice.icon,
                            size: 18,
                            color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          choice.label,
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: selected ? cs.onPrimary : cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: tt.labelLarge?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < choices.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  segment(choices[i]),
                ],
              ],
            ),
            if (state.hasError) ...[
              const SizedBox(height: 8),
              Padding(
                // Matches the 16dp content inset Material gives a text field's
                // own error line, so every error in the form shares one edge.
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  state.errorText!,
                  style: tt.bodySmall?.copyWith(color: cs.error),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Tap-to-fill breeds under the breed field. A single scrolling row rather than
/// a wrapped block: nine chips wrapped would push the rest of the form most of
/// a screen further down for what is only a typing shortcut.
class _BreedShortcuts extends StatelessWidget {
  final List<String> breeds;
  final ValueChanged<String> onPicked;

  const _BreedShortcuts({required this.breeds, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: breeds.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Semantics(
          button: true,
          label: 'Use breed ${breeds[i]}',
          child: ExcludeSemantics(
            child: ScaleButton(
              onTap: () => onPicked(breeds[i]),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: cs.outline),
                ),
                child: Text(
                  breeds[i],
                  style: tt.labelLarge?.copyWith(color: cs.onSurface),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A date the wheel produced. The day is nullable because pets are adopted
/// and rescued, and an owner who does not know the exact day must be able to
/// say so — `birth_day` is nullable on the backend for the same reason.
class _BirthDate {
  const _BirthDate({required this.month, required this.day, required this.year});

  final int month;
  final int? day;
  final int year;
}

/// Date of birth: one field, one sheet, one wheel.
///
/// This replaced a grid picker per part, which meant three separate modal trips
/// to state one date and no way to see month, day and year together. A wheel
/// puts all three columns in front of the member at once and lets any of them
/// be nudged without reopening anything.
///
/// The usual objection to wheel pickers — that a birth year is an endless spin
/// — is about HUMAN dates, where the range runs to 118 years. A pet's runs to
/// 37 and clusters in the last fifteen, so the year column is short in practice
/// and starts on the current year.
class _BirthDateField extends StatelessWidget {
  const _BirthDateField({
    required this.month,
    required this.year,
    required this.day,
    required this.onPicked,
    required this.errorText,
    required this.summary,
  });

  final int? month;
  final int? year;
  final int? day;
  final ValueChanged<_BirthDate> onPicked;
  final String? errorText;
  final String? summary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasError = errorText != null;
    final isSet = month != null && year != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date of birth',
          style: tt.labelLarge?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Month and year are enough — add the day if you know it.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        _PickerField(
          // No labelText: the group heading two lines up already says "Date of
          // birth", and an InputDecorator label would print it a second time.
          label: 'Date of birth',
          showLabel: false,
          value: isSet
              ? (day == null
                  ? '${_kMonths[month! - 1]} $year'
                  : '$day ${_kMonths[month! - 1]} $year')
              : null,
          placeholder: 'Choose a date',
          hasError: hasError,
          onTap: () async {
            final picked = await _BirthWheelSheet.show(
              context: context,
              month: month,
              day: day,
              year: year,
            );
            if (picked != null) onPicked(picked);
          },
        ),
        if (hasError) ...[
          const SizedBox(height: 8),
          _BirthNote(
            icon: Icons.error_outline_rounded,
            text: errorText!,
            color: cs.error,
          ),
        ] else if (summary != null) ...[
          const SizedBox(height: 8),
          // The age is the only thing that catches a mis-spun year: 2013 is as
          // valid a year as 2023, and nothing else gives it away.
          _BirthNote(
            icon: Icons.cake_outlined,
            text: summary!,
            color: cs.onSurfaceVariant,
          ),
        ],
      ],
    );
  }
}

/// A read-only field that opens a picker. Built on [InputDecorator] so it
/// inherits the app's `InputDecorationTheme` exactly — it sits among real text
/// fields and must not read as a different species of control.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.hasError,
    required this.onTap,
    this.placeholder,
    this.showLabel = true,
  });

  /// Always used for the semantics announcement; printed in the field only
  /// when [showLabel], since a labelled group would otherwise say it twice.
  final String label;
  final bool showLabel;
  final String? value;
  final String? placeholder;
  final bool hasError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isEmpty = value == null;

    return Semantics(
      button: true,
      label: '$label: ${value ?? 'not set'}',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            isEmpty: isEmpty && placeholder == null,
            decoration: InputDecoration(
              labelText: showLabel ? label : null,
              errorText: hasError ? '' : null,
              // Collapsed: the group prints one message below the field.
              errorStyle: const TextStyle(height: 0, fontSize: 0),
              suffixIcon: Icon(
                Icons.expand_more_rounded,
                size: 22,
                color: cs.onSurfaceVariant,
              ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 34,
                minHeight: 24,
              ),
            ),
            child: Text(
              value ?? placeholder ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.titleMedium?.copyWith(
                color: isEmpty ? cs.onSurfaceVariant : cs.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The three-column wheel. Month · Day · Year, in Philippine reading order.
class _BirthWheelSheet extends StatefulWidget {
  const _BirthWheelSheet({
    required this.month,
    required this.day,
    required this.year,
  });

  final int? month;
  final int? day;
  final int? year;

  static const earliestYear = 1990;
  static const _itemExtent = 44.0;

  static Future<_BirthDate?> show({
    required BuildContext context,
    required int? month,
    required int? day,
    required int? year,
  }) {
    return showModalBottomSheet<_BirthDate>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BirthWheelSheet(month: month, day: day, year: year),
    );
  }

  @override
  State<_BirthWheelSheet> createState() => _BirthWheelSheetState();
}

class _BirthWheelSheetState extends State<_BirthWheelSheet> {
  late int _month;
  late int _year;

  /// Null means "Not sure", which is the first stop on the day wheel rather
  /// than a checkbox beside it — one control, and it reads in the wheel's own
  /// idiom instead of bolting a second widget onto the sheet.
  int? _day;

  late final FixedExtentScrollController _monthCtl;
  late final FixedExtentScrollController _dayCtl;
  late final FixedExtentScrollController _yearCtl;

  late final List<int> _years;

  @override
  void initState() {
    super.initState();
    final thisYear = DateTime.now().year;
    _years = [
      for (var y = thisYear; y >= _BirthWheelSheet.earliestYear; y--) y,
    ];
    // Opening on nothing lands on this year and January, which is the nearest
    // plausible guess for a puppy and the shortest spin for anything older.
    // Opening on January left the whole top half of the sheet blank, because
    // every column started at its first item. The month is cyclic, so it loops
    // and opens on the current one; the day and year keep their boundaries,
    // where the empty space is meaningful — nothing precedes "Not sure", and
    // nothing is newer than this year.
    _month = widget.month ?? DateTime.now().month;
    _year = widget.year ?? thisYear;
    _day = widget.day;

    _monthCtl = FixedExtentScrollController(initialItem: _month - 1);
    _yearCtl = FixedExtentScrollController(
      initialItem: _years.indexOf(_year).clamp(0, _years.length - 1),
    );
    _dayCtl = FixedExtentScrollController(initialItem: _day ?? 0);
  }

  @override
  void dispose() {
    _monthCtl.dispose();
    _dayCtl.dispose();
    _yearCtl.dispose();
    super.dispose();
  }

  int get _lastDay => _AddPetScreenState._daysInMonth(_year, _month);

  /// A day the new month can't hold is pulled back to that month's last day —
  /// spinning to 31 and then to February must not leave 31 February behind.
  void _reconcileDay() {
    if (_day != null && _day! > _lastDay) {
      _day = _lastDay;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _dayCtl.jumpToItem(_lastDay);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Date of birth', style: tt.titleLarge),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: _BirthWheelSheet._itemExtent * 5,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // The selection band sits UNDER the wheels so the centred
                  // row reads as sitting in it rather than behind a scrim.
                  IgnorePointer(
                    child: Container(
                      height: _BirthWheelSheet._itemExtent,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: _Wheel(
                          controller: _monthCtl,
                          count: 12,
                          loop: true,
                          labelAt: (i) => _kMonths[i],
                          onChanged: (i) => setState(() {
                            _month = i + 1;
                            _reconcileDay();
                          }),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: _Wheel(
                          controller: _dayCtl,
                          // Index 0 is "Not sure"; 1..lastDay are real days.
                          count: _lastDay + 1,
                          labelAt: (i) => i == 0 ? 'Not sure' : '$i',
                          onChanged: (i) =>
                              setState(() => _day = i == 0 ? null : i),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: _Wheel(
                          controller: _yearCtl,
                          count: _years.length,
                          labelAt: (i) => '${_years[i]}',
                          onChanged: (i) => setState(() {
                            _year = _years[i];
                            _reconcileDay();
                          }),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: MpButton(
                label: 'Confirm',
                onPressed: () => Navigator.pop(
                  context,
                  _BirthDate(month: _month, day: _day, year: _year),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.controller,
    required this.count,
    required this.labelAt,
    required this.onChanged,
    this.loop = false,
  });

  final FixedExtentScrollController controller;
  final int count;
  final String Function(int index) labelAt;
  final ValueChanged<int> onChanged;

  /// Wraps past the ends. Only for a genuinely cyclic column — a looping YEAR
  /// would put 1990 directly after this year, which is nonsense.
  final bool loop;

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: _BirthWheelSheet._itemExtent,
      physics: const FixedExtentScrollPhysics(),
      diameterRatio: 1.8,
      perspective: 0.003,
      // Rows away from the centre fade rather than shrink out of legibility,
      // which is what makes the selected value read as the answer.
      overAndUnderCenterOpacity: 0.4,
      // A looping wheel reports raw indices that run negative and past the end,
      // so they are folded back before anyone reads them as a month.
      onSelectedItemChanged: (i) => onChanged(loop ? ((i % count) + count) % count : i),
      childDelegate: loop
          ? ListWheelChildLoopingListDelegate(
              children: [
                for (var i = 0; i < count; i++) _cell(context, labelAt(i)),
              ],
            )
          : ListWheelChildBuilderDelegate(
              childCount: count,
              builder: (context, index) => _cell(context, labelAt(index)),
            ),
    );
  }

  Widget _cell(BuildContext context, String label) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: tt.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
      ),
    );
  }
}

class _BirthNote extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _BirthNote({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ─── Step 1: Photos ───────────────────────────────────────────────────────────

class _PhotosStep extends StatelessWidget {
  final String petName;
  final Map<_Shot, _Picked> shots;
  final bool showMissing;
  final void Function(_Shot) onPick;
  final void Function(_Shot) onRemove;
  final VoidCallback onHelp;

  const _PhotosStep({
    required this.petName,
    required this.shots,
    required this.showMissing,
    required this.onPick,
    required this.onRemove,
    required this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final who = petName.isEmpty ? 'your pet' : petName;
    final added = _AddPetScreenState._requiredShots
        .where((s) => shots[s] != null)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          petName.isEmpty ? 'Photos' : 'Photos of $petName',
          style: tt.displaySmall,
        ),
        const SizedBox(height: 6),
        Text(
          'Three photos confirm $who is really yours. They travel with every '
          'claim, so a clear set now saves questions later.',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        // The detail of what makes a good shot lives behind this rather than in
        // four paragraphs above the first tile.
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onHelp,
            icon: const Icon(Icons.help_outline_rounded, size: 18),
            label: const Text('What makes a good photo'),
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Text(
              '$added of 3 added',
              style: tt.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: added == 3 ? AppColors.successDark : cs.onSurface,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: added / 3,
                  minHeight: 6,
                  backgroundColor: cs.outline,
                  // Progress is structure, not money — ink, never gold.
                  color: cs.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        _ShotRow(
          title: 'Front face',
          guidance: 'Head-on, with the whole face in frame.',
          picked: shots[_Shot.face],
          showError: showMissing && shots[_Shot.face] == null,
          onTap: () => onPick(_Shot.face),
          onRemove: () => onRemove(_Shot.face),
        ),
        const SizedBox(height: 12),
        _ShotRow(
          title: 'Full body',
          guidance: 'Side on and standing, nose to tail.',
          picked: shots[_Shot.fullBody],
          showError: showMissing && shots[_Shot.fullBody] == null,
          onTap: () => onPick(_Shot.fullBody),
          onRemove: () => onRemove(_Shot.fullBody),
        ),
        const SizedBox(height: 12),
        _ShotRow(
          title: 'With you',
          guidance: 'The two of you together, both faces visible.',
          picked: shots[_Shot.withOwner],
          showError: showMissing && shots[_Shot.withOwner] == null,
          onTap: () => onPick(_Shot.withOwner),
          onRemove: () => onRemove(_Shot.withOwner),
        ),

        if (showMissing && added < 3) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, size: 16, color: cs.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  added == 2
                      ? 'One photo still to add.'
                      : 'Add the ${3 - added} photos marked above to continue.',
                  style: tt.bodyMedium?.copyWith(
                    color: cs.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 32),
        const _SectionHeading('Vaccination card'),
        const SizedBox(height: 10),
        Text(
          "Optional. Adding it now starts $who's digital health record — you "
          'can also add it later from their profile.',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        _ShotRow(
          title: 'Vaccination card',
          guidance: 'A flat, readable shot — corner to corner.',
          picked: shots[_Shot.vaxCard],
          optional: true,
          showError: false,
          onTap: () => onPick(_Shot.vaxCard),
          onRemove: () => onRemove(_Shot.vaxCard),
        ),
        const SizedBox(height: 12),
        Text(
          'JPG or PNG, up to ${ApiService.maxUploadMb} MB.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// One photo slot as a full-width row: thumbnail, what the shot is, and what a
/// good one looks like. Three cramped squares side by side had no room to say
/// any of that, and on a 320dp screen each was under 90dp wide.
class _ShotRow extends StatelessWidget {
  final String title;
  final String guidance;
  final _Picked? picked;
  final bool optional;
  final bool showError;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _ShotRow({
    required this.title,
    required this.guidance,
    required this.picked,
    required this.showError,
    required this.onTap,
    required this.onRemove,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final filled = picked != null;

    final Color border = showError
        ? cs.error
        : filled
            ? AppColors.navy
            : cs.outline;

    return Semantics(
      button: true,
      label: filled
          ? '$title, added. Tap to replace.'
          : optional
              ? '$title, optional, not added.'
              : '$title, required, not added.',
      child: ExcludeSemantics(
        child: ScaleButton(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: border,
                width: (filled || showError) ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: filled
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(picked!.bytes, fit: BoxFit.cover),
                        )
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.add_a_photo_outlined,
                            size: 22,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // No "Optional" badge here, deliberately: it cost the
                      // title enough width to render "Vaccination…", and the
                      // section heading and the line above the row already say
                      // the slot is optional in full words.
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        guidance,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      if (filled) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Added · tap to replace',
                              style: tt.labelSmall?.copyWith(
                                color: AppColors.successDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                if (filled)
                  IconButton(
                    onPressed: onRemove,
                    tooltip: 'Remove $title',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: cs.onSurfaceVariant,
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.add_rounded,
                      size: 22,
                      color: cs.onSurfaceVariant,
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

/// Camera first: a member registering a pet is usually holding the pet.
class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
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
                color: cs.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _PhotoHelpSheet extends StatelessWidget {
  const _PhotoHelpSheet();

  @override
  Widget build(BuildContext context) {
    return MpHelpSheet(
      title: 'What makes a good photo',
      intro:
          'These three photos are how MetroPaws tells your pet apart from any '
          'other pet on a claim. They are kept with the membership and are not '
          'shared outside it.',
      children: const [
        MpHelpHeading('Front face'),
        MpHelpBullet('Take it head-on, with the whole face in frame.'),
        MpHelpBullet('Good light, no heavy shadow across the face.'),
        MpHelpBullet('No hats, costumes or filters.'),
        SizedBox(height: 18),
        MpHelpHeading('Full body'),
        MpHelpBullet('Side on and standing, from nose to tail.'),
        MpHelpBullet(
          'Include any markings a vet would use to identify them — a patch, a '
          'scar, an unusual tail.',
        ),
        SizedBox(height: 18),
        MpHelpHeading('With you'),
        MpHelpBullet('You and your pet in the same frame, both faces visible.'),
        MpHelpBullet(
          'This one is what links the pet to your membership, so it is worth '
          'taking properly.',
        ),
        SizedBox(height: 18),
        MpHelpHeading('If a photo is refused'),
        MpHelpBullet('Files over 8 MB are turned away — retake rather than crop.'),
        MpHelpBullet('Screenshots of other photos are hard to verify.'),
        SizedBox(height: 18),
        MpHelpHeading('Later on'),
        MpHelpBullet(
          'Five more angles can be added from the pet profile once registration '
          'is done. They are optional.',
        ),
      ],
    );
  }
}

// ─── Step 2: Plan selection ───────────────────────────────────────────────────

class _PlanStep extends StatelessWidget {
  final List<Plan> plans;
  final Map<String, PlanQuote> quotes;
  final bool plansLoading;
  final String? selectedPlanId;
  final void Function(String?) onPlanSelected;
  final String cadence;
  final ValueChanged<String> onCadenceChanged;
  final bool agreementAccepted;
  final ValueChanged<bool> onAgreementChanged;
  final String? error;

  const _PlanStep({
    required this.plans,
    required this.quotes,
    required this.plansLoading,
    required this.selectedPlanId,
    required this.onPlanSelected,
    required this.cadence,
    required this.onCadenceChanged,
    required this.agreementAccepted,
    required this.onAgreementChanged,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose a plan', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 6),
        Text(
          "Pick the membership tier that fits your pet's needs. You can upgrade "
          'at any time.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        if (error != null) ...[
          MpErrorBanner(message: error!),
          const SizedBox(height: 16),
        ],
        if (plansLoading)
          const Center(child: CircularProgressIndicator())
        else if (plans.isEmpty)
          Center(
            child: Text(
              'No plans available. Please try again later.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          )
        else ...[
          if (plans.any((p) => p.priceMonthly != null)) ...[
            CadenceToggle(cadence: cadence, onChanged: onCadenceChanged),
            const SizedBox(height: 16),
          ],
          ...plans.map((plan) => _PlanCard(
                plan: plan,
                quote: quotes[plan.id],
                isSelected: plan.id == selectedPlanId,
                onTap: () => onPlanSelected(plan.id),
                cadence: cadence,
              )),
        ],
        const SizedBox(height: 20),
        // Pre-payment agreement gate — must be re-confirmed before money moves.
        AgreementCheckbox(
          value: agreementAccepted,
          onChanged: onAgreementChanged,
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Plan plan;

  /// Server-computed Pack Discount quote; null = full price.
  final PlanQuote? quote;
  final bool isSelected;
  final VoidCallback onTap;
  final String cadence;

  const _PlanCard({
    required this.plan,
    required this.quote,
    required this.isSelected,
    required this.onTap,
    required this.cadence,
  });

  /// Monthly only applies where the plan actually offers it; anything else
  /// keeps showing its annual figure rather than a blank one.
  bool get isMonthly => cadence == 'monthly' && plan.priceMonthly != null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.goldLight : cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.gold : cs.outline,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          plan.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isSelected ? AppColors.gold : cs.onSurface,
                          ),
                        ),
                        if (plan.isFeatured) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'POPULAR',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    RichText(
                      text: TextSpan(
                        children: [
                          // Pack Discount: struck-through full price ahead of
                          // the server-quoted final. Never computed on-device.
                          if (!isMonthly && (quote?.hasDiscount ?? false))
                            TextSpan(
                              text: '${_peso(quote!.fullPhp)}  ',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          TextSpan(
                            text: isMonthly
                                ? '${_peso(plan.priceMonthly!)} /month'
                                : '${_peso(quote?.finalPhp ?? plan.price)} /year',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: isSelected ? AppColors.gold : cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (quote?.hasDiscount ?? false) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${quote!.discountPercent}% Pack Discount · save '
                        '${_peso(quote!.discountPhp)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          // goldDark is only contrast-safe on light surfaces;
                          // use gold on dark mode's dark card background.
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.gold
                              : AppColors.goldDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (plan.tagline != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        plan.tagline!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isSelected ? AppColors.grey : cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    ...plan.features.take(3).map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: isSelected
                                    ? AppColors.gold
                                    : cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  f,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isSelected
                                        ? AppColors.text
                                        : cs.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.gold : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? AppColors.gold : cs.outline,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What is about to be charged, sitting directly above the button that charges
/// it. The plan cards scroll; this doesn't.
class _FooterSummary extends StatelessWidget {
  final Plan plan;
  final PlanQuote? quote;
  final String cadence;

  const _FooterSummary({
    required this.plan,
    required this.quote,
    required this.cadence,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isMonthly = cadence == 'monthly' && plan.priceMonthly != null;
    final amount = isMonthly
        ? '${_peso(plan.priceMonthly!)} /month'
        : '${_peso(quote?.finalPhp ?? plan.price)} /year';

    return Row(
      children: [
        Expanded(
          child: Text(
            plan.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          amount,
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ─── Step 3: Done ─────────────────────────────────────────────────────────────

class _DoneStep extends StatelessWidget {
  final String petName;
  final Uint8List? facePhoto;
  final Plan? plan;
  final PlanQuote? quote;
  final String cadence;
  final String? checkoutUrl;
  final bool paid;
  final bool waiting;

  const _DoneStep({
    required this.petName,
    required this.facePhoto,
    required this.plan,
    required this.quote,
    required this.cadence,
    required this.checkoutUrl,
    required this.paid,
    required this.waiting,
  });

  bool get _isMonthly => cadence == 'monthly' && plan?.priceMonthly != null;

  @override
  Widget build(BuildContext context) {
    // Pending only until the payment watch confirms — then this flips to the
    // success treatment, which is also the no-checkout (payments off) path.
    final showPending = checkoutUrl != null && !paid;
    return showPending ? _pending(context) : _success(context);
  }

  // ── Before payment ──────────────────────────────────────────────────────

  /// The member is one tap from being sent to PayMongo, so this states what is
  /// about to be charged. It used to read "Complete your payment to activate
  /// the plan" and name no pet, no plan and no amount — asking someone to pay
  /// without telling them what for.
  Widget _pending(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final who = petName.isEmpty ? 'your pet' : petName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('One step left', style: tt.displaySmall),
        const SizedBox(height: 6),
        Text(
          '$who is registered. Pay to activate their plan.',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 24),

        _OrderSummary(
          petName: petName,
          facePhoto: facePhoto,
          plan: plan,
          quote: quote,
          isMonthly: _isMonthly,
        ),
        const SizedBox(height: 20),

        const _InfoRow(
          icon: Icons.open_in_new_rounded,
          text: 'Paying opens PayMongo outside the app. Come back here when '
              'you are done — you do not need to do anything else.',
        ),
        const SizedBox(height: 12),
        const _InfoRow(
          icon: Icons.lock_outline_rounded,
          text: 'MetroPaws never sees or stores your card or wallet details.',
        ),
        if (_isMonthly) ...[
          const SizedBox(height: 12),
          // Agreement §5.7 — a monthly member is not covered yet, and that has
          // to be said BEFORE the money moves, not after.
          const _InfoRow(
            icon: Icons.schedule_rounded,
            text: 'This is the first monthly payment. App access starts now, '
                'and benefits open up as your payments continue.',
          ),
        ],

        if (waiting) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Waiting for confirmation. This screen updates on its own.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── After payment ───────────────────────────────────────────────────────

  /// Registration success is one of the moments PRODUCT.md marks for joyful
  /// treatment, and it is the first time the member meets the pet they just
  /// built. The old version was a gold circle and one sentence promising
  /// "session credits" — a benefit the app no longer runs.
  Widget _success(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final who = petName.isEmpty ? 'Your pet' : petName;
    final planName = plan?.name;

    final String subtitle;
    if (planName == null) {
      subtitle = '$who is set up and ready.';
    } else if (_isMonthly) {
      subtitle = '$who is on the $planName plan.';
    } else {
      subtitle = 'The $planName plan is active for $who.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(child: _SuccessPortrait(facePhoto: facePhoto)),
        const SizedBox(height: 24),
        Text(
          '$who is a member!',
          style: tt.displaySmall,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),

        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'What is ready now',
            style: tt.labelLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _NextStep(
          icon: Icons.qr_code_2_rounded,
          title: 'Digital Pawprint',
          body: 'The ID card for $who is on your Home tab — show it at a '
              'partner clinic.',
        ),
        const SizedBox(height: 10),
        // Benefit Wallet, not "session credits": the wallet is what a plan
        // actually funds, and a monthly member reaches it by vesting.
        _NextStep(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Benefit Wallet',
          body: _isMonthly
              ? 'Opens up as your monthly payments continue. Track it on the '
                  'Benefits tab.'
              : 'Ready on the Benefits tab — pay a clinic, then claim it back.',
        ),
        const SizedBox(height: 10),
        _NextStep(
          icon: Icons.photo_camera_outlined,
          title: 'More photos',
          body: 'Five more angles can be added from the profile for $who '
              'whenever you like.',
        ),
      ],
    );
  }
}

/// The pet, ringed in success green. A photo of the animal just registered
/// says "this worked" faster than any icon can.
class _SuccessPortrait extends StatelessWidget {
  const _SuccessPortrait({required this.facePhoto});

  final Uint8List? facePhoto;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 132,
            height: 132,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.successLight,
              border: Border.all(color: AppColors.success, width: 3),
            ),
            child: facePhoto == null
                ? const Icon(
                    Icons.pets_rounded,
                    size: 56,
                    color: AppColors.successDark,
                  )
                : ClipOval(child: Image.memory(facePhoto!, fit: BoxFit.cover)),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 3,
              ),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 22,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// What is about to be charged, itemised. Gold is spent on the amount and on
/// nothing else here — it is the one figure on the card that is money.
class _OrderSummary extends StatelessWidget {
  const _OrderSummary({
    required this.petName,
    required this.facePhoto,
    required this.plan,
    required this.quote,
    required this.isMonthly,
  });

  final String petName;
  final Uint8List? facePhoto;
  final Plan? plan;
  final PlanQuote? quote;
  final bool isMonthly;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final int? amount = plan == null
        ? null
        : isMonthly
            ? plan!.priceMonthly!
            : (quote?.finalPhp ?? plan!.price);
    // The Pack Discount is annual-only — never itemise it against a monthly
    // instalment, which is not a year of anything.
    final discounted = !isMonthly && (quote?.hasDiscount ?? false);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: facePhoto == null
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.pets_rounded,
                          size: 22,
                          color: cs.onSurfaceVariant,
                        ),
                      )
                    : ClipOval(
                        child: Image.memory(facePhoto!, fit: BoxFit.cover),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      petName.isEmpty ? 'Your pet' : petName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      plan == null
                          ? 'Membership'
                          : '${plan!.name} · ${isMonthly ? 'Monthly' : 'Yearly'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (amount != null) ...[
            const SizedBox(height: 14),
            Divider(color: cs.outline, height: 1),
            const SizedBox(height: 14),
            if (discounted) ...[
              _SummaryLine(
                label: 'Plan',
                value: _peso(quote!.fullPhp),
                struck: true,
              ),
              const SizedBox(height: 6),
              _SummaryLine(
                label: '${quote!.discountPercent}% Pack Discount',
                value: '-${_peso(quote!.discountPhp)}',
                highlight: true,
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    isMonthly ? 'Due today' : 'Total',
                    style: tt.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                Text(
                  _peso(amount),
                  style: tt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.gold : AppColors.goldDark,
                  ),
                ),
              ],
            ),
            if (isMonthly) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'then ${_peso(amount)} each month',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.struck = false,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool struck;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = tt.bodySmall?.copyWith(
      color: highlight
          ? (isDark ? AppColors.gold : AppColors.goldDark)
          : cs.onSurfaceVariant,
      fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
      decoration: struck ? TextDecoration.lineThrough : null,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: cs.onSurfaceVariant),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _NextStep extends StatelessWidget {
  const _NextStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: AppColors.navy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _SectionHeading extends StatelessWidget {
  final String label;
  const _SectionHeading(this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Divider(color: cs.outline, height: 1),
      ],
    );
  }
}
