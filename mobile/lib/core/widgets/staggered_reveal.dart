import 'package:flutter/material.dart';

/// Fade + slide-up entrance for list items appearing on first load, with a
/// per-index delay (60ms/item) so the list reveals in sequence rather than
/// popping in at once. Respects `disableAnimations`. Cap the number of items
/// you stagger — delay grows linearly, so don't feed this a 100-item list.
class StaggeredReveal extends StatelessWidget {
  final int index;
  final Widget child;

  const StaggeredReveal({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    const revealMs = 320;
    final delayMs = 60 * index;
    final totalMs = revealMs + delayMs;
    final delayFraction = delayMs / totalMs;
    return TweenAnimationBuilder<double>(
      key: ValueKey('stagger-reveal-$index'),
      // Linear time fraction (0→1 over totalMs) — curve is applied manually
      // below, after the delay hold, so it shapes the reveal, not the wait.
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: totalMs),
      builder: (context, t, child) {
        final revealT = ((t - delayFraction) / (1 - delayFraction)).clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(revealT);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, (1 - eased) * 12),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
