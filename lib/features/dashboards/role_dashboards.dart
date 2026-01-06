import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/app_state.dart';

const String buildTag = '2026-01-05c';

class RoleDashboard extends StatelessWidget {
  const RoleDashboard({super.key, required this.role});

  final String role;

  String get title {
    switch (role) {
      case 'learner':
        return 'Learner Dashboard';
      case 'educator':
        return 'Educator Dashboard';
      case 'parent':
        return 'Parent Dashboard';
      case 'site':
        return 'Site Lead Dashboard';
      case 'partner':
        return 'Partner Dashboard';
      case 'hq':
        return 'HQ Dashboard';
      default:
        return 'Dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currentRole = appState.role ?? role;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              appState.clearRole();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          )
        ],
      ),
      body: _buildContent(context, currentRole),
    );
  }

  Widget _buildContent(BuildContext context, String currentRole) {
    if (role == 'hq') {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Tooltip(
            message: 'Review users, set roles, and manage access across sites',
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: const Text('User Administration'),
                subtitle: const Text('Create, suspend, or update user roles'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/hq/user-admin'),
              ),
            ),
          ),
          Tooltip(
            message: 'See pending access or role change requests',
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.verified_user),
                title: const Text('Access Reviews'),
                subtitle: const Text('Pending approvals and escalations'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Access reviews coming soon')),
                  );
                },
              ),
            ),
          ),
          Tooltip(
            message: 'Audit changes and exports for compliance',
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Audit & Logs'),
                subtitle: const Text('Recent admin actions and exports'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Audit log coming soon')),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Build: $buildTag', style: Theme.of(context).textTheme.labelMedium),
        ],
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('Placeholder for $title (role: $currentRole)'),
          const SizedBox(height: 16),
          Text('Build: $buildTag', style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
