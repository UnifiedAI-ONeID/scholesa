import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../auth/app_state.dart';

class ParentSummaryScreen extends StatefulWidget {
  const ParentSummaryScreen({super.key});

  @override
  State<ParentSummaryScreen> createState() => _ParentSummaryScreenState();
}

class _ParentSummaryScreenState extends State<ParentSummaryScreen> {
  late Future<List<AttendanceRecordModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AttendanceRecordModel>> _load() async {
    final siteId = context.read<AppState>().primarySiteId ?? '';
    if (siteId.isEmpty) return <AttendanceRecordModel>[];
    return AttendanceRepository().listRecentBySite(siteId, limit: 50);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Child Summary')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<AttendanceRecordModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final records = snapshot.data ?? <AttendanceRecordModel>[];
            if (records.isEmpty) {
              return const Center(child: Text('No recent attendance records.'));
            }
            // Simple parent-safe rollup: count statuses.
            final counts = <String, int>{};
            for (final r in records) {
              final key = r.status.toUpperCase();
              counts[key] = (counts[key] ?? 0) + 1;
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Recent attendance (parent-safe)'),
                const SizedBox(height: 12),
                for (final entry in counts.entries)
                  ListTile(
                    leading: const Icon(Icons.checklist_rtl),
                    title: Text(entry.key),
                    trailing: Text(entry.value.toString()),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
