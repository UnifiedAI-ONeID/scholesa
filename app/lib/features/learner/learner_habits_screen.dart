import 'package:flutter/material.dart';

class LearnerHabitsScreen extends StatelessWidget {
  const LearnerHabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Habit Coach')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('Habit do-now and reflections (stub).'),
          SizedBox(height: 12),
          Text('Wire to habit engine + telemetry per docs 21/22.'),
        ],
      ),
    );
  }
}
