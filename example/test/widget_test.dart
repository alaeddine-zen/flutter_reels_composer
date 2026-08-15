import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_reels_composer_example/main.dart';

void main() {
  testWidgets('opens the example home', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('Open composer'), findsOneWidget);
  });
}
