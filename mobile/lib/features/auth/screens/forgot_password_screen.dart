import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/mp_button.dart';
import '../../../core/widgets/mp_error_banner.dart';
import '../../../core/widgets/mp_text_field.dart';
import '../../../core/widgets/mp_brand_photo_strip.dart';
import '../../../core/widgets/mp_paw_backdrop.dart';
import '../../../core/widgets/staggered_reveal.dart';
import '../../../theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ApiService.requestPasswordReset(_emailCtrl.text.trim());
      if (mounted) {
        setState(() {
          _isLoading = false;
          _sent = true;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Could not connect. Check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mirrors LoginScreen: photo header with a rounded foot, then the cream
    // form field with the paw trail behind it. The form area inherits the
    // scaffold theme — an earlier version forced a light surface, which left
    // dark-theme text faint on white.
    // Read here, above the Scaffold — see MpBrandPhotoStrip.keyboardInset.
    final keyboardInset = MpBrandPhotoStrip.keyboardInset(context);

    return Scaffold(
      body: Column(
        children: [
          MpBrandPhotoStrip(
            imagePath: 'assets/images/pet-care-login.jpg',
            tagline: 'It happens to the best of us.',
            height: MpBrandPhotoStrip.heightFor(context),
            compact: keyboardInset > 0,
          ),
          Expanded(
            child: MpPawBackdrop(
              keyboardInset: keyboardInset,
              child: MpCentredScroll(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: _sent
                    ? _SuccessView(
                        email: _emailCtrl.text.trim(),
                        onBackToSignIn: () => Navigator.pop(context),
                        onTryAnother: () => setState(() {
                          _sent = false;
                          _error = null;
                          _emailCtrl.clear();
                        }),
                      )
                    : _RequestView(
                        formKey: _formKey,
                        emailCtrl: _emailCtrl,
                        isLoading: _isLoading,
                        error: _error,
                        onSubmit: _submit,
                        onBackToSignIn: () => Navigator.pop(context),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared: state badge ──────────────────────────────────────────────────────

/// Marks which of the two states the screen is in. Tinted ink, not gold — gold
/// is the 10% and is spent on money and actions, and a state marker is neither.
class _StateBadge extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color foreground;

  const _StateBadge({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, color: foreground, size: 30),
    );
  }
}

// ─── Request State ────────────────────────────────────────────────────────────

class _RequestView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final bool isLoading;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onBackToSignIn;

  const _RequestView({
    required this.formKey,
    required this.emailCtrl,
    required this.isLoading,
    required this.error,
    required this.onSubmit,
    required this.onBackToSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StaggeredReveal(
          index: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _StateBadge(
                icon: Icons.lock_reset_rounded,
                background: AppColors.navyLight,
                foreground: AppColors.navy,
              ),
              const SizedBox(height: 20),
              Text(
                "Let's get you back in.",
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Enter your email and we'll send you a link to set a new "
                'password.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        if (error != null) ...[
          MpErrorBanner(message: error!),
          const SizedBox(height: 16),
        ],
        StaggeredReveal(
          index: 1,
          child: Form(
            key: formKey,
            child: MpTextField(
              controller: emailCtrl,
              label: 'Email address',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              prefix: const MpFieldIcon(Icons.mail_outline_rounded),
              onFieldSubmitted: (_) => onSubmit(),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter your email';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        StaggeredReveal(
          index: 2,
          child: Column(
            children: [
              MpButton(
                label: 'Send Reset Link',
                onPressed: isLoading ? null : onSubmit,
                loading: isLoading,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: onBackToSignIn,
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                child: RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    children: const [
                      TextSpan(text: 'Remembered it? '),
                      TextSpan(
                        text: 'Back to sign in',
                        style: TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Success State ────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final String email;
  final VoidCallback onBackToSignIn;
  final VoidCallback onTryAnother;

  const _SuccessView({
    required this.email,
    required this.onBackToSignIn,
    required this.onTryAnother,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StateBadge(
          icon: Icons.mark_email_read_outlined,
          background: AppColors.successLight,
          foreground: AppColors.success,
        ),
        const SizedBox(height: 20),
        Text(
          'Check your inbox',
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 10),
        RichText(
          text: TextSpan(
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            children: [
              const TextSpan(text: 'We sent a reset link to '),
              TextSpan(
                text: email,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _TipRow(
                emoji: '💡',
                text: 'Tip: The reset link expires in 1 hour.',
              ),
              const SizedBox(height: 8),
              _TipRow(
                emoji: '📁',
                text: "Check your spam folder if you don't see it.",
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        MpButton(label: 'Back to Sign In', onPressed: onBackToSignIn),
        const SizedBox(height: 12),
        MpButton(
          label: 'Try Another Email',
          onPressed: onTryAnother,
          outlined: true,
        ),
      ],
    );
  }
}

class _TipRow extends StatelessWidget {
  final String emoji;
  final String text;

  const _TipRow({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16), semanticsLabel: ''),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
