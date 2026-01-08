import 'package:flutter/material.dart';

class SiteProvisioningScreen extends StatelessWidget {
  const SiteProvisioningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Provisioning')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('Provision users, link guardians, set roles (stubbed UI).'),
          SizedBox(height: 12),
          Text('Implement forms against Security/Provisioning flows per doc 06/41/46.'),
        ],
      ),
    );
  }
}
