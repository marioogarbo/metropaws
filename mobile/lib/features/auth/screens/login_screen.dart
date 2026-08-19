import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../theme.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../core/widgets/mp_button.dart';
import '../../../core/widgets/mp_text_field.dart';
import '../../../core/widgets/mp_error_banner.dart';
import '../../../core/widgets/mp_brand_photo_strip.dart';
import '../../../core/widgets/mp_paw_backdrop.dart';
import '../../../core/widgets/staggered_reveal.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
      AuthLoginRequested(_emailCtrl.text.trim(), _passwordCtrl.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Read here, above the Scaffold — see MpBrandPhotoStrip.keyboardIsUp.
    final compact = MpBrandPhotoStrip.keyboardIsUp(context);

    return Scaffold(
      body: Column(
        children: [
          MpBrandPhotoStrip(
            imagePath: 'assets/images/pet-care-login.jpg',
            tagline: 'Membership in your pocket.',
            height: MpBrandPhotoStrip.heightFor(context),
            compact: compact,
          ),
          Expanded(
            child: MpPawBackdrop(
              child: MpCentredScroll(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StaggeredReveal(
                          index: 0,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome home.',
                                // The one element on the page that should
                                // feel too big. It steps down a level rather
                                // than shrinking to fit when the screen is
                                // narrow or the text is scaled up.
                                style:
                                    (context.isTight
                                            ? theme.textTheme.displaySmall
                                            : theme.textTheme.displayMedium)
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                        ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Sign in to check in on your pets.',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        // ── Error banner — derived from BLoC state ────────
                        BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, state) {
                            if (state is AuthFailure) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: MpErrorBanner(message: state.message),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                        StaggeredReveal(
                          index: 1,
                          child: MpTextField(
                            controller: _emailCtrl,
                            label: 'Email address',
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            prefix: const MpFieldIcon(
                              Icons.mail_outline_rounded,
                            ),
                            onFieldSubmitted: (_) => FocusScope.of(
                              context,
                            ).requestFocus(_passwordFocus),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Email address is required';
                              }
                              if (!RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(v)) {
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        StaggeredReveal(
                          index: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MpTextField(
                                controller: _passwordCtrl,
                                focusNode: _passwordFocus,
                                label: 'Password',
                                obscure: _obscure,
                                autofillHints: const [AutofillHints.password],
                                textInputAction: TextInputAction.done,
                                prefix: const MpFieldIcon(
                                  Icons.lock_outline_rounded,
                                ),
                                onFieldSubmitted: (_) => _submit(),
                                validator: (v) => v == null || v.length < 8
                                    ? 'Password must be at least 8 characters'
                                    : null,
                                suffix: IconButton(
                                  tooltip: _obscure
                                      ? 'Show password'
                                      : 'Hide password',
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              // Sits on the field's trailing edge, next to
                              // the eye the member just reached for after a
                              // failed attempt.
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const ForgotPasswordScreen(),
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(44, 44),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                  ),
                                  child: Text(
                                    'Forgot password?',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.navy,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        StaggeredReveal(
                          index: 3,
                          child: Column(
                            children: [
                              BlocBuilder<AuthBloc, AuthState>(
                                builder: (context, state) {
                                  final loading = state is AuthLoading;
                                  return MpButton(
                                    label: 'Sign In',
                                    onPressed: loading ? null : _submit,
                                    loading: loading,
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
                              TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(44, 44),
                                ),
                                child: RichText(
                                  text: TextSpan(
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    children: const [
                                      TextSpan(text: 'Not a member yet? '),
                                      TextSpan(
                                        text: 'Join the club',
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
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
