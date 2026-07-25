import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/api_constants.dart';

/// The "I have read and accept …" clickwrap row shown before any payment
/// (Add-a-Pet plan step, existing-pet plan confirm sheet).
///
/// The legally binding, version-stamped acceptance is recorded at registration
/// (`agreement_accepted_at` / `agreement_version` on the backend Member row);
/// this widget is the pre-payment reaffirmation gate — the paying member
/// re-confirms the same documents right before money moves. Keep the document
/// list in sync with the registration checkbox in `register_screen.dart`.
class AgreementCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const AgreementCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  TextSpan _link(BuildContext context, String text, String url) {
    final cs = Theme.of(context).colorScheme;
    return TextSpan(
      text: text,
      style: TextStyle(
        color: cs.primary,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
        decorationColor: cs.primary,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () => launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => onChanged(!value),
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
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: cs.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                  children: [
                    const TextSpan(text: 'I have read and accept the '),
                    _link(context, 'Membership Agreement', ApiConstants.tosUrl),
                    const TextSpan(text: ', '),
                    _link(context, 'Privacy Policy', ApiConstants.privacyUrl),
                    const TextSpan(text: ', and '),
                    _link(context, 'Member Manual', ApiConstants.manualUrl),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
