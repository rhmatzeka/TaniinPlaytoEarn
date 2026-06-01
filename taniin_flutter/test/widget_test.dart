import 'package:flutter_test/flutter_test.dart';
import 'package:taniin_flutter/src/app/taniin_app.dart';

void main() {
  testWidgets('renders the Taniin game shell HUD', (WidgetTester tester) async {
    await tester.pumpWidget(const TaniinApp());
    await tester.pump();

    expect(find.text('COIN'), findsOneWidget);
    expect(find.text('TANI'), findsOneWidget);
    expect(find.text('CONNECT WALLET'), findsOneWidget);
  });
}
