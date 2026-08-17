import 'dart:async';
import 'dart:typed_data';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/plan.dart';
import '../../../core/models/plan_quote.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/cadence_toggle.dart';
import '../../../core/widgets/agreement_checkbox.dart';
import '../../../core/widgets/mp_button.dart';
import '../../../core/widgets/mp_dropdown_field.dart';
import '../../../core/widgets/mp_error_banner.dart';
import '../../../core/widgets/mp_text_field.dart';
import '../../../theme.dart';

const _kMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

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

class AddPetScreen extends StatefulWidget {
  const AddPetScreen({super.key});

  @override
  State<AddPetScreen> createState() => _AddPetScreenState();
}

class _AddPetScreenState extends State<AddPetScreen> {
  // 0 = Pet Details, 1 = Health Card, 2 = Plan, 3 = Done
  int _step = 0;
  bool _isLoading = false;
  String? _error;

  // Pet details
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _breedCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _species;
  String? _sex;
  int? _birthMonth;
  int? _birthYear;
  int? _birthDay;
  // Required identity photos (MP-FRM-PET-001 slots 1-3). The remaining 5
  // angles are optional and added later from the pet's profile screen.
  Uint8List? _photoBytes;
  String? _photoExt;
  Uint8List? _fullBodyBytes;
  String? _fullBodyExt;
  Uint8List? _ownerBytes;
  String? _ownerExt;

  // Health card
  Uint8List? _vaxBytes;
  String? _vaxExt;

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
    _nameCtrl.dispose();
    _breedCtrl.dispose();
    _weightCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _goBack() {
    if (_step > 0) {
      setState(() { _step--; _error = null; });
    } else {
      Navigator.pop(context, false);
    }
  }

  void _nextStep() {
    if (_step == 0) {
      if (!_formKey.currentState!.validate()) return;
      if (_species == null) {
        _snack('Please select a pet type');
        return;
      }
      if (_sex == null) {
        _snack('Please select a sex');
        return;
      }
      if (_birthMonth == null || _birthYear == null) {
        _snack('Please select birth month and year');
        return;
      }
      if (_photoBytes == null || _fullBodyBytes == null || _ownerBytes == null) {
        _snack('Please add all 3 required photos');
        return;
      }
    }
    setState(() { _step++; _error = null; });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// Rejects an oversized pick immediately, at the step where it was chosen,
  /// instead of letting the member reach the final step before finding out.
  bool _tooLargeToUse(Uint8List bytes) {
    if (bytes.length <= ApiService.maxUploadBytes) return false;
    _snack('That photo is over ${ApiService.maxUploadMb} MB. Please choose a smaller one.');
    return true;
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (_tooLargeToUse(bytes)) return;
    // picked.name (not .path) — on web, XFile.path is a blob: URL with no
    // real extension, which sends the wrong extension to the backend.
    if (mounted) setState(() { _photoBytes = bytes; _photoExt = picked.name.split('.').last.toLowerCase(); });
  }

  Future<void> _pickFullBody() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (_tooLargeToUse(bytes)) return;
    if (mounted) {
      setState(() { _fullBodyBytes = bytes; _fullBodyExt = picked.name.split('.').last.toLowerCase(); });
    }
  }

