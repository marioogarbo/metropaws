import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metropaws/features/member/bloc/member_bloc.dart';
import 'package:metropaws/features/member/screens/paw_points_screen.dart';

/// The "How PawPoints work" sheet lays its earning table out with stretched Rows
/// so the member's plan reads as one unbroken tinted column. Stretch needs a
/// bounded height and the sheet scrolls, so the table has to resolve its own —
/// getting that wrong throws during layout and the whole sheet renders blank,
/// which no amount of static analysis catches.
void main() {
  testWidgets('the help sheet lays out instead of rendering blank', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => MemberBloc(),
          child: const PawPointsScreen(planType: 'Deluxe Plan'),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('How PawPoints work'));
    // Not pumpAndSettle: with no network the screen sits on its loading
    // spinner, which never settles. The sheet's entrance is ~250ms.
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text('How PawPoints work'), findsOneWidget);
    expect(find.text('Activate Membership'), findsOneWidget);
    // Plan names are spelled out, never abbreviated, even though that pushes
    // the table past the screen and into a horizontal scroll.
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Deluxe'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
    // The member's own rate, and the rate they'd reach on Premium.
    expect(find.text('200'), findsOneWidget);
    expect(find.text('300'), findsWidgets);
  });
}
