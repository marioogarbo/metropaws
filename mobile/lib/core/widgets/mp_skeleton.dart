import 'package:flutter/material.dart';

/// A pulsing placeholder list shown while content loads — the product-standard
/// skeleton in place of a spinner floating in the middle of empty content. One
/// controller drives the whole group; respects the platform reduce-motion
/// setting (renders a static, mid-opacity placeholder).
class MpSkeleton extends StatefulWidget {
  final int items;
  final double itemHeight;
  final EdgeInsetsGeometry padding;

  const MpSkeleton({
    super.key,
    this.items = 4,
    this.itemHeight = 76,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 16),
  });

  @override
  State<MpSkeleton> createState() => _MpSkeletonState();
}

class _MpSkeletonState extends State<MpSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;
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
      duration: const Duration(milliseconds: 1100),
    );
    _pulse = Tween<double>(begin: 0.45, end: 0.9).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (!_reduceMotion) _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Loading',
      child: Padding(
        padding: widget.padding,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final opacity = _reduceMotion ? 0.6 : _pulse.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(widget.items, (i) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: i == widget.items - 1 ? 0 : 12,
                  ),
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      height: widget.itemHeight,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
