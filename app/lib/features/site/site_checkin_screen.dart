import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../auth/app_state.dart';

class SiteCheckInScreen extends StatefulWidget {
  const SiteCheckInScreen({super.key});

  @override
  State<SiteCheckInScreen> createState() => _SiteCheckInScreenState();
}

class _SiteCheckInScreenState extends State<SiteCheckInScreen> {
  late Future<List<EnrollmentModel>> _enrollmentsFuture;

  @override
  void initState() {
    super.initState();
    _enrollmentsFuture = _load();
  }

  Future<List<EnrollmentModel>> _load() async {
    final siteId = context.read<AppState>().primarySiteId ?? '';
    if (siteId.isEmpty) return <EnrollmentModel>[];
    return EnrollmentRepository().listBySite(siteId);
  }

  Future<void> _refresh() async {
    setState(() {
      _enrollmentsFuture = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check-in / Check-out')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<EnrollmentModel>>(
          future: _enrollmentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final enrollments = snapshot.data ?? <EnrollmentModel>[];
            if (enrollments.isEmpty) {
              return const Center(child: Text('No enrollments for this site.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: enrollments.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final e = enrollments[index];
                return ListTile(
                  leading: const Icon(Icons.qr_code_scanner),
                  title: Text('Learner ${e.learnerId}'),
                  subtitle: Text('Session ${e.sessionId}'),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      TextButton(onPressed: () => _check(context, e, 'CHECK_IN'), child: const Text('Check-in')),
                      TextButton(onPressed: () => _check(context, e, 'CHECK_OUT'), child: const Text('Check-out')),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _check(BuildContext context, EnrollmentModel e, String action) async {
    // TODO: replace with real SiteCheckInOut repository when schema is available.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$action recorded for ${e.learnerId} (demo)')));
  }
}
