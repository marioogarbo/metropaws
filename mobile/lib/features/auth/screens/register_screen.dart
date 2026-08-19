import 'dart:async';
import 'dart:math' show cos, sin;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/models/plan.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/mp_button.dart';
import '../../../core/widgets/mp_dropdown_field.dart';
import '../../../core/widgets/mp_error_banner.dart';
import '../../../core/widgets/mp_brand_photo_strip.dart';
import '../../../core/widgets/mp_paw_backdrop.dart';
import '../../../core/widgets/mp_text_field.dart';
import '../../../theme.dart';

// Version of the terms accepted at sign-up (Membership Agreement + Privacy
// Policy + Member Manual). Must match CURRENT_AGREEMENT_VERSION on the backend.
const _agreementVersion = '2026-07.2';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Email pre-step
  bool _emailVerified = false;
  bool _isEmailChecking = false;
  String? _emailError;
  final _emailPreCtrl = TextEditingController();
  final _emailPreKey = GlobalKey<FormState>();
  int _emailAttempts = 0;
  DateTime? _emailCooldownUntil;
  bool _isEmailTaken = false;

  // After email gate: show account form or success
  bool _registrationSuccess = false;
  bool _isPostRegLoading = false;
  String? _postRegError;

  // Account step
  final _step1Key = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _lastNameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscure = true;

  // Digital Agreement acceptance (required to register).
  bool _agreementAccepted = false;
  String? _agreementError;


  @override
  void dispose() {
    _emailPreCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _lastNameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _checkEmailAndProceed() async {
    if (!_emailPreKey.currentState!.validate()) return;

    // Client-side cooldown — _CooldownBanner in _EmailGate handles live display
    if (_emailCooldownUntil != null && DateTime.now().isBefore(_emailCooldownUntil!)) {
      setState(() {});
      return;
    }

    setState(() {
      _isEmailChecking = true;
      _emailError = null;
      _isEmailTaken = false;
    });
    try {
      final available = await ApiService.isEmailAvailable(_emailPreCtrl.text.trim());
      if (!mounted) return;
      _emailAttempts++;
      if (_emailAttempts >= 3) {
        _emailCooldownUntil = DateTime.now().add(const Duration(seconds: 30));
        _emailAttempts = 0;
      }
      if (!available) {
        setState(() => _isEmailTaken = true);
        return;
      }
      _emailCtrl.text = _emailPreCtrl.text.trim();
      setState(() => _emailVerified = true);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 429) {
        _emailCooldownUntil = DateTime.now().add(const Duration(seconds: 60));
        _emailAttempts = 0;
        setState(() {});
      } else {
        setState(() => _emailError = 'Could not verify email. Check your connection and try again.');
      }
    } catch (_) {
      if (mounted) setState(() => _emailError = 'Could not verify email. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _isEmailChecking = false);
    }
  }

  void _submitStep1() {
    final formValid = _step1Key.currentState!.validate();
    if (!_agreementAccepted) {
      setState(() => _agreementError =
          'Please accept the Membership Agreement and Privacy Policy to continue.');
    }
    if (!formValid || !_agreementAccepted) return;
    context.read<AuthBloc>().add(
      AuthRegisterRequested(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        phone: '+63${_phoneCtrl.text.trim()}',
        agreementAccepted: true,
        agreementVersion: _agreementVersion,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // Read here, above the Scaffold — see MpBrandPhotoStrip.keyboardIsUp.
    final compact = MpBrandPhotoStrip.keyboardIsUp(context);

    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            setState(() => _postRegError = state.message);
          } else if (state is AuthRegistrationComplete) {
            setState(() => _registrationSuccess = true);
          }
        },
        child: Column(
          children: [
            MpBrandPhotoStrip(
              imagePath: 'assets/images/pet-care-register.jpg',
              tagline: 'Two minutes to join.',
              height: MpBrandPhotoStrip.heightFor(context),
              compact: compact,
            ),
            Expanded(
              child: MpPawBackdrop(
                child: !_emailVerified
                    ? _EmailGate(
                        formKey: _emailPreKey,
                        emailCtrl: _emailPreCtrl,
                        isLoading: _isEmailChecking,
                        error: _emailError,
                        isTaken: _isEmailTaken,
                        cooldownUntil: _emailCooldownUntil,
                        onContinue: _checkEmailAndProceed,
                        onBack: () => Navigator.pop(context),
                      )
                    : _registrationSuccess
                    ? _SuccessState(
                        onDashboard: () {
                          Navigator.of(context).popUntil((r) => r.isFirst);
                          context.read<AuthBloc>().add(AuthCheckRequested());
                        },
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        child: _Step1(
                          formKey: _step1Key,
                          firstNameCtrl: _firstNameCtrl,
                          lastNameCtrl: _lastNameCtrl,
                          emailCtrl: _emailCtrl,
                          phoneCtrl: _phoneCtrl,
                          passwordCtrl: _passwordCtrl,
                          lastNameFocus: _lastNameFocus,
                          emailFocus: _emailFocus,
                          phoneFocus: _phoneFocus,
                          passwordFocus: _passwordFocus,
                          obscure: _obscure,
                          onToggleObscure: () =>
                              setState(() => _obscure = !_obscure),
                          error: _postRegError,
                          agreementAccepted: _agreementAccepted,
                          agreementError: _agreementError,
                          onAgreementChanged: (v) => setState(() {
                            _agreementAccepted = v;
                            if (v) _agreementError = null;
                          }),
                          onNext: _submitStep1,
                          onBack: () => setState(() => _emailVerified = false),
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

// ─── Step Indicator ───────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int totalSteps;
  final int currentStep;

  const _StepIndicator({required this.totalSteps, required this.currentStep});

  static const _labels = ['Account', 'Pet', 'Vaccination', 'Plan'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(totalSteps * 2 - 1, (i) {
        if (i.isOdd) {
          final isDone = (i ~/ 2) < currentStep;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 15),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 2,
                color: isDone ? AppColors.navy : cs.outline,
              ),
            ),
          );
        }
        final idx = i ~/ 2;
        final isActive = idx == currentStep;
        final isDone = idx < currentStep;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 32,
              height: 32,
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
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : Text(
                        '${idx + 1}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? Colors.white
                                  : cs.onSurfaceVariant,
                            ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              idx < _labels.length ? _labels[idx] : '${idx + 1}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: (isActive || isDone) ? AppColors.navy : cs.onSurfaceVariant,
                  ),
            ),
          ],
        );
      }),
    );
  }
}