  Future<void> _pickOwnerPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (_tooLargeToUse(bytes)) return;
    if (mounted) {
      setState(() { _ownerBytes = bytes; _ownerExt = picked.name.split('.').last.toLowerCase(); });
    }
  }

  Future<void> _pickVax() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (_tooLargeToUse(bytes)) return;
    if (mounted) setState(() { _vaxBytes = bytes; _vaxExt = picked.name.split('.').last.toLowerCase(); });
  }

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
          name: _nameCtrl.text.trim(),
          species: _species,
          sex: _sex?.toLowerCase(),
          birthMonth: _birthMonth!,
          birthYear: _birthYear!,
          birthDay: _birthDay,
          breed: _breedCtrl.text.trim(),
          weightKg: double.tryParse(_weightCtrl.text.trim()) ?? 0,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          photoBytes: _photoBytes!,
          photoExt: _photoExt!,
          fullBodyBytes: _fullBodyBytes!,
          fullBodyExt: _fullBodyExt!,
          ownerBytes: _ownerBytes!,
          ownerExt: _ownerExt!,
          vaxBytes: _vaxBytes,
          vaxExt: _vaxExt,
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
            _step = 3;
          });
        }
      } else {
        await ApiService.activatePetPlan(petId, _selectedPlanId!);
        if (mounted) setState(() => _step = 3);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = _friendlyPlanError(e.message));
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      _activating = false;
      if (mounted) setState(() => _isLoading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // titleMedium's ink is the body color — dark on the now-navy bar.
        title: Text(
          _step == 3 ? 'All done!' : 'Add a Pet',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.white,
          ),
        ),
        leading: _step == 3
            ? const SizedBox.shrink()
            : BackButton(onPressed: _goBack),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_step < 3)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: _StepBar(step: _step),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: [
                  _PetDetailsStep(
                    formKey: _formKey,
                    nameCtrl: _nameCtrl,
                    breedCtrl: _breedCtrl,
                    weightCtrl: _weightCtrl,
                    notesCtrl: _notesCtrl,
                    species: _species,
                    onSpeciesChanged: (v) => setState(() => _species = v),
                    sex: _sex,
                    onSexChanged: (v) => setState(() => _sex = v),
                    birthMonth: _birthMonth,
                    onBirthMonthChanged: (v) => setState(() => _birthMonth = v),
                    birthYear: _birthYear,
                    onBirthYearChanged: (v) => setState(() => _birthYear = v),
                    birthDay: _birthDay,
                    onBirthDayChanged: (v) => setState(() => _birthDay = v),
                    photoBytes: _photoBytes,
                    onPickPhoto: _pickPhoto,
                    fullBodyBytes: _fullBodyBytes,
                    onPickFullBody: _pickFullBody,
                    ownerBytes: _ownerBytes,
                    onPickOwnerPhoto: _pickOwnerPhoto,
                    onNext: _nextStep,
                  ),
                  _HealthCardStep(
                    vaxBytes: _vaxBytes,
                    onPickVax: _pickVax,
                    onNext: _nextStep,
                    onSkip: () => setState(() { _vaxBytes = null; _vaxExt = null; _step++; }),
                  ),
                  _PlanStep(
                    plans: _plans,
                    quotes: _quotes,
                    plansLoading: _plansLoading,
                    selectedPlanId: _selectedPlanId,
                    onPlanSelected: (id) => setState(() => _selectedPlanId = id),
                    cadence: _cadence,
                    onCadenceChanged: (v) => setState(() => _cadence = v),
                    agreementAccepted: _agreementAccepted,
                    onAgreementChanged: (v) => setState(() => _agreementAccepted = v),
                    isLoading: _isLoading,
                    error: _error,
                    onActivate: _activate,
                    onBack: _goBack,
                  ),
                  _DoneStep(
                    petName: _nameCtrl.text.trim(),
                    checkoutUrl: _checkoutUrl,
                    paid: _paid,
                    waiting: _pollTimer != null,
                    onCompletePayment: _openCheckout,
                    onDone: () => Navigator.pop(context, true),
                  ),
                ][_step],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Step bar ─────────────────────────────────────────────────────────────────

class _StepBar extends StatelessWidget {
  final int step;
  const _StepBar({required this.step});

  static const _labels = ['Details', 'Health Card', 'Plan'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
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
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isActive || isDone) ? AppColors.navy : Colors.transparent,
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
            // Bound the label width so a long step name ("Health Card") wraps
            // to two lines instead of widening the step column and overflowing
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
                  color: (isActive || isDone) ? AppColors.navy : cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ─── Step 0: Pet Details ──────────────────────────────────────────────────────

class _PetDetailsStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController breedCtrl;
  final TextEditingController weightCtrl;
  final TextEditingController notesCtrl;
  final String? species;
  final void Function(String?) onSpeciesChanged;
  final String? sex;
  final void Function(String?) onSexChanged;
  final int? birthMonth;
  final void Function(int?) onBirthMonthChanged;
  final int? birthYear;
  final void Function(int?) onBirthYearChanged;
  final int? birthDay;
  final void Function(int?) onBirthDayChanged;
  final Uint8List? photoBytes;
  final VoidCallback onPickPhoto;
  final Uint8List? fullBodyBytes;
  final VoidCallback onPickFullBody;
  final Uint8List? ownerBytes;
  final VoidCallback onPickOwnerPhoto;
  final VoidCallback onNext;

