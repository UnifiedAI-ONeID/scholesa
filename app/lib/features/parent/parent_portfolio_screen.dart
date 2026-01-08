import 'package:flutter/material.dart';

class ParentPortfolioScreen extends StatelessWidget {
  const ParentPortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Portfolio Highlights')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('Parent-safe artifacts (stub).'),
          SizedBox(height: 12),
          Text('Wire to parent-visible PortfolioItem subset with consent gates per doc 41.'),
        ],
      ),
    );
  }
}
