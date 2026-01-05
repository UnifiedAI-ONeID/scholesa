import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/app_state.dart';
import '../auth/auth_service.dart';

const List<String> pillarChips = <String>['Future Skills', 'Leadership & Agency', 'Impact & Innovation'];

const Map<String, List<DashboardCard>> roleCards = <String, List<DashboardCard>>{
  'learner': <DashboardCard>[
    DashboardCard(
      title: 'Missions in progress',
      description: 'Track your active missions and submit reflections.',
      pillar: 'Future Skills',
    ),
    DashboardCard(
      title: 'Leadership moments',
      description: 'Log agency wins and peer collaborations.',
      pillar: 'Leadership & Agency',
    ),
    DashboardCard(
      title: 'Impact portfolio',
      description: 'Capture artifacts that evidence real-world impact.',
      pillar: 'Impact & Innovation',
    ),
  ],
  'educator': <DashboardCard>[
    DashboardCard(
      title: 'Today’s sessions',
      description: 'Review rosters and prep materials.',
      pillar: 'Future Skills',
    ),
    DashboardCard(
      title: 'Attendance + notes',
      description: 'Mark presence and add quick observations.',
      pillar: 'Leadership & Agency',
    ),
    DashboardCard(
      title: 'Mission reviews',
      description: 'Approve submissions and coach next steps.',
      pillar: 'Impact & Innovation',
    ),
  ],
  'parent': <DashboardCard>[
    DashboardCard(
      title: 'Learner updates',
      description: 'See weekly highlights and coach at home.',
      pillar: 'Leadership & Agency',
    ),
    DashboardCard(
      title: 'Portfolio gallery',
      description: 'Browse evidence and celebrate progress.',
      pillar: 'Impact & Innovation',
    ),
  ],
  'site': <DashboardCard>[
    DashboardCard(
      title: 'Site pulse',
      description: 'Attendance, staffing, and upcoming sessions.',
      pillar: 'Future Skills',
    ),
    DashboardCard(
      title: 'Team actions',
      description: 'Assign follow-ups and track blockers.',
      pillar: 'Leadership & Agency',
    ),
  ],
  'partner': <DashboardCard>[
    DashboardCard(
      title: 'Deliverables',
      description: 'Review contracts and submission deadlines.',
      pillar: 'Impact & Innovation',
    ),
  ],
  'hq': <DashboardCard>[
    DashboardCard(
      title: 'Network health',
      description: 'Cross-site KPIs and escalations.',
      pillar: 'Leadership & Agency',
    ),
    DashboardCard(
      title: 'Program insights',
      description: 'Mission performance and impact trends.',
      pillar: 'Impact & Innovation',
    ),
  ],
};

class RoleDashboard extends StatelessWidget {
  const RoleDashboard({super.key, required this.role});

  final String role;