  const _PetDetailsStep({
    required this.formKey,
    required this.nameCtrl,
    required this.breedCtrl,
    required this.weightCtrl,
    required this.notesCtrl,
    required this.species,
    required this.onSpeciesChanged,
    required this.sex,
    required this.onSexChanged,
    required this.birthMonth,
    required this.onBirthMonthChanged,
    required this.birthYear,
    required this.onBirthYearChanged,
    required this.birthDay,
    required this.onBirthDayChanged,
    required this.photoBytes,
    required this.onPickPhoto,
    required this.fullBodyBytes,
    required this.onPickFullBody,
    required this.ownerBytes,
    required this.onPickOwnerPhoto,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentYear = DateTime.now().year;

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Your pet's pawprint", style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 6),
          Text(
            "Tell us about your furry family member.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),

          // Required identity photos (MP-FRM-PET-001 slots 1-3). The other 5
          // angles are optional and can be added later from the pet's profile.
          Text(
            'Required photos',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'These help us verify your pet and prevent fraudulent claims. '
            'You can add more angles later.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PhotoTile(
                  label: 'Front face',
                  bytes: photoBytes,
                  onTap: onPickPhoto,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PhotoTile(
                  label: 'Full body',
                  bytes: fullBodyBytes,
                  onTap: onPickFullBody,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PhotoTile(
                  label: 'With owner',
                  bytes: ownerBytes,
                  onTap: onPickOwnerPhoto,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          MpTextField(
            controller: nameCtrl,
            label: 'Pet name *',
            textInputAction: TextInputAction.next,
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          MpDropdownField<String>(
            value: species,
            label: 'Pet type *',
            items: const [
              DropdownMenuItem(value: 'Dog', child: Text('Dog')),
              DropdownMenuItem(value: 'Cat', child: Text('Cat')),
            ],
            onChanged: onSpeciesChanged,
          ),
          const SizedBox(height: 16),
          MpDropdownField<String>(
            value: sex,
            label: 'Sex *',
            items: const [
              DropdownMenuItem(value: 'Male', child: Text('Male')),
              DropdownMenuItem(value: 'Female', child: Text('Female')),
            ],
            onChanged: onSexChanged,
          ),
          const SizedBox(height: 16),
          MpTextField(
            controller: breedCtrl,
            label: 'Breed *',
            textInputAction: TextInputAction.next,
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 24),
          _SectionDivider(label: 'Age & vitals'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: MpDropdownField<int>(
                  value: birthMonth,
                  label: 'Birth month *',
                  items: List.generate(
                    12,
                    (i) => DropdownMenuItem(value: i + 1, child: Text(_kMonths[i])),
                  ),
                  onChanged: onBirthMonthChanged,
                  validator: (v) => v == null ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MpDropdownField<int>(
                  value: birthYear,
                  label: 'Birth year *',
                  items: List.generate(
                    currentYear - 1989,
                    (i) => DropdownMenuItem(value: currentYear - i, child: Text('${currentYear - i}')),
                  ),
                  onChanged: onBirthYearChanged,
                  validator: (v) => v == null ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          MpDropdownField<int?>(
            value: birthDay,
            label: 'Birth day (optional)',
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('—')),
              ...List.generate(31, (i) => DropdownMenuItem<int?>(value: i + 1, child: Text('${i + 1}'))),
            ],
            onChanged: onBirthDayChanged,
          ),
          const SizedBox(height: 16),
          MpTextField(
            controller: weightCtrl,
            label: 'Weight (kg) *',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              final val = double.tryParse(v.trim());
              if (val == null || val <= 0 || val > 200) return 'Enter a valid weight (0–200 kg)';
              return null;
            },
          ),
          const SizedBox(height: 16),
          MpTextField(
            controller: notesCtrl,
            label: 'Notes',
            hint: 'Allergies, special needs, anything useful...',
            maxLines: 3,
          ),
          const SizedBox(height: 32),
          MpButton(label: 'Continue →', onPressed: onNext),
        ],
      ),
    );
  }
}

/// One of the 3 required identity photos captured during registration
/// (MP-FRM-PET-001 slots 1-3). Square tile, camera badge, label below.
class _PhotoTile extends StatelessWidget {
  final String label;
  final Uint8List? bytes;
  final VoidCallback onTap;

  const _PhotoTile({
    required this.label,
    required this.bytes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: cs.surfaceContainerHighest,
                    border: Border.all(
                      color: bytes != null ? AppColors.gold : cs.outline,
                      width: bytes != null ? 2 : 1.5,
                    ),
                  ),
                  child: bytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(bytes!, fit: BoxFit.cover),
                        )
                      : Icon(Icons.add_a_photo_outlined, size: 28, color: cs.onSurfaceVariant),
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, size: 11, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ─── Step 1: Health Card ──────────────────────────────────────────────────────

class _HealthCardStep extends StatelessWidget {
  final Uint8List? vaxBytes;
  final VoidCallback onPickVax;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _HealthCardStep({
    required this.vaxBytes,
    required this.onPickVax,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vaccination card', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 6),
        Text(
          'Upload your pet\'s vaccination card to build their digital health record. You can always add this later.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: onPickVax,
          child: Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: vaxBytes != null ? AppColors.gold : cs.outline,
                width: vaxBytes != null ? 2 : 1,
              ),
            ),
            child: vaxBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.memory(vaxBytes!, fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upload_file_rounded, size: 48, color: cs.onSurfaceVariant),
                      const SizedBox(height: 10),
                      Text(
                        'Tap to upload',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'JPG, PNG or PDF — max 5 MB',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
          ),
        ),
        if (vaxBytes != null) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: onPickVax,
              icon: const Icon(Icons.swap_horiz, size: 16),
              label: const Text('Replace'),
            ),
          ),
        ],
        const SizedBox(height: 32),
        MpButton(
          label: vaxBytes != null ? 'Continue →' : 'Continue →',
          onPressed: vaxBytes != null ? onNext : onNext,
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: onSkip,
            child: Text(
              'Skip for now',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Step 2: Plan Selection ───────────────────────────────────────────────────

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
  final bool isLoading;
  final String? error;
  final VoidCallback onActivate;
  final VoidCallback onBack;

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
    required this.isLoading,
    required this.error,
    required this.onActivate,
    required this.onBack,
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
          'Pick the membership tier that fits your pet\'s needs. You can upgrade at any time.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
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
        const SizedBox(height: 20),
        MpButton(
          label: isLoading ? 'Activating…' : 'Activate Plan →',
          onPressed: (selectedPlanId == null || !agreementAccepted || isLoading)
              ? null
              : onActivate,
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: isLoading ? null : onBack,
            child: Text(
              '← Back',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
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

  static String _comma(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                              text: '₱${_comma(quote!.fullPhp)}  ',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          TextSpan(
                            text: isMonthly
                                ? '₱${_comma(plan.priceMonthly!)} /month'
                                : '₱${_comma(quote?.finalPhp ?? plan.price)} /year',
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
                        '${quote!.discountPercent}% Pack Discount · save ₱${_comma(quote!.discountPhp)}',
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
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: isSelected ? AppColors.grey : cs.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 8),
                    ...plan.features.take(3).map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_rounded, size: 14,
                              color: isSelected ? AppColors.gold : cs.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              f,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: isSelected ? AppColors.text : cs.onSurface),
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

// ─── Step 3: Done ─────────────────────────────────────────────────────────────

class _DoneStep extends StatelessWidget {
  final String petName;
  final String? checkoutUrl;
  final bool paid;
  final bool waiting;
  final VoidCallback onCompletePayment;
  final VoidCallback onDone;

  const _DoneStep({
    required this.petName,
    required this.checkoutUrl,
    required this.paid,
    required this.waiting,
    required this.onCompletePayment,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Pending only until the payment watch confirms — then this flips to the
    // same success treatment as the no-checkout (payments disabled) path.
    final showPending = checkoutUrl != null && !paid;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 24),
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: AppColors.goldLight,
            shape: BoxShape.circle,
          ),
          child: Icon(
            showPending ? Icons.payment_rounded : Icons.pets_rounded,
            color: AppColors.gold,
            size: 40,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          showPending ? 'One step left!' : '${petName.isNotEmpty ? petName : "Your pet"} is all set!',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(color: cs.primary),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        Text(
          showPending
              ? 'Complete your payment to activate the plan. Your plan activates automatically once payment is confirmed.'
              : 'The plan is active. ${petName.isNotEmpty ? petName : "Your pet"} now has a Digital Pawprint and session credits.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        if (showPending) ...[
          MpButton(
            label: 'Complete Payment →',
            onPressed: onCompletePayment,
          ),
          if (waiting) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Waiting for payment confirmation…',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: onDone,
              child: Text(
                'Back to Dashboard',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ),
        ] else
          MpButton(label: 'Back to Dashboard →', onPressed: onDone),
      ],
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _SectionDivider extends StatelessWidget {
  final String label;
  const _SectionDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
