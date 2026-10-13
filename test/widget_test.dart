import 'package:flutter_test/flutter_test.dart';
import 'package:minicapstone_flutter/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const FootballTrainingApp());
    expect(find.byType(FootballTrainingApp), findsOneWidget);
  });
}