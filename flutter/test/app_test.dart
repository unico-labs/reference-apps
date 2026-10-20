import 'package:flutter_test/flutter_test.dart';

import '../app/main.dart';
import '../settings/settings.dart';

void main() {
  testWidgets('opens Connect when the device has no credentials', (tester) async {
    await tester.pumpWidget(const ReferenceApp(settings: Settings()));

    expect(find.text('Connect your Unico account'), findsOneWidget);
  });
}
