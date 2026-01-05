// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:app/features/auth/app_state.dart';
import 'package:app/features/auth/auth_service.dart';
import 'package:app/features/landing/landing_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Landing renders pillars', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(authService: _FakeAuthService()),
        child: const MaterialApp(home: LandingPage()),
      ),
    );

    expect(find.text('Scholesa'), findsOneWidget);
    expect(find.text('Future Skills'), findsOneWidget);
    expect(find.text('Leadership & Agency'), findsOneWidget);
    expect(find.text('Impact & Innovation'), findsOneWidget);
  });
}

class _FakeAuthService implements AuthServiceBase {
  @override
  Future<EntitlementsResult> loadEntitlements() async => const EntitlementsResult(
        roles: {'learner', 'educator'},
        siteIds: <String>['site-demo'],
        primarySiteId: 'site-demo',
      );

  @override
  Future<User?> register({required String email, required String password}) async => null;

  @override
  Future<User?> signIn({required String email, required String password}) async => null;

  @override
  Future<void> signOut() async {}
}
