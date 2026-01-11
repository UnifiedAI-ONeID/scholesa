import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/auth/app_state.dart';
import 'features/auth/login_page.dart';
import 'features/auth/register_page.dart';
import 'features/dashboards/hq_user_admin_page.dart';
import 'features/dashboards/role_dashboards.dart';
import 'features/dashboards/role_selector_page.dart';
import 'features/dashboards/user_profile_service.dart';

class ScholesaApp extends StatelessWidget {
  const ScholesaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'Scholesa EDU',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: const AuthRouter(),
        routes: <String, Object Function(context)>{
          '/login': (Object? context) => const LoginPage(),
          '/register': (Object? context) => const RegisterPage(),
          '/roles': (Object? context) => const RoleSelectorPage(),
          '/dashboard/learner': (Object? context) => const RoleDashboard(role: 'learner'),
          '/dashboard/educator': (Object? context) => const RoleDashboard(role: 'educator'),
          '/dashboard/parent': (Object? context) => const RoleDashboard(role: 'parent'),
          '/dashboard/site': (Object? context) => const RoleDashboard(role: 'site'),
          '/dashboard/partner': (Object? context) => const RoleDashboard(role: 'partner'),
          '/dashboard/hq': (Object? context) => const RoleDashboard(role: 'hq'),
          '/hq/user-admin': (Object? context) => const HqUserAdminPage(),
        },
      ),
    );
  }
}

class AuthRouter extends StatelessWidget {
  const AuthRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snapshot.data;
        if (user == null) {
          appState.clearAll();
          return const LoginPage();
        }

        return FutureBuilder<UserProfile?>(
          future: UserProfileService().fetchProfile(user.uid),
          builder: (BuildContext context, AsyncSnapshot<UserProfile?> profileSnap) {
            if (profileSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (profileSnap.hasError) {
              return Scaffold(
                body: Center(child: Text('Failed to load profile: ${profileSnap.error}')),
              );
            }

            final profile = profileSnap.data;
            if (profile == null) {
              return const Scaffold(
                body: Center(child: Text('Profile missing. Contact an administrator.')),
              );
            }

            appState.setProfile(profile);
            final role = profile.role;
            if (role == null) {
              return const RoleSelectorPage();
            }

            switch (role) {
              case 'learner':
                return const RoleDashboard(role: 'learner');
              case 'educator':
                return const RoleDashboard(role: 'educator');
              case 'parent':
                return const RoleDashboard(role: 'parent');
              case 'site':
                return const RoleDashboard(role: 'site');
              case 'partner':
                return const RoleDashboard(role: 'partner');
              case 'hq':
                return const RoleDashboard(role: 'hq');
              default:
                return const RoleSelectorPage();
            }
          },
        );
      },
    );
  }
}