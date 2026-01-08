import 'package:flutter/material.dart';

class ParentBillingScreen extends StatelessWidget {
  const ParentBillingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Billing')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('Receipts and payment status (stub).'),
          SizedBox(height: 12),
          Text('Wire to Order/Invoice per doc 13.'),
        ],
      ),
    );
  }
}