  String get title {
    switch (role) {
      case 'learner':
        return 'Learner Dashboard';
      case 'educator':
        return 'Educator Dashboard';
      case 'parent':
        return 'Parent Dashboard';
      case 'site':
        return 'Site Lead Dashboard';
      case 'partner':
        return 'Partner Dashboard';
      case 'hq':
        return 'HQ Dashboard';
      default:
        return 'Dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currentRole = appState.role ?? role;
    final entitlements = appState.entitlements;
    if (FirebaseAuth.instance.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      });
    }
    if (!entitlements.contains(currentRole)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(context, '/roles', (route) => false);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              AuthService().signOut();
              appState.clearRole();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          )
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: pillarChips
                    .map(
                      (String label) => Chip(
                        label: Text(label),
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        labelStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              ...List<Widget>.from(
                (roleCards[currentRole] ?? roleCards['learner'] ?? <DashboardCard>[])
                    .map((DashboardCard card) => DashboardCardView(card: card)),
              ),
              const SizedBox(height: 12),
              DashboardDataList(role: currentRole, siteId: appState.primarySiteId),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardItem {
  const DashboardItem({required this.title, this.subtitle});

  final String title;
  final String? subtitle;
}

class DashboardDataList extends StatelessWidget {
  const DashboardDataList({super.key, required this.role, this.siteId});

  final String role;
  final String? siteId;

  @override
  Widget build(BuildContext context) {
    if (_siteScoped(role) && siteId == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No site selected. Ask your site lead to assign a site.'),
      );
    }
    return FutureBuilder<List<DashboardItem>>(
      future: _loadItems(role, siteId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final items = snapshot.data ?? const <DashboardItem>[];
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items
              .map(
                (DashboardItem item) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(item.title),
                    subtitle: item.subtitle != null ? Text(item.subtitle!) : null,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Future<List<DashboardItem>> _loadItems(String role, String? siteId) async {
    try {
      switch (role) {
        case 'educator':
          return _fetchCollection('sessions', siteId: siteId, titleField: 'title', subtitleField: 'pillarCodes');
        case 'learner':
          return _fetchCollection('missions', titleField: 'title', subtitleField: 'pillarCodes');
        case 'parent':
          return _fetchCollection('portfolioItems', titleField: 'title', subtitleField: 'description');
        case 'site':
          return _fetchCollection('sessions', siteId: siteId, titleField: 'title', subtitleField: 'startDate');
        case 'partner':
          return _fetchCollection('contracts', titleField: 'title', subtitleField: 'status');
        case 'hq':
          return _fetchCollection('missions', titleField: 'title', subtitleField: 'difficulty');
        default:
          return _fetchCollection('missions', titleField: 'title', subtitleField: 'pillarCodes');
      }
    } catch (_) {
      return _fallbackItems(role);
    }
  }

  Future<List<DashboardItem>> _fetchCollection(
    String collection, {
    String? siteId,
    required String titleField,
    String? subtitleField,
  }) async {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(collection).limit(3);
    if (siteId != null) {
      query = query.where('siteId', isEqualTo: siteId);
    }
    final snap = await query.get();
    if (snap.docs.isEmpty) return _fallbackItems(role);
    return snap.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final data = doc.data();
      final title = (data[titleField] as String?) ?? 'Untitled';
      final subtitleValue = data[subtitleField];
      final subtitle = _formatSubtitle(subtitleValue);
      return DashboardItem(title: title, subtitle: subtitle);
    }).toList();
  }

  List<DashboardItem> _fallbackItems(String role) {
    final base = <DashboardItem>[
      DashboardItem(title: 'Getting started', subtitle: 'No records yet. Create your first item.'),
    ];
    switch (role) {
      case 'educator':
        return <DashboardItem>[...base, const DashboardItem(title: 'Create a session roster', subtitle: 'Add learners to today’s class')];
      case 'learner':
        return <DashboardItem>[...base, const DashboardItem(title: 'Pick a mission', subtitle: 'Start with a Future Skills challenge')];
      case 'parent':
        return <DashboardItem>[...base, const DashboardItem(title: 'Link to your learner', subtitle: 'Request access from the site lead')];
      case 'site':
        return <DashboardItem>[...base, const DashboardItem(title: 'Review attendance', subtitle: 'Monitor daily presence')];
      case 'partner':
        return <DashboardItem>[...base, const DashboardItem(title: 'Submit deliverables', subtitle: 'Upload artifacts for review')];
      case 'hq':
        return <DashboardItem>[...base, const DashboardItem(title: 'Monitor KPIs', subtitle: 'Check network health')];
      default:
        return base;
    }
  }

  String? _formatSubtitle(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.whereType<String>().join(' • ');
    }
    if (value is String) return value;
    if (value is num) return value.toString();
    return null;
  }

  bool _siteScoped(String role) => role == 'educator' || role == 'site';
}

class DashboardCard {
  const DashboardCard({required this.title, required this.description, required this.pillar});

  final String title;
  final String description;
  final String pillar;
}

class DashboardCardView extends StatelessWidget {
  const DashboardCardView({super.key, required this.card});

  final DashboardCard card;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(card.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(card.description),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                card.pillar,
                style: TextStyle(color: scheme.onSecondaryContainer, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
