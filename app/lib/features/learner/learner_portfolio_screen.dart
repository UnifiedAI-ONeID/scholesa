import 'package:flutter/material.dart';

class LearnerPortfolioScreen extends StatelessWidget {
  const LearnerPortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Portfolio')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('Portfolio highlights and credentials (stub).'),
          SizedBox(height: 12),
          Text('Wire to PortfolioItem and Credential per docs 01/02A.'),
        ],
      ),
    );
  }
}
