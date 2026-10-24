
import 'package:flutter_test/flutter_test.dart';
import 'package:scam_sathi/main.dart';

void main() {
  testWidgets('ScamSathi app opens successfully',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ScamSathiApp());

    expect(find.text('ScamSathi'), findsWidgets);
  });
}
