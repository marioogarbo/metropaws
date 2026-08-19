import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';

/// The photo header the auth screens open on.
///
/// The foot is rounded so the page reads as two materials — the navy lid of the
/// membership box, the cream linen inside it — instead of one photo dissolving
/// into a background, which is what the old gradient-to-scaffold trick did.
///
/// It also gets out of the way: pass [compact] and the strip shrinks to a band
/// and drops the tagline, handing the room back to the form. With the keyboard
/// up that is the difference between a visible Sign In button and one the
/// member has to go looking for.
class MpBrandPhotoStrip extends StatelessWidget {
  final String imagePath;

  /// One short line under the lockup. Null hides it, which is what a header
  /// with nothing to add should do.
  final String? tagline;

  /// Height at rest. [compact] overrides it downward.
  final double height;

  /// Give the room back. See [keyboardIsUp] for who decides.
  final bool compact;

  const MpBrandPhotoStrip({
    super.key,
    required this.imagePath,
    required this.height,
    this.tagline,
    this.compact = false,
  });

  static const collapsedHeight = 108.0;
  static const _footRadius = 28.0;

  /// The strip's height at rest.
  ///
  /// Owned here, not by each screen: the three auth screens all show the SAME
  /// photograph, so any difference between them reads as the one image being
  /// resized mid-flow rather than as hierarchy — and login pushing to
  /// forgot-password makes the change visible. Proportional so it keeps its
  /// share of tall and short phones, clamped at both ends so it never eats the
  /// form on a 560dp-tall screen nor swallows the page on a tablet.
  static double heightFor(BuildContext context) =>
      (MediaQuery.sizeOf(context).height * 0.28).clamp(168.0, 250.0);

  /// Whether the keyboard is up, and so whether [compact] should be set.
  ///
  /// MUST be called from the build method that RETURNS the Scaffold, never from
  /// inside its body: with `resizeToAvoidBottomInset` on, `Scaffold` strips the
  /// bottom view inset from the MediaQuery it hands its body, so the identical
  /// check one level down reads 0 forever and silently never fires. That is why
  /// the screens compute this and pass it in rather than the strip reading it.
  static bool keyboardIsUp(BuildContext context) =>
      MediaQuery.viewInsetsOf(context).bottom > 0;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final target = compact ? math.min(collapsedHeight, height) : height;
    const foot = BorderRadius.vertical(bottom: Radius.circular(_footRadius));

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: target, end: target),
      duration: Duration(milliseconds: reduceMotion ? 0 : 260),
      curve: Curves.easeOutQuart,
      builder: (context, animatedHeight, _) =>
          // The auth screens carry no AppBar, so Flutter has no background to
          // derive the status-bar style from and they inherit whatever the
          // previous screen set — which left dark icons sitting on the photo.
          // Same fix, and same reason, as payment_result_screen's AnnotatedRegion.
          AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: Container(
              height: animatedHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: foot,
                // Lifts the lid off the linen. Subtle — the brand takes no harsh
                // drop shadows.
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navy.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: foot,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _SettlingPhoto(imagePath: imagePath),
                    const DecoratedBox(
                      decoration: BoxDecoration(gradient: _vignette),
                    ),
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 20,
                      child: _Lockup(tagline: tagline, showTagline: !compact),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  /// Dark at the crown so the status-bar icons stay legible over a bright sky,
  /// open through the middle so the animal actually reads, dark again at the
  /// foot so the lockup has ~5:1 to sit on.
  static const _vignette = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.34, 1.0],
    colors: [
      Color(0x57263258), // navy 34%
      Color(0x52263258), // navy 32%
      Color(0xDB263258), // navy 86%
    ],
  );
}

class _Lockup extends StatelessWidget {
  final String? tagline;
  final bool showTagline;

  const _Lockup({this.tagline, required this.showTagline});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/logo-full-white-metro.png',
          height: 30,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          semanticLabel: 'MetroPaws',
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
        // Dropped from the layout when collapsed, not just faded: holding the
        // slot open pushed the lockup up into the status bar, where it sat a
        // few pixels off the clock. The strip's own height animation covers
        // the change.
        if (tagline != null && showTagline) ...[
          const SizedBox(height: 10),
          Text(
            tagline!,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.white,
              letterSpacing: 0.1,
              shadows: [
                Shadow(
                  color: AppColors.navy.withValues(alpha: 0.6),
                  blurRadius: 10,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The photo eases out of a slight over-scale on open, so the yard settles
/// rather than snapping into place. One gesture, 1.2s, never repeated.
class _SettlingPhoto extends StatefulWidget {
  final String imagePath;

  const _SettlingPhoto({required this.imagePath});

  @override
  State<_SettlingPhoto> createState() => _SettlingPhotoState();
}

class _SettlingPhotoState extends State<_SettlingPhoto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settle;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _settle.value = 1.0;
    } else {
      _settle.forward();
    }
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = Image.asset(
      widget.imagePath,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.navy),
    );
    return AnimatedBuilder(
      animation: _settle,
      builder: (context, child) => Transform.scale(
        scale: 1.06 - 0.06 * Curves.easeOutQuart.transform(_settle.value),
        child: child,
      ),
      child: photo,
    );
  }
}
