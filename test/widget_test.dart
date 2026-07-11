import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutrilens_mobile_app/main.dart';

void main() {
  testWidgets('NutriLens app boots into the splash screen first',
      (tester) async {
    await tester.pumpWidget(const NutriLensApp());

    // Resolving a saved session happens off the secure-storage platform
    // channel, which isn't available under flutter_test — it fails and
    // falls back to the login screen, but the very first frame is always
    // the splash loader rather than skipping straight to login.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
