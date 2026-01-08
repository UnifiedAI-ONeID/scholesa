import 'package:flutter/material.dart';

class SiteIdentityScreen extends StatelessWidget {
  const SiteIdentityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Identity Resolution')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('Approve/merge external identity links (stub).'),
          SizedBox(height: 12),
          Text('Wire to ExternalIdentityLink per doc 46.'),
        ],
      ),
    );
  }
}
