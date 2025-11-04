// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:readright/main.dart';
import 'package:readright/services/auth_service.dart';

void main() {
  testWidgets('Shows sign in screen by default', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final authController = AuthController(
      repository: MockAuthRepository(prefs),
    );
    await authController.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: authController,
        child: const ReadRightApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Sign in'), findsOneWidget);
    expect(find.textContaining('Demo accounts'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(2));
  });
}
