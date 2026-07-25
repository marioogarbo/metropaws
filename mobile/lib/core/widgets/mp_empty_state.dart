import 'package:flutter/material.dart';

import '../../theme.dart';

/// A calm, on-brand empty / first-run state: an icon in a soft circle with a
/// subtle gold glow (echoing the splash), a heading, and a supporting line,
/// revealed with a gentle entrance. Shared across tabs so empty states stay
/// consistent instead of each screen inventing its own. Respects the platform
/// reduce-motion setting.
class MpEmptyState extends StatefulWidget {
  final IconData icon;
  final String title;
  final String message;
  final EdgeInsetsGeometry padding;
  // Optional call to action shown below the message (e.g. an MpButton). Size it
  // yourself (wrap in a SizedBox) if you don't want a full-width button.
  final Widget? action;

  const MpEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.padding = const EdgeInsets.all(32),
    this.action,
  });

  @override
  State<MpEmptyState> createState() => _MpEmptyStateState();
}

class _MpEmptyStateState extends State<MpEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _rise;
  late final Animation<double> _iconScale;
  late final bool _reduceMotion;

  @override
  void initState() {
    super.initState();
    _reduceMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
      value: _reduceMotion ? 1.0 : 0.0,
    );
    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    );
    _rise = Tween<double>(begin: 12, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _iconScale = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    if (!_reduceMotion) _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final goldInk = isDark ? AppColors.gold : AppColors.goldDark;

    return Center(
      child: Padding(
        padding: widget.padding,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => Opacity(
            opacity: _fade.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, _rise.value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: _iconScale.value,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(
                              alpha: isDark ? 0.16 : 0.12,
                            ),
                            blurRadius: 28,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(widget.icon, size: 32, color: goldInk),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  if (widget.action != null) ...[
                    const SizedBox(height: 24),
                    widget.action!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
