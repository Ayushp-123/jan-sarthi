import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jan_sarthi/widgets/sos_button.dart';

void main() {
  testWidgets('SOSButton renders and responds to tap', (WidgetTester tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SOSButton(
            onPressed: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('HELP'), findsOneWidget);
    expect(find.text('TAP TO SOS'), findsOneWidget);

    await tester.tap(find.byType(SOSButton));
    expect(tapped, isTrue);
  });
}
