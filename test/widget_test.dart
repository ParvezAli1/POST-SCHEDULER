// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:post_scheduler/app/app.dart';

void main() {
  testWidgets('Dashboard loads and navigation works', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PostSchedulerApp());

    expect(find.text('Dashboard'), findsOneWidget);

    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Scheduler'), findsOneWidget);
  });
}
