import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cipher_clash_client/main.dart';

void main() {
  testWidgets('App boots to the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: CipherClashApp(signedIn: false)),
    );
    // The login screen runs looping glow animations, so pump fixed frames
    // instead of pumpAndSettle.
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(CipherClashApp), findsOneWidget);
    expect(find.text('CIPHER CLASH'), findsOneWidget);

    // Drain pending animation timers before the framework's invariant check.
    await tester.pump(const Duration(seconds: 30));
  });
}
