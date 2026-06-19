import 'package:flutter_test/flutter_test.dart';

import 'package:nutrilens_mobile_app/main.dart';

void main() {
  testWidgets('NutriLens app starts at login page', (tester) async {
    await tester.pumpWidget(const NutriLensApp());

    expect(find.text('NutriLens'), findsOneWidget);
    expect(find.text('Chào mừng trở lại!'), findsOneWidget);
  });
}
