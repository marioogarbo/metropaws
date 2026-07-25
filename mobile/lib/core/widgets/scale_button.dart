import 'package:flutter/material.dart';

/// Press-scale wrapper for tappable cards and custom buttons — the app's
/// standard tap feedback (scale to 0.97 on press, spring back on release).
/// Use this instead of a bare `GestureDetector` for anything tappable that
/// isn't already a themed `ElevatedButton` / `OutlinedButton`.
class ScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const ScaleButton({super.key, required this.child, required this.onTap});

  @override
  State<ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<ScaleButton> {
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
