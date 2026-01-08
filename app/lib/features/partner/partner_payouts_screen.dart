import 'package:flutter/material.dart';

class PartnerPayoutsScreen extends StatelessWidget {
  const PartnerPayoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payouts')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('View payout status/history (stub).'),
          SizedBox(height: 12),
          Text('Wire to Payout per doc 16.'),
        ],
      ),
    );
  }
}
