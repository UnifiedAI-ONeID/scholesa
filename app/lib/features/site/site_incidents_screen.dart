import 'package:flutter/material.dart';

class SiteIncidentsScreen extends StatelessWidget {
  const SiteIncidentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety & Incidents')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('Incident list and escalation (stub).'),
          SizedBox(height: 12),
          Text('Wire to IncidentReport collection per doc 41/42.'),
        ],
      ),
    );
  }
}
