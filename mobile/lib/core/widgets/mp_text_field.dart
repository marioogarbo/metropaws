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
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      focusNode: focusNode,
      onFieldSubmitted: onFieldSubmitted,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      maxLines: obscure ? 1 : (maxLines ?? 1),
      style: style,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        prefixIcon: prefix,
        suffixIcon: suffix,
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
