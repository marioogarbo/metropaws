import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme.dart';

/// A trail of paw prints walking down the page behind a form.
///
/// Deliberately TRACKS, not wallpaper. Scattered paws at random angles are the
/// reflex move for a pet app and read as filler; a trail follows one heading,
/// alternates to either side of the line of travel the way a real gait does,
/// and tapers as it recedes — so it does a job, leading the eye from the
/// heading down toward the primary action. On first build the prints land one
/// after another, as though something just walked through. With
/// `disableAnimations` the finished trail is painted at once.
///
/// Ink, never gold: gold marks money and actions, and spending it on
/// decoration costs the signal (see CLAUDE.md).
///
/// Also applies the bottom safe-area inset to [child], since every auth screen
/// that wants the trail wants that too.
class MpPawBackdrop extends StatefulWidget {
  final Widget child;

  const MpPawBackdrop({super.key, required this.child});

  @override
  State<MpPawBackdrop> createState() => _MpPawBackdropState();
}

class _MpPawBackdropState extends State<MpPawBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _walk;
  bool _started = false;

  /// The box the trail was laid out against, kept across keyboard changes.
  double? _laidOutAtWidth;
  double _trailHeight = 0;

  /// The trail is positioned in fractions of the box it paints into, so
  /// painting it into the LIVE box means the whole gait compresses the moment
  /// the keyboard shortens the form area — stride and print size shrink
  /// together, which reads as the background deforming rather than as texture
  /// sitting behind the page. So the box is remembered: the tallest one seen at
  /// the current width, which is the keyboard-down state. The keyboard then
  /// crops the trail instead of squeezing it.
  void _rememberTrailBox(BoxConstraints box) {
    if (!box.hasBoundedHeight) return;
    // A width change is a genuinely different layout — rotation, or a fold
    // opening — not a keyboard, so start over rather than keep a trail sized
    // for the old orientation.
    if (_laidOutAtWidth != box.maxWidth) {
      _laidOutAtWidth = box.maxWidth;
      _trailHeight = box.maxHeight;
    } else if (box.maxHeight > _trailHeight) {
      _trailHeight = box.maxHeight;
    }
  }

  @override
  void initState() {
    super.initState();
    _walk = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery isn't readable in initState, so the walk starts here — once.
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _walk.value = 1.0;
    } else {
      _walk.forward();
    }
  }

  @override
  void dispose() {
    _walk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      // Explicit so the form fills the area rather than being sized by its
      // content — a short form would otherwise leave the trail painting into
      // space the Stack never claimed.
      fit: StackFit.expand,
      children: [
        // Isolated so the walk repaints the trail and nothing else, and so the
        // form's own rebuilds (typing, validation) never repaint the trail.
        Positioned.fill(
          child: RepaintBoundary(
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, box) {
                  _rememberTrailBox(box);
                  return OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: _trailHeight,
                    maxHeight: _trailHeight,
                    child: AnimatedBuilder(
                      animation: _walk,
                      builder: (context, _) => CustomPaint(
                        painter: _PawTrailPainter(progress: _walk.value),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        // Bottom inset only — the photo strip above deliberately runs under
        // the status bar, and the trail should reach the screen edge even
        // where the content must not.
        SafeArea(top: false, child: widget.child),
      ],
    );
  }
}

class _PawTrailPainter extends CustomPainter {
  /// 0 → nothing painted, 1 → the whole trail.
  final double progress;

  const _PawTrailPainter({required this.progress});

  // The route, as fractions of the painted area: in at the top right, out at
  // the bottom left. Hand-placed rather than generated — it has to clear the
  // heading's first line and land beside the primary action, not wander.
  static const _entry = Offset(0.94, 0.02);
  static const _exit = Offset(0.08, 0.88);
  static const _printCount = 8;

  /// Sideways offset from the line of travel, alternating per step — the gait.
  /// A share of width so it holds its shape from 320dp up.
  static const _stride = 0.055;

  // Big enough that the pad and toes read as one print. At 34px they
  // separated into a cluster of circles on a real screen.
  static const _nearSize = 46.0; // logical px, the closest print
  static const _farSize = 32.0; // logical px, the furthest
  static const _inkAlpha = 0.07;

  /// How much of the total walk one print takes to land.
  static const _landing = 0.34;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || size.isEmpty) return;

    final start = Offset(_entry.dx * size.width, _entry.dy * size.height);
    final travel =
        Offset(_exit.dx * size.width, _exit.dy * size.height) - start;
    if (travel.distance == 0) return;

    // A print points "up" in unit space, so this turns it to face the walk.
    final heading = math.atan2(travel.dx, -travel.dy);
    final sideways = Offset(-travel.dy, travel.dx) / travel.distance;

    for (var i = 0; i < _printCount; i++) {
      final landed = _landingProgress(i);
      if (landed <= 0) continue;

      final along = i / (_printCount - 1);
      final foot = i.isEven ? 1.0 : -1.0;
      final centre =
          start + travel * along + sideways * (foot * _stride * size.width);
      // Scales up as it lands, so a print presses in rather than fading in.
      final scale =
          (_nearSize + (_farSize - _nearSize) * along) * (0.78 + 0.22 * landed);

      final paint = Paint()
        ..color = AppColors.navy.withValues(alpha: _inkAlpha * landed);

      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.rotate(heading);
      canvas.scale(
        scale * foot,
        scale,
      ); // negative x mirrors left foot to right
      _paw(canvas, paint);
      canvas.restore();
    }
  }

  double _landingProgress(int index) {
    final startsAt = (index / _printCount) * (1 - _landing);
    final local = ((progress - startsAt) / _landing).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(local);
  }

  /// One print in unit space: about 1.0 wide, 1.15 tall, centred on the
  /// origin, toes toward negative y.
  void _paw(Canvas canvas, Paint paint) {
    // Metacarpal pad — wide and heavy, the part that makes a print a print.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 0.30), width: 0.72, height: 0.52),
      paint,
    );
    // Four toes in an arc over it, the outer two set lower and splayed.
    _toe(canvas, paint, const Offset(-0.36, -0.02), 0.28, 0.36, -0.45);
    _toe(canvas, paint, const Offset(-0.135, -0.26), 0.30, 0.38, -0.15);
    _toe(canvas, paint, const Offset(0.135, -0.26), 0.30, 0.38, 0.15);
    _toe(canvas, paint, const Offset(0.36, -0.02), 0.28, 0.36, 0.45);
  }

  void _toe(
    Canvas canvas,
    Paint paint,
    Offset at,
    double width,
    double height,
    double tilt,
  ) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(tilt);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: width, height: height),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PawTrailPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Scrolls, and centres its child in the viewport for as long as the child
/// fits.
///
/// Top-aligned, an auth form left a third of a tall phone empty below the last
/// link and pushed the fields up away from the thumb. Once the keyboard
/// shortens the area — or the text is scaled up — the child outgrows the
/// viewport and this behaves like the plain scroll view it wraps.
class MpCentredScroll extends StatelessWidget {
  final EdgeInsets padding;
  final Widget child;

  const MpCentredScroll({
    super.key,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, viewport) {
        // Unbounded height means there is no viewport to centre against, and a
        // very short one would ask for a negative minimum.
        final room = viewport.hasBoundedHeight
            ? math.max(0.0, viewport.maxHeight - padding.vertical)
            : 0.0;
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: room),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [child],
            ),
          ),
        );
      },
    );
  }
}
