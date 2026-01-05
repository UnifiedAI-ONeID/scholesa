import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/app_state.dart';

const Map<String, String> roles = <String, String>{
  'learner': 'Learner',
  'educator': 'Educator',
  'parent': 'Parent',
  'site': 'Site Lead',
  'partner': 'Partner',
  'hq': 'HQ',
};

class RoleSelectorPage extends StatefulWidget {
  const RoleSelectorPage({super.key});

  @override
  State<RoleSelectorPage> createState() => _RoleSelectorPageState();
}

class _RoleSelectorPageState extends State<RoleSelectorPage> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (FirebaseAuth.instance.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final entitlements = context.watch<AppState>().entitlements;
    return Scaffold(
      appBar: AppBar(title: const Text('Choose role')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: roles.entries
            .map(
              (MapEntry<String, String> entry) => Card(
                child: ListTile(
                  title: Text(entry.value),
                  subtitle: entitlements.contains(entry.key)
                      ? null
                      : const Text('Not enabled for this account'),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: entitlements.contains(entry.key) ? null : Colors.grey,
                  ),
                  onTap: () {
                    if (!entitlements.contains(entry.key)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Role not enabled for this account')),
                      );
                      return;
                    }
                    context.read<AppState>().setRole(entry.key);
                    Navigator.pushNamed(context, '/dashboard/${entry.key}');
                  },
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
