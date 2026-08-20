import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metropaws/core/widgets/mp_brand_photo_strip.dart';
import 'package:metropaws/core/widgets/mp_paw_backdrop.dart';
import 'package:metropaws/core/widgets/mp_text_field.dart';

/// The skeleton every auth screen shares: collapsing photo header, paw trail
/// behind the form.
class _AuthSkeleton extends StatelessWidget {
  final Widget child;

  const _AuthSkeleton({required this.child});

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MpBrandPhotoStrip.keyboardInset(context);
    return Scaffold(
      body: Column(
        children: [
          MpBrandPhotoStrip(
            imagePath: 'assets/images/pet-care-login.jpg',
            tagline: 'Membership in your pocket.',
            height: MpBrandPhotoStrip.heightFor(context),
            compact: keyboardInset > 0,
          ),
          Expanded(
            child: MpPawBackdrop(keyboardInset: keyboardInset, child: child),
          ),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('the paw trail holds its place when the keyboard opens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: _AuthSkeleton(child: SizedBox.expand())),
    );
    await tester.pumpAndSettle();

    // The painted trail, not the OverflowBox around it: the box takes the
    // live size and hands the resting one down to its child.
    final trail = find.descendant(
      of: find.byType(MpPawBackdrop),
      matching: find.byType(CustomPaint),
    );
    final restingTop = tester.getTopLeft(trail);
    final restingSize = tester.getSize(trail);
    final restingHeader = tester.getSize(find.byType(MpBrandPhotoStrip)).height;

    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pumpAndSettle();

    // The header really did get out of the way — otherwise the assertions
    // below would pass on a screen where nothing moved at all.
    expect(
      tester.getSize(find.byType(MpBrandPhotoStrip)).height,
      lessThan(restingHeader),
    );
    final movedTop = tester.getTopLeft(trail);
    expect(movedTop.dy, closeTo(restingTop.dy, 0.01));
    expect(movedTop.dx, closeTo(restingTop.dx, 0.01));
    expect(tester.getSize(trail).height, closeTo(restingSize.height, 0.01));
  });

  testWidgets('a tap outside a field drops focus', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: _AuthSkeleton(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: MpTextField(
              controller: controller,
              focusNode: node,
              label: 'Email address',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(MpTextField));
    await tester.pumpAndSettle();
    expect(node.hasFocus, isTrue);

    // On the empty page above the field — a touch, which is the case Flutter
    // deliberately ignores by default.
    await tester.tapAt(const Offset(40, 400));
    await tester.pumpAndSettle();
    expect(node.hasFocus, isFalse);
  });
}
