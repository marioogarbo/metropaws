import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';

class MpTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final Widget? prefix;
  final String? prefixText;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final void Function(String)? onFieldSubmitted;
  final int? maxLength;
  final int? maxLines;
  final List<TextInputFormatter>? inputFormatters;

  /// Trailing unit printed inside the field (e.g. `kg`). Keeps the unit out of
  /// the label, so the label stays a plain noun the member can read at a
  /// glance instead of "Weight (kg)".
  final String? suffixText;

  /// Standing guidance under the field. Reserves its own line, so use it only
  /// where the hint genuinely helps — it costs vertical rhythm on every field
  /// that carries one.
  final String? helperText;

  /// Sentence/word capitalisation. Names and breeds are proper nouns, and the
  /// keyboard should say so rather than leaving "bella" to be corrected.
  final TextCapitalization textCapitalization;

  /// Per-field validation timing. Set this rather than putting
  /// `autovalidateMode` on the enclosing [Form]: a Form-level setting marks the
  /// WHOLE form as interacted with the first time any one field changes, so
  /// choosing a pet type lights up every other field in red at once.
  final AutovalidateMode? autovalidateMode;

  /// Overrides the field's text style — e.g. `fontFeatures:
  /// [FontFeature.tabularFigures()]` for currency/amount fields so digits
  /// don't shift width while typing. Leave null everywhere else; it has no
  /// effect on existing call sites.
  final TextStyle? style;

  const MpTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.suffix,
    this.prefix,
    this.prefixText,
    this.autofillHints,
    this.textInputAction,
    this.focusNode,
    this.onFieldSubmitted,
    this.maxLength,
    this.maxLines,
    this.inputFormatters,
    this.style,
    this.suffixText,
    this.helperText,
    this.textCapitalization = TextCapitalization.none,
    this.autovalidateMode,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      autovalidateMode: autovalidateMode,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      focusNode: focusNode,
      onFieldSubmitted: onFieldSubmitted,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      maxLines: obscure ? 1 : (maxLines ?? 1),
      style: style,
      // Android and iOS deliberately KEEP focus when a touch lands outside the
      // field, so without this the caret and the keyboard stay put wherever the
      // member taps and the field reads as stuck open. Every text field shares
      // one TapRegion group, so moving between fields — or reaching for the eye
      // in the suffix — is not "outside" and does not fire this.
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        prefixIcon: prefix,
        suffixIcon: suffix,
        suffixText: suffixText,
        helperText: helperText,
        counterText: '',
      ),
    );
  }
}

/// Leading mark for a text field. The membership spans a broad age range and
/// mixed digital comfort, so an icon makes a field's job legible before the
/// label is read. Navy at partial alpha, not gold: gold marks money and
/// actions, and a field ornament is neither.
class MpFieldIcon extends StatelessWidget {
  final IconData icon;

  const MpFieldIcon(this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: 20, color: AppColors.navy.withValues(alpha: 0.55));
  }
}
