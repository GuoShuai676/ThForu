import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:thforu/app.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AIApp()));
    expect(find.text('ThForu'), findsOneWidget);
  });
}
