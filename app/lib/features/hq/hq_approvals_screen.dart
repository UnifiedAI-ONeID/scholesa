import 'package:flutter/material.dart';

class HqApprovalsScreen extends StatelessWidget {
  const HqApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Approvals Queue')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('Listings, contracts, payouts approvals (stub).'),
          SizedBox(height: 12),
          Text('Wire to MarketplaceListing, PartnerContract, Payout per docs 15/16.'),
        ],
      ),
    );
  }
}
