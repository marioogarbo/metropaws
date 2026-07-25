import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/mp_button.dart';
import '../../../core/widgets/mp_error_banner.dart';
import '../../../core/widgets/mp_text_field.dart';
import '../../../core/widgets/mp_brand_photo_strip.dart';
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
    // Mirror LoginScreen: dark "navy gift box" photo strip header + a form area
    // that inherits the scaffold theme (adapts to light/dark) — the previous
    // screen forced a light surface, so dark-theme text rendered faint on white.
    final headerHeight = MediaQuery.of(context).size.height * 0.28;

    return Scaffold(
      body: Column(
        children: [
          MpBrandPhotoStrip(
            imagePath: 'assets/images/pet-care-login.jpg',
            tagline: "Let's get you back in.",
            height: headerHeight,
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
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

// ─── Shared: gold accent badge ─────────────────────────────────────────────────

class _AccentBadge extends StatelessWidget {
  final IconData icon;
  const _AccentBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        color: Color(0x26B89A3E), // gold 15% — reads on both light & dark
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppColors.gold, size: 28),
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
        const _AccentBadge(icon: Icons.lock_reset_rounded),
        const SizedBox(height: 20),
        Text(
          'Reset your password',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Enter your email and we'll send you a link to set a new password.",
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        if (error != null) ...[
          MpErrorBanner(message: error!),
          const SizedBox(height: 16),
        ],
        Form(
          key: formKey,
          child: MpTextField(
            controller: emailCtrl,
            label: 'Email address',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
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
        const SizedBox(height: 24),
        MpButton(
          label: 'Send Reset Link',
          onPressed: isLoading ? null : onSubmit,
          loading: isLoading,
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: onBackToSignIn,
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                children: const [
                  TextSpan(text: 'Remember your password? '),
                  TextSpan(
                    text: 'Sign In',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
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
        const _AccentBadge(icon: Icons.mark_email_read_outlined),
        const SizedBox(height: 20),
        Text(
          'Check your inbox',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
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
