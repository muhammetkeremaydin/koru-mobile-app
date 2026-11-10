import 'package:flutter_test/flutter_test.dart';
import 'package:koru/main.dart';

void main() {
  testWidgets('app starts and shows its name', (tester) async {
    await tester.pumpWidget(const KoruApp());
    expect(find.text('Koru'), findsOneWidget);
  });
}
