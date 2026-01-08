import 'package:flutter/material.dart';

class HqIntegrationsScreen extends StatelessWidget {
  const HqIntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Integrations Health')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('Cross-site sync failures (stub).'),
          SizedBox(height: 12),
          Text('Wire to SyncJob failures per doc 31.'),
        ],
      ),
    );
  }
}
