// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/screens/login_screen.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build app with test ApiService (no plugins / network)
    await tester.pumpWidget(DebtCollectionApp(apiService: ApiService(testMode: true)));

    // Let async microtasks (AuthWrapper init) complete
    await tester.pumpAndSettle();

    // Verify that the app loads and shows login (unauthenticated)
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
