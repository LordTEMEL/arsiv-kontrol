import 'package:arsiv_kontrol/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows safe archive verification workflow', (tester) async {
    await tester.pumpWidget(const ArchiveCheckApp());

    expect(find.text('Arşiv Kontrol'), findsOneWidget);
    expect(find.text('Doğrulanmış medyayı tara'), findsOneWidget);
    expect(find.textContaining('sistem onayıyla sil'), findsOneWidget);
  });
}
