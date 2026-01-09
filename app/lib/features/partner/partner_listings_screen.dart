import 'package:flutter/material.dart';

class PartnerListingsScreen extends StatelessWidget {
  const PartnerListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Listings')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('MarketplaceListing repo not present; add when available to list/create listings.'),
        ),
      ),
    );
  }
}