// ─── Email Gate ───────────────────────────────────────────────────────────────

class _EmailGate extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final bool isLoading;
  final String? error;
  final bool isTaken;
  final DateTime? cooldownUntil;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const _EmailGate({
    required this.formKey,
    required this.emailCtrl,
    required this.isLoading,
    required this.error,
    this.isTaken = false,
    this.cooldownUntil,
    required this.onContinue,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MpCentredScroll(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: AutofillGroup(
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Join the club.',
                // Steps down a level on a narrow or text-scaled screen rather
                // than shrinking to fit — same call LoginScreen makes.
                style: (context.isTight
                        ? Theme.of(context).textTheme.displaySmall
                        : Theme.of(context).textTheme.displayMedium)
                    ?.copyWith(
                        fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),
              const SizedBox(height: 10),
              Text(
                "Start with your email address, and we'll check it's free.",
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 28),
              // Cooldown takes priority; then taken; then generic network error
              if (cooldownUntil != null) ...[
                _CooldownBanner(until: cooldownUntil!),
                const SizedBox(height: 16),
              ] else if (isTaken) ...[
                MpErrorBanner(message: 'This email is already registered.'),
                const SizedBox(height: 16),
              ] else if (error != null) ...[
                MpErrorBanner(message: error!),
                const SizedBox(height: 16),
              ],
              MpTextField(
                controller: emailCtrl,
                label: 'Email address',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.done,
                prefix: const MpFieldIcon(Icons.mail_outline_rounded),
                onFieldSubmitted: (_) => onContinue(),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter your email';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Semantics(
                label: 'Continue',
                child: MpButton(
                  label: 'Continue →',
                  onPressed: isLoading ? null : onContinue,
                  loading: isLoading,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: onBack,
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  child: RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                      children: [
                        const TextSpan(text: 'Already have an account? '),
                        TextSpan(
                          text: 'Sign in',
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
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
    );
  }
}

// ─── Cooldown Banner ──────────────────────────────────────────────────────────

class _CooldownBanner extends StatefulWidget {
  final DateTime until;
  const _CooldownBanner({required this.until});

  @override
  State<_CooldownBanner> createState() => _CooldownBannerState();
}

class _CooldownBannerState extends State<_CooldownBanner> {
  late final Timer _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final secs = widget.until.difference(DateTime.now()).inSeconds + 1;
    setState(() => _secondsLeft = secs.clamp(0, 999));
    if (_secondsLeft <= 0) _timer.cancel();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_secondsLeft <= 0) return const SizedBox.shrink();
    final s = _secondsLeft == 1 ? '' : 's';
    return MpErrorBanner(
      message: 'Too many attempts. Please wait $_secondsLeft second$s.',
    );
  }
}

// ─── Step 1: Account Details ──────────────────────────────────────────────────

class _Step1 extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController firstNameCtrl;
  final TextEditingController lastNameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController passwordCtrl;
  final FocusNode lastNameFocus;
  final FocusNode emailFocus;
  final FocusNode phoneFocus;
  final FocusNode passwordFocus;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final String? error;
  final bool agreementAccepted;
  final String? agreementError;
  final ValueChanged<bool> onAgreementChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _Step1({
    required this.formKey,
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.passwordCtrl,
    required this.lastNameFocus,
    required this.emailFocus,
    required this.phoneFocus,
    required this.passwordFocus,
    required this.obscure,
    required this.onToggleObscure,
    required this.error,
    required this.agreementAccepted,
    required this.agreementError,
    required this.onAgreementChanged,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AutofillGroup(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fur parent details',
              style: Theme.of(context).textTheme.displaySmall
                  ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
            ),
            const SizedBox(height: 10),
            Text(
              'A few details about you, then we can talk about your pet.',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            if (error != null) ...[
              MpErrorBanner(message: error!),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: MpTextField(
                    controller: firstNameCtrl,
                    label: 'First name',
                    autofillHints: const [AutofillHints.givenName],
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(lastNameFocus),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MpTextField(
                    controller: lastNameCtrl,
                    label: 'Last name',
                    focusNode: lastNameFocus,
                    autofillHints: const [AutofillHints.familyName],
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(emailFocus),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            MpTextField(
              controller: emailCtrl,
              label: 'Email address',
              focusNode: emailFocus,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              prefix: const MpFieldIcon(Icons.mail_outline_rounded),
              onFieldSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(phoneFocus),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter your email';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            MpTextField(
              controller: phoneCtrl,
              label: 'Mobile number *',
              focusNode: phoneFocus,
              prefixText: '+63 ',
              hint: '9171234567',
              keyboardType: TextInputType.number,
              inputFormatters: [_PhNumberFormatter()],
              maxLength: 10,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(passwordFocus),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Mobile number is required';
                if (v.trim().length != 10) {
                  return 'Enter a 10-digit PH number starting with 9';
                }
                if (!v.trim().startsWith('9')) {
                  return 'PH numbers start with 9 (e.g. 9171234567)';
                }
                return null;
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                'We handle the +63 — just type your 10-digit number',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 12),
            MpTextField(
              controller: passwordCtrl,
              focusNode: passwordFocus,
              label: 'Password',
              obscure: obscure,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              prefix: const MpFieldIcon(Icons.lock_outline_rounded),
              validator: (v) =>
                  v == null || v.length < 8 ? 'At least 8 characters' : null,
              suffix: IconButton(
                tooltip: obscure ? 'Show password' : 'Hide password',
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  color: cs.onSurfaceVariant,
                ),
                onPressed: onToggleObscure,
              ),
            ),
            const SizedBox(height: 12),
            // Digital Agreement acceptance — required to register.
            InkWell(
              onTap: () => onAgreementChanged(!agreementAccepted),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: agreementAccepted,
                        onChanged: (v) => onAgreementChanged(v ?? false),
                        activeColor: cs.primary,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                          children: [
                            const TextSpan(
                              text: 'I have read and accept the ',
                            ),
                            TextSpan(
                              text: 'Membership Agreement',
                              style: TextStyle(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: cs.primary,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => launchUrl(
                                  Uri.parse(ApiConstants.tosUrl),
                                  mode: LaunchMode.externalApplication,
                                ),
                            ),
                            const TextSpan(text: ', '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: cs.primary,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => launchUrl(
                                  Uri.parse(ApiConstants.privacyUrl),
                                  mode: LaunchMode.externalApplication,
                                ),
                            ),
                            const TextSpan(text: ', and '),
                            TextSpan(
                              text: 'Member Manual',
                              style: TextStyle(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: cs.primary,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => launchUrl(
                                  Uri.parse(ApiConstants.manualUrl),
                                  mode: LaunchMode.externalApplication,
                                ),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (agreementError != null) ...[
              const SizedBox(height: 6),
              Text(
                agreementError!,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: cs.error),
              ),
            ],
            const SizedBox(height: 24),
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                final loading = state is AuthLoading;
                return MpButton(
                  label: 'Next: Add Your Pet →',
                  onPressed: loading ? null : onNext,
                  loading: loading,
                );
              },
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: onBack,
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                    children: [
                      const TextSpan(text: 'Already have an account? '),
                      TextSpan(
                        text: 'Sign in',
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
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
    );
  }
}

// ─── Step 2: Pet Details ──────────────────────────────────────────────────────

const _kMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

class _Step2 extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController petNameCtrl;
  final TextEditingController petBreedCtrl;
  final TextEditingController petWeightCtrl;
  final TextEditingController petNotesCtrl;
  final String? selectedSpecies;
  final void Function(String?) onSpeciesChanged;
  final String? selectedSex;
  final void Function(String?) onSexChanged;
  final int? selectedBirthMonth;
  final void Function(int?) onBirthMonthChanged;
  final int? selectedBirthYear;
  final void Function(int?) onBirthYearChanged;
  final int? selectedBirthDay;
  final void Function(int?) onBirthDayChanged;
  final Uint8List? petPhotoBytes;
  final VoidCallback onPickPhoto;
  final bool accountCreated;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _Step2({
    required this.formKey,
    required this.petNameCtrl,
    required this.petBreedCtrl,
    required this.petWeightCtrl,
    required this.petNotesCtrl,
    required this.selectedSpecies,
    required this.onSpeciesChanged,
    required this.selectedSex,
    required this.onSexChanged,
    required this.selectedBirthMonth,
    required this.onBirthMonthChanged,
    required this.selectedBirthYear,
    required this.onBirthYearChanged,
    required this.selectedBirthDay,
    required this.onBirthDayChanged,
    required this.petPhotoBytes,
    required this.onPickPhoto,
    required this.accountCreated,
    required this.onNext,
    required this.onBack,
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
          if (accountCreated)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.gold, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Account created — now let's add your pet.",
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: cs.primary),
                    ),
                  ),
                ],
              ),
            ),
          Text(
            "Your pet's pawprint",
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Text(
            "Let's meet your furry family member.",
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          // ── Pet photo upload ─────────────────────────────────────────────
          Semantics(
            label: petPhotoBytes != null
                ? 'Pet photo selected. Tap to change.'
                : 'Add pet photo. Tap to open gallery.',
            button: true,
            child: InkWell(
              onTap: onPickPhoto,
              borderRadius: BorderRadius.circular(100),
              child: Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.surfaceContainerHighest,
                        border: Border.all(color: cs.outline, width: 1.5),
                      ),
                      child: petPhotoBytes != null
                          ? ClipOval(
                              child: Image.memory(
                                petPhotoBytes!,
                                fit: BoxFit.cover,
                                excludeFromSemantics: true,
                              ),
                            )
                          : Icon(Icons.pets, size: 40, color: cs.onSurfaceVariant),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.navy,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                      child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              petPhotoBytes != null ? 'Tap to change photo' : 'Add a photo (optional)',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 24),
          MpTextField(
            controller: petNameCtrl,
            label: 'Pet name *',
            textInputAction: TextInputAction.next,
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          MpDropdownField<String>(
            value: selectedSpecies,
            label: 'Pet type *',
            items: const [
              DropdownMenuItem(value: 'Dog', child: Text('Dog')),
              DropdownMenuItem(value: 'Cat', child: Text('Cat')),
            ],
            onChanged: onSpeciesChanged,
          ),
          const SizedBox(height: 16),
          MpDropdownField<String>(
            value: selectedSex,
            label: 'Sex *',
            items: const [
              DropdownMenuItem(value: 'Male', child: Text('Male')),
              DropdownMenuItem(value: 'Female', child: Text('Female')),
            ],
            onChanged: onSexChanged,
          ),
          const SizedBox(height: 16),
          MpTextField(
            controller: petBreedCtrl,
            label: 'Breed *',
            textInputAction: TextInputAction.next,
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Age & vitals',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 0.5),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: MpDropdownField<int>(
                  value: selectedBirthMonth,
                  label: 'Birth month *',
                  items: List.generate(
                    12,
                    (i) => DropdownMenuItem(value: i + 1, child: Text(_kMonthNames[i])),
                  ),
                  onChanged: onBirthMonthChanged,
                  validator: (v) => v == null ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MpDropdownField<int>(
                  value: selectedBirthYear,
                  label: 'Birth year *',
                  items: List.generate(
                    currentYear - 1989,
                    (i) => DropdownMenuItem(
                      value: currentYear - i,
                      child: Text('${currentYear - i}'),
                    ),
                  ),
                  onChanged: onBirthYearChanged,
                  validator: (v) => v == null ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          MpDropdownField<int?>(
            value: selectedBirthDay,
            label: 'Birth day (optional)',
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('—')),
              ...List.generate(
                31,
                (i) => DropdownMenuItem<int?>(value: i + 1, child: Text('${i + 1}')),
              ),
            ],
            onChanged: onBirthDayChanged,
          ),
          const SizedBox(height: 16),
          MpTextField(
            controller: petWeightCtrl,
            label: 'Weight (kg) *',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              final val = double.tryParse(v.trim());
              if (val == null || val <= 0 || val > 200) return 'Enter a valid weight';
              return null;
            },
          ),
          const SizedBox(height: 16),
          MpTextField(
            controller: petNotesCtrl,
            label: 'Notes',
            hint: 'Allergies, special needs, anything useful...',
            maxLines: 3,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 28),
          MpButton(label: 'Next: Vaccination →', onPressed: onNext),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onBack,
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back,
                  size: 16,
                  color: accountCreated ? cs.outline : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'Back',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: accountCreated ? cs.outline : cs.onSurfaceVariant,
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

// ─── Step 3: Vaccination ──────────────────────────────────────────────────────

class _Step3 extends StatelessWidget {
  final Uint8List? vaxCardBytes;
  final VoidCallback onPickVax;
  final bool isLoading;
  final String? error;
  final VoidCallback onFinish;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  const _Step3({
    required this.vaxCardBytes,
    required this.onPickVax,
    required this.isLoading,
    required this.error,
    required this.onFinish,
    required this.onSkip,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Got a vaccine card?',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Optional — you can add this later from your profile.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        if (error != null) ...[
          MpErrorBanner(message: error!),
          const SizedBox(height: 16),
        ],
        Semantics(
          label: vaxCardBytes != null
              ? 'Vaccination card selected. Tap to change.'
              : 'Upload vaccination card. Tap to open gallery.',
          button: true,
          child: InkWell(
            onTap: onPickVax,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              height: 140,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outline),
              ),
              child: vaxCardBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.memory(
                        vaxCardBytes!,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.upload_file_outlined,
                          size: 36,
                          color: cs.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upload vaccination card',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: cs.primary),
                        ),
                        Text(
                          'JPG or PNG · max 5 MB',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        MpButton(
          label: 'Next: Choose Plan →',
          onPressed: isLoading ? null : onFinish,
          loading: isLoading,
        ),
        const SizedBox(height: 12),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: vaxCardBytes == null
              ? TextButton(
                  onPressed: isLoading ? null : onSkip,
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  child: Center(
                    child: Text(
                      'Skip for now',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: onBack,
          style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                'Back',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Step 4: Plan Selection ───────────────────────────────────────────────────

class _Step4Plan extends StatelessWidget {
  final String? selectedPlan;
  final void Function(String?) onPlanSelected;
  final bool isLoading;
  final String? error;
  final VoidCallback onConfirm;
  final VoidCallback onBack;
  final List<Plan> plans;
  final bool plansLoading;

  const _Step4Plan({
    required this.selectedPlan,
    required this.onPlanSelected,
    required this.isLoading,
    required this.error,
    required this.onConfirm,
    required this.onBack,
    required this.plans,
    required this.plansLoading,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selectedPlanObj = plans.where((p) => p.id == selectedPlan).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose your plan', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 8),
        Text(
          'Select a membership tier. No payment required right now.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        if (plansLoading)
          const Center(child: CircularProgressIndicator(color: AppColors.navy))
        else
        ...plans.map((plan) => _RegisterPlanTile(
          plan: plan,
          isSelected: selectedPlan == plan.id,
          onTap: () => onPlanSelected(plan.id),
        )),
        if (error != null) ...[
          const SizedBox(height: 4),
          MpErrorBanner(message: error!),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        MpButton(
          label: selectedPlanObj == null
              ? 'Select a plan to continue'
              : 'Continue with ${selectedPlanObj.subtitle} →',
          onPressed: (selectedPlan == null || isLoading) ? null : onConfirm,
          loading: isLoading,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onBack,
          style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('Back', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Register Plan Tile ───────────────────────────────────────────────────────

class _RegisterPlanTile extends StatefulWidget {
  final Plan plan;
  final bool isSelected;
  final VoidCallback onTap;

  const _RegisterPlanTile({
    required this.plan,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_RegisterPlanTile> createState() => _RegisterPlanTileState();
}

class _RegisterPlanTileState extends State<_RegisterPlanTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plan = widget.plan;
    final isSelected = widget.isSelected;
    final tier = tierStyleFor(plan.subtitle, isDark: isDark);
    final isDarkCard = isDarkCardTier(plan.subtitle);
    final cardBg = isDarkCard
        ? tier.cardSurface
        : (isDark ? const Color(0xFF1F2740) : Colors.white);
    final labelColor = isDarkCard
        ? tier.primaryText
        : (isDark ? const Color(0xFFEEF0FB) : AppColors.text);
    final subColor = isDarkCard
        ? tier.primaryText.withValues(alpha: 0.65)
        : (isDark ? const Color(0xFF8890B4) : AppColors.grey);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: _pressed ? Curves.easeInOut : Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppColors.gold
                  : (isDarkCard ? tier.borderColor : AppColors.greyLight),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          plan.subtitle.toUpperCase(),
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: labelColor,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        if (plan.isFeatured) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              'POPULAR',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (plan.tagline != null)
                      Text(
                        plan.tagline!,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: subColor),
                      ),
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
                    color: isSelected ? AppColors.gold : AppColors.greyLight,
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

// ─── Success State ────────────────────────────────────────────────────────────

class _SuccessState extends StatefulWidget {
  final VoidCallback onDashboard;

  const _SuccessState({required this.onDashboard});

  @override
  State<_SuccessState> createState() => _SuccessStateState();
}

class _SuccessStateState extends State<_SuccessState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _iconScale;
  late final Animation<double> _burstProgress;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _petNameSlide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );
    _burstProgress = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _contentFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.35, 0.8, curve: Curves.easeIn),
    );
    _petNameSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _burstProgress,
                  builder: (_, _) => CustomPaint(
                    size: const Size(160, 160),
                    painter: _GoldBurstPainter(_burstProgress.value),
                  ),
                ),
                ScaleTransition(
                  scale: _iconScale,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: AppColors.goldLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: AppColors.gold,
                      size: 40,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FadeTransition(
            opacity: _contentFade,
            child: Text(
              'Welcome to\nMetroPaws!',
              style: Theme.of(context).textTheme.displaySmall
                  ?.copyWith(color: cs.primary, height: 1.2),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          SlideTransition(
            position: _petNameSlide,
            child: FadeTransition(
              opacity: _contentFade,
              child: Text(
                'Your account is ready.',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FadeTransition(
            opacity: _contentFade,
            child: Text(
              'Add your first pet and choose a plan to unlock full access.',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          FadeTransition(
            opacity: _contentFade,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _TipRow(
                    icon: Icons.pets_rounded,
                    text: 'Tap "Add a pet" on the dashboard to register your fur baby.',
                  ),
                  const SizedBox(height: 8),
                  _TipRow(
                    icon: Icons.qr_code_rounded,
                    text: 'Each pet gets their own QR ID and service plan.',
                  ),
                  const SizedBox(height: 8),
                  _TipRow(
                    icon: Icons.check_circle_rounded,
                    text: 'Track sessions, bookings, and health records in one place.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          FadeTransition(
            opacity: _contentFade,
            child: MpButton(
              label: 'Go to Dashboard →',
              onPressed: widget.onDashboard,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoldBurstPainter extends CustomPainter {
  final double progress;
  _GoldBurstPainter(this.progress);

  static const _angles = [
    0.0, 0.628, 1.257, 1.885, 2.513, 3.142, 3.770, 4.398, 5.027, 5.655,
  ];
  static const _dists = [
    0.70, 0.85, 0.65, 0.90, 0.75, 0.80, 0.70, 0.85, 0.60, 0.75,
  ];
  static const _sizes = [
    5.0, 4.0, 6.0, 3.5, 5.5, 4.5, 5.0, 3.0, 6.0, 4.0,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.01) return;
    final paint = Paint()
      ..color = AppColors.gold.withValues(alpha: (1.0 - progress) * 0.85);
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = size.width * 0.48;

    for (var i = 0; i < _angles.length; i++) {
      final r = maxR * _dists[i] * progress;
      final x = cx + r * cos(_angles[i]);
      final y = cy + r * sin(_angles[i]);
      canvas.drawCircle(Offset(x, y), _sizes[i], paint);
    }
  }

  @override
  bool shouldRepaint(_GoldBurstPainter old) => old.progress != progress;
}

/// Strips the leading zero Philippine users commonly type ("09xxx" → "9xxx"),
/// removes any non-digit characters, and caps input at 10 digits.
class _PhNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.startsWith('0')) text = text.substring(1);
    if (text.length > 10) text = text.substring(0, 10);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TipRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.gold),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ],
    );
  }
}
