import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cipher_clash_client/main.dart';

void main() {
  testWidgets('App smoke test - app initializes', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: CipherClashApp()));

    // Verify that the app builds without crashing.
    expect(find.byType(CipherClashApp), findsOneWidget);
  });

  testWidgets('App smoke test - shows login screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: CipherClashApp()));
    await tester.pumpAndSettle();

    // Verify that we land on the login screen.
    expect(find.text('CIPHER CLASH'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
  });
}
