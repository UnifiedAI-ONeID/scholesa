import 'package:flutter/material.dart';

class PartnerListingsScreen extends StatelessWidget {
  const PartnerListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Listings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('Create/edit marketplace listings (stub).'),
          SizedBox(height: 12),
          Text('Wire to MarketplaceListing per doc 15.'),
        ],
      ),
    );
  }
}
