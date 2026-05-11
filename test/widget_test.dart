import 'package:flutter_test/flutter_test.dart';

import 'package:sr_tuner/main.dart';

void main() {
  testWidgets('startup screen shows project actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SrTunerApp());
    await tester.pump();

    expect(find.text('sr-tuner'), findsOneWidget);
    expect(find.text('Create Project'), findsAtLeastNWidgets(1));
    expect(find.text('Open Project'), findsAtLeastNWidgets(1));
  });
}
