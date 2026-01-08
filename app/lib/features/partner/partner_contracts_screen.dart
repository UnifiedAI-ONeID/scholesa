import 'package:flutter/material.dart';

class PartnerContractsScreen extends StatelessWidget {
  const PartnerContractsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contracts')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('Submit deliverables, respond to reviews (stub).'),
          SizedBox(height: 12),
          Text('Wire to PartnerContract and PartnerDeliverable per doc 16.'),
        ],
      ),
    );
  }
}
