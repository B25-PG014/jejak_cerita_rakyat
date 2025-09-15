// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jejak_cerita_rakyat/app.dart'; // <-- impor MyApp dari app.dart

void main() {
  testWidgets('app builds', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MyApp), findsOneWidget);
  });
}
