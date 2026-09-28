import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:billing/main.dart';

void main() {
  testWidgets('MightyBillingApp boots up with navigation destinations', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MightyBillingApp(),
      ),
    );

    // Initial frame shows splash screen
    await tester.pump();

    // Tap splash screen to skip immediately
    await tester.tap(find.byType(GestureDetector));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify main destinations exist
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Invoices'), findsOneWidget);
    expect(find.text('Customers'), findsOneWidget);
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
