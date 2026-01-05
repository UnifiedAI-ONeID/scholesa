import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/repositories.dart';
import '../../domain/models.dart';
import '../auth/app_state.dart';
import '../auth/auth_service.dart';
import '../offline/offline_actions.dart';
import '../offline/offline_queue.dart';
import '../offline/offline_service.dart';

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
    final queue = context.watch<OfflineQueue>();
    final offline = context.watch<OfflineService>();
    final currentRole = appState.role ?? role;
    final entitlements = appState.entitlements;
    final siteIds = appState.siteIds;
    final String? activeSiteId = appState.primarySiteId ?? (siteIds.isNotEmpty ? siteIds.first : null);
    final isSiteScoped = currentRole == 'educator' || currentRole == 'site';
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B1224), Color(0xFF0F172A), Color(0xFF0B1224)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Aligned to Future Skills, Leadership & Agency, Impact & Innovation.',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white70),
                        onPressed: () {
                          AuthService().signOut();
                          appState.clearRole();
                          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _OfflineQueueCard(queue: queue, offline: offline),
                  if (currentRole == 'learner' && activeSiteId != null) ...[
                    const SizedBox(height: 12),
                    _MissionAttemptForm(queue: queue, siteId: activeSiteId, appState: appState),
                    const SizedBox(height: 12),
                    _MissionListCard(siteId: activeSiteId, learnerId: appState.user?.uid),
                    const SizedBox(height: 12),
                    _PortfolioItemForm(queue: queue, siteId: activeSiteId, appState: appState),
                  ],
                  if ((currentRole == 'educator' || currentRole == 'site') && activeSiteId != null) ...[
                    const SizedBox(height: 12),
                    _AttendanceForm(queue: queue, siteId: activeSiteId, appState: appState),
                  ],
                  if (currentRole == 'parent' && activeSiteId != null) ...[
                    const SizedBox(height: 12),
                      _AttendanceForm(queue: queue, siteId: activeSiteId, appState: appState),
                      const SizedBox(height: 12),
                      _AttendanceDemoCard(queue: queue, siteId: activeSiteId),
                      const SizedBox(height: 12),
                      _ParentSummaryCard(appState: appState, siteId: activeSiteId),
                  ],
                  if ((currentRole == 'site' || currentRole == 'hq') && activeSiteId != null) ...[
                    const SizedBox(height: 12),
                    _AdminProvisioningCard(siteId: activeSiteId, appState: appState),
                  ],
                  if (currentRole == 'site' && activeSiteId != null) ...[
                    const SizedBox(height: 12),
                    _SiteSessionForm(siteId: activeSiteId, appState: appState),
                  ],
                  if (currentRole == 'partner') ...[
                    const SizedBox(height: 12),
                    _PartnerDeliverableForm(appState: appState),
                  ],
                  if (currentRole == 'hq') ...[
                    const SizedBox(height: 12),
                    _HqKpiForm(appState: appState),
                  ],
                  if ((currentRole == 'educator' || currentRole == 'site') && activeSiteId != null) ...[
                    const SizedBox(height: 12),
                    _AttendanceDemoCard(queue: queue, siteId: activeSiteId),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF38BDF8), Color(0xFF6366F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 12))],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active role',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                title,
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isSiteScoped && activeSiteId != null
                                    ? 'Site scoped • $activeSiteId'
                                    : 'Multi-role ready',
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Column(
                            children: [
                              const Text('Pillars', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  _Dot(color: Color(0xFF38BDF8)),
                                  SizedBox(width: 6),
                                  _Dot(color: Color(0xFFF59E0B)),
                                  SizedBox(width: 6),
                                  _Dot(color: Color(0xFF22C55E)),
                                ],
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isSiteScoped)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Active site', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          if (siteIds.isEmpty)
                            const Text('No sites assigned. Ask your site lead to add you to a site.', style: TextStyle(color: Colors.white70))
                          else
                            DropdownButtonFormField<String>(
                              initialValue: activeSiteId,
                              dropdownColor: const Color(0xFF0F172A),
                              iconEnabledColor: Colors.white,
                              items: siteIds
                                  .map(
                                    (String id) => DropdownMenuItem<String>(
                                      value: id,
                                      child: Text(id, style: const TextStyle(color: Colors.white)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (String? value) => context.read<AppState>().setPrimarySite(value),
                              decoration: InputDecoration(
                                labelText: 'Site',
                                labelStyle: const TextStyle(color: Colors.white70),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.05),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.white24),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                                ),
                              ),
                              style: const TextStyle(color: Colors.white),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: pillarChips
                        .map(
                          (String label) => Chip(
                            label: Text(label),
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white24)),
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
                  DashboardDataList(role: currentRole, siteId: activeSiteId),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineQueueCard extends StatelessWidget {
  const _OfflineQueueCard({required this.queue, required this.offline});

  final OfflineQueue queue;
  final OfflineService offline;

  @override
  Widget build(BuildContext context) {
    final isOffline = offline.isOffline;
    final pendingCount = queue.pending.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 12)),
        ],
        gradient: const LinearGradient(
          colors: [Color(0xFF0B1224), Color(0xFF111827)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isOffline ? const [Color(0xFFef4444), Color(0xFFb91c1c)] : const [Color(0xFF22c55e), Color(0xFF16a34a)],
                  ),
                ),
                child: Icon(isOffline ? Icons.wifi_off : Icons.cloud_done, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Offline sync', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(
                    isOffline
                        ? 'You are offline. Actions queue safely.'
                        : 'Online. Queued actions will flush.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
              const Spacer(),
              Chip(
                label: Text('$pendingCount queued', style: const TextStyle(color: Colors.white)),
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                shape: StadiumBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Log an action even when offline; we will sync the moment you reconnect. Use this to demo the queue while data wiring is in progress.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 8,
              ),
              onPressed: () async {
                await OfflineActions.queueMissionAttempt(
                  queue,
                  missionId: 'demo-mission',
                  siteId: 'demo-site',
                  learnerId: FirebaseAuth.instance.currentUser?.uid ?? 'demo',
                  status: 'started',
                );
                if (!isOffline) await queue.flush(online: true);
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isOffline ? 'Queued mission attempt for sync.' : 'Sent mission attempt (or queued if offline).'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: const Color(0xFF0EA5E9),
                  ),
                );
              },
              child: Text(isOffline ? 'Queue mission attempt' : 'Send mission attempt'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionAttemptForm extends StatefulWidget {
  const _MissionAttemptForm({required this.queue, required this.siteId, required this.appState});

  final OfflineQueue queue;
  final String siteId;
  final AppState appState;

  @override
  State<_MissionAttemptForm> createState() => _MissionAttemptFormState();
}

class _MissionAttemptFormState extends State<_MissionAttemptForm> {
  final TextEditingController _missionId = TextEditingController();
  final TextEditingController _reflection = TextEditingController();
  final TextEditingController _artifactUrl = TextEditingController();
  final TextEditingController _sessionOccurrenceId = TextEditingController();
  final TextEditingController _pillarCodes = TextEditingController(text: 'FUTURE_SKILLS,LEADERSHIP_AGENCY,IMPACT_INNOVATION');

  @override
  void dispose() {
    _missionId.dispose();
    _reflection.dispose();
    _artifactUrl.dispose();
    _sessionOccurrenceId.dispose();
    _pillarCodes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = context.watch<OfflineService>().isOffline;
    final learnerId = widget.appState.user?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    final role = widget.appState.role ?? 'learner';
    return _GlassCard(
      title: 'Submit mission attempt',
      subtitle: 'Queues with site + learner + pillars; syncs when online.',
      child: Column(
        children: [
          _TextField(controller: _missionId, label: 'Mission ID', hint: 'mission-123'),
          const SizedBox(height: 8),
          _TextField(controller: _sessionOccurrenceId, label: 'Session occurrence (optional)', hint: 'session-occ-123'),
          const SizedBox(height: 8),
          _TextField(controller: _pillarCodes, label: 'Pillar codes (comma separated)', hint: 'FUTURE_SKILLS'),
          const SizedBox(height: 8),
          _TextField(controller: _artifactUrl, label: 'Artifact URL (optional)', hint: 'https://...'),
          const SizedBox(height: 8),
          _TextField(controller: _reflection, label: 'Reflection', hint: 'What did you learn?'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(isOffline ? Icons.cloud_off : Icons.cloud_upload, color: Colors.white),
              label: Text(isOffline ? 'Queue mission attempt' : 'Submit mission attempt'),
              onPressed: () async {
                final missionId = _missionId.text.trim();
                if (missionId.isEmpty) {
                  _toast(context, 'Mission ID is required');
                  return;
                }
                if (learnerId == null) {
                  _toast(context, 'Sign in to submit mission attempts');
                  return;
                }
                await OfflineActions.queueMissionAttempt(
                  widget.queue,
                  missionId: missionId,
                  siteId: widget.siteId,
                  learnerId: learnerId,
                  reflection: _reflection.text.trim().isEmpty ? null : _reflection.text.trim(),
                  pillarCodes: _splitCodes(_pillarCodes.text),
                  artifactUrls: _splitCodes(_artifactUrl.text),
                  sessionOccurrenceId: _sessionOccurrenceId.text.trim().isEmpty ? null : _sessionOccurrenceId.text.trim(),
                  actorRole: role,
                );
                if (!context.mounted) return;
                if (!isOffline) await widget.queue.flush(online: true);
                if (!context.mounted) return;
                _toast(context, isOffline ? 'Queued mission attempt for sync' : 'Mission attempt submitted');
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PortfolioItemForm extends StatefulWidget {
  const _PortfolioItemForm({required this.queue, required this.siteId, required this.appState});

  final OfflineQueue queue;
  final String siteId;
  final AppState appState;

  @override
  State<_PortfolioItemForm> createState() => _PortfolioItemFormState();
}

class _PortfolioItemFormState extends State<_PortfolioItemForm> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _missionId = TextEditingController();
  final TextEditingController _pillarCodes = TextEditingController(text: 'FUTURE_SKILLS');
  final TextEditingController _artifactUrl = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _missionId.dispose();
    _pillarCodes.dispose();
    _artifactUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = context.watch<OfflineService>().isOffline;
    final learnerId = widget.appState.user?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    final role = widget.appState.role ?? 'learner';
    return _GlassCard(
      title: 'Add portfolio evidence',
      subtitle: 'Logs an item tied to pillars and site scope.',
      child: Column(
        children: [
          _TextField(controller: _title, label: 'Title', hint: 'Robotics demo'),
          const SizedBox(height: 8),
          _TextField(controller: _description, label: 'Description', hint: 'What was built or learned?'),
          const SizedBox(height: 8),
          _TextField(controller: _pillarCodes, label: 'Pillar codes (comma separated)', hint: 'FUTURE_SKILLS'),
          const SizedBox(height: 8),
          _TextField(controller: _missionId, label: 'Mission ID (optional)', hint: 'mission-123'),
          const SizedBox(height: 8),
          _TextField(controller: _artifactUrl, label: 'Artifact URL (optional)', hint: 'https://...'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(isOffline ? Icons.cloud_off : Icons.cloud_upload, color: Colors.white),
              label: Text(isOffline ? 'Queue portfolio item' : 'Save portfolio item'),
              onPressed: () async {
                final title = _title.text.trim();
                if (title.isEmpty) {
                  _toast(context, 'Title is required');
                  return;
                }
                if (learnerId == null) {
                  _toast(context, 'Sign in to save portfolio items');
                  return;
                }
                await OfflineActions.queuePortfolioItem(
                  widget.queue,
                  siteId: widget.siteId,
                  learnerId: learnerId,
                  title: title,
                  description: _description.text.trim().isEmpty ? null : _description.text.trim(),
                  pillarCodes: _splitCodes(_pillarCodes.text),
                  missionId: _missionId.text.trim().isEmpty ? null : _missionId.text.trim(),
                  url: _artifactUrl.text.trim().isEmpty ? null : _artifactUrl.text.trim(),
                  actorRole: role,
                );
                if (!context.mounted) return;
                if (!isOffline) await widget.queue.flush(online: true);
                if (!context.mounted) return;
                _toast(context, isOffline ? 'Queued portfolio item for sync' : 'Portfolio item saved');
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceForm extends StatefulWidget {
  const _AttendanceForm({required this.queue, required this.siteId, required this.appState});

  final OfflineQueue queue;
  final String siteId;
  final AppState appState;

  @override
  State<_AttendanceForm> createState() => _AttendanceFormState();
}

class _AttendanceFormState extends State<_AttendanceForm> {
  final TextEditingController _sessionOccurrenceId = TextEditingController();
  final TextEditingController _learnerId = TextEditingController();
  final TextEditingController _note = TextEditingController();
  String _status = 'present';
  List<SessionOccurrenceModel> _occurrences = <SessionOccurrenceModel>[];
  List<AttendanceRecordModel> _recent = <AttendanceRecordModel>[];
  List<EnrollmentModel> _enrollments = <EnrollmentModel>[];
  bool _loadingRefs = false;
  String? _selectedOccurrenceId;

  @override
  void dispose() {
    _sessionOccurrenceId.dispose();
    _learnerId.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadRefs();
  }

  Future<void> _loadRefs() async {
    setState(() => _loadingRefs = true);
    final occRepo = SessionOccurrenceRepository();
    final attRepo = AttendanceRepository();
    final enrRepo = EnrollmentRepository();
    final occs = await occRepo.listBySite(widget.siteId);
    final recent = await attRepo.listBySite(widget.siteId);
    final enrollments = await enrRepo.listBySite(widget.siteId);
    if (!mounted) return;
    setState(() {
      _occurrences = occs;
      _recent = recent;
      _enrollments = enrollments;
      _selectedOccurrenceId ??= _occurrences.isNotEmpty ? _occurrences.first.id : null;
      if (_sessionOccurrenceId.text.isEmpty && _selectedOccurrenceId != null) {
        _sessionOccurrenceId.text = _selectedOccurrenceId!;
      }
      _loadingRefs = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = context.watch<OfflineService>().isOffline;
    final recordedBy = widget.appState.user?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    final role = widget.appState.role ?? 'educator';
    return _GlassCard(
      title: 'Mark attendance (site scoped)',
      subtitle: 'Deterministic doc IDs per occurrence + learner; queues offline.',
      child: Column(
        children: [
          _TextField(controller: _sessionOccurrenceId, label: 'Session occurrence ID', hint: 'occ-2024-10-01-A'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedOccurrenceId ?? (_occurrences.isNotEmpty ? _occurrences.first.id : null),
            decoration: _inputDecoration('Pick session occurrence'),
            dropdownColor: const Color(0xFF0F172A),
            items: _occurrences
                .map((o) => DropdownMenuItem(
                      value: o.id,
                      child: Text('${o.id} • ${o.date}', style: const TextStyle(color: Colors.white)),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedOccurrenceId = value;
                  _sessionOccurrenceId.text = value;
                });
              }
            },
          ),
          const SizedBox(height: 8),
          _TextField(controller: _learnerId, label: 'Learner ID', hint: 'uid of learner'),
          const SizedBox(height: 8),
          _AttendanceRoster(
            occurrences: _occurrences,
            enrollments: _enrollments,
            selectedOccurrenceId: _selectedOccurrenceId,
            onSelectLearner: (id) {
              setState(() => _learnerId.text = id);
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _status,
            dropdownColor: const Color(0xFF0F172A),
            decoration: _inputDecoration('Status'),
            items: const [
              DropdownMenuItem(value: 'present', child: Text('Present')),
              DropdownMenuItem(value: 'absent', child: Text('Absent')),
              DropdownMenuItem(value: 'late', child: Text('Late')),
            ],
            onChanged: (value) => setState(() => _status = value ?? 'present'),
          ),
          const SizedBox(height: 8),
          _TextField(controller: _note, label: 'Note (optional)', hint: 'Observation'),
          const SizedBox(height: 12),
          if (_loadingRefs)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Loading references...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(isOffline ? Icons.cloud_off : Icons.cloud_upload, color: Colors.white),
              label: Text(isOffline ? 'Queue attendance' : 'Save attendance'),
              onPressed: () async {
                final sessionOccurrenceId = _sessionOccurrenceId.text.trim();
                final learnerId = _learnerId.text.trim();
                if (sessionOccurrenceId.isEmpty || learnerId.isEmpty) {
                  _toast(context, 'Session occurrence and learner are required');
                  return;
                }
                if (recordedBy == null) {
                  _toast(context, 'Sign in to record attendance');
                  return;
                }
                await OfflineActions.queueAttendance(
                  widget.queue,
                  sessionOccurrenceId: sessionOccurrenceId,
                  siteId: widget.siteId,
                  learnerId: learnerId,
                  recordedBy: recordedBy,
                  status: _status,
                  note: _note.text.trim().isNotEmpty ? _note.text.trim() : null,
                  actorRole: role,
                );
                if (!context.mounted) return;
                if (!isOffline) await widget.queue.flush(online: true);
                if (!context.mounted) return;
                _toast(context, isOffline ? 'Queued attendance for sync' : 'Attendance saved');
                _loadRefs();
              },
            ),
          ),
          _AttendanceRecentList(records: _recent.take(10).toList()),
        ],
      ),
    );
  }
}

class _AttendanceRecentList extends StatelessWidget {
  const _AttendanceRecentList({required this.records});

  final List<AttendanceRecordModel> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        const Text('Recent attendance', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: records.length,
            separatorBuilder: (_, unused) => const Divider(color: Colors.white10, height: 1),
            itemBuilder: (context, index) {
              final r = records[index];
              return ListTile(
                dense: true,
                title: Text('${r.sessionOccurrenceId} • ${r.learnerId}', style: const TextStyle(color: Colors.white)),
                subtitle: Text('Status: ${r.status}${r.note != null ? ' • ${r.note}' : ''}', style: const TextStyle(color: Colors.white70)),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AttendanceRoster extends StatelessWidget {
  const _AttendanceRoster({
    required this.occurrences,
    required this.enrollments,
    required this.selectedOccurrenceId,
    required this.onSelectLearner,
  });

  final List<SessionOccurrenceModel> occurrences;
  final List<EnrollmentModel> enrollments;
  final String? selectedOccurrenceId;
  final ValueChanged<String> onSelectLearner;

  @override
  Widget build(BuildContext context) {
    if (selectedOccurrenceId == null) return const SizedBox.shrink();
    final occ = occurrences.firstWhere(
      (o) => o.id == selectedOccurrenceId,
      orElse: () => SessionOccurrenceModel(
        id: '',
        sessionId: '',
        siteId: '',
        date: '',
        startAt: Timestamp.now(),
        endAt: Timestamp.now(),
      ),
    );
    if (occ.id.isEmpty) return const SizedBox.shrink();
    final roster = enrollments.where((e) => e.sessionId == occ.sessionId).toList();
    if (roster.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Roster for ${occ.sessionId} (${occ.date})', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: roster.length,
            separatorBuilder: (_, unused) => const Divider(color: Colors.white10, height: 1),
            itemBuilder: (context, index) {
              final enrollment = roster[index];
              return ListTile(
                dense: true,
                title: Text(enrollment.learnerId, style: const TextStyle(color: Colors.white)),
                trailing: TextButton(
                  onPressed: () => onSelectLearner(enrollment.learnerId),
                  child: const Text('Select', style: TextStyle(color: Colors.white70)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AttendanceDemoCard extends StatelessWidget {
  const _AttendanceDemoCard({required this.queue, required this.siteId});

  final OfflineQueue queue;
  final String siteId;

  @override
  Widget build(BuildContext context) {
    final isOffline = context.watch<OfflineService>().isOffline;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 12))],
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF111827)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF6366F1)]),
                ),
                child: const Icon(Icons.event_available, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Attendance (demo)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  Text('Queue a mark and sync on reconnect.', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Site: $siteId', style: TextStyle(color: Colors.white.withValues(alpha: 0.75))),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFF22c55e),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 8,
              ),
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                await OfflineActions.queueAttendance(
                  queue,
                  sessionOccurrenceId: 'demo-occurrence',
                  siteId: siteId,
                  learnerId: user?.uid ?? 'demo-learner',
                  recordedBy: user?.uid ?? 'demo-educator',
                  status: 'present',
                  actorRole: 'educator',
                  note: 'demo button',
                );
                if (!isOffline) await queue.flush(online: true);
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isOffline ? 'Queued attendance mark for sync.' : 'Attendance marked (or queued).'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: const Color(0xFF16a34a),
                  ),
                );
              },
              child: Text(isOffline ? 'Queue attendance (demo)' : 'Mark attendance (demo)'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminProvisioningCard extends StatefulWidget {
  const _AdminProvisioningCard({required this.siteId, required this.appState});

  final String siteId;
  final AppState appState;

  @override
  State<_AdminProvisioningCard> createState() => _AdminProvisioningCardState();
}

class _AdminProvisioningCardState extends State<_AdminProvisioningCard> {
  final TextEditingController _learnerId = TextEditingController();
  final TextEditingController _learnerEmail = TextEditingController();
  final TextEditingController _learnerName = TextEditingController();
  final TextEditingController _learnerPreferred = TextEditingController();
  final TextEditingController _learnerGrade = TextEditingController();
  final TextEditingController _learnerDob = TextEditingController();

  final TextEditingController _parentId = TextEditingController();
  final TextEditingController _parentEmail = TextEditingController();
  final TextEditingController _parentName = TextEditingController();
  final TextEditingController _parentPhone = TextEditingController();
  final TextEditingController _parentLang = TextEditingController();

  final TextEditingController _linkParentId = TextEditingController();
  final TextEditingController _linkLearnerId = TextEditingController();
  String _relationship = 'guardian';
  bool _isPrimary = true;

  bool _busy = false;

  @override
  void dispose() {
    _learnerId.dispose();
    _learnerEmail.dispose();
    _learnerName.dispose();
    _learnerPreferred.dispose();
    _learnerGrade.dispose();
    _learnerDob.dispose();
    _parentId.dispose();
    _parentEmail.dispose();
    _parentName.dispose();
    _parentPhone.dispose();
    _parentLang.dispose();
    _linkParentId.dispose();
    _linkLearnerId.dispose();
    super.dispose();
  }

  Future<void> _createLearner() async {
    if (_busy) return;
    final learnerId = _learnerId.text.trim();
    final email = _learnerEmail.text.trim();
    if (learnerId.isEmpty || email.isEmpty) {
      _toast(context, 'Learner ID and email are required');
      return;
    }
    final actorId = widget.appState.user?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (actorId == null) {
      _toast(context, 'Sign in required');
      return;
    }
    setState(() => _busy = true);
    try {
      final userRepo = UserRepository();
      final learnerRepo = LearnerProfileRepository();
      final auditRepo = AuditLogRepository();
      final now = Timestamp.now();
      await userRepo.upsert(
        UserModel(
          id: learnerId,
          email: email,
          role: 'learner',
          displayName: _learnerPreferred.text.trim().isNotEmpty ? _learnerPreferred.text.trim() : _learnerName.text.trim(),
          siteIds: <String>[widget.siteId],
          activeSiteId: widget.siteId,
          provisionedBy: actorId,
          provisionedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await learnerRepo.upsert(
        LearnerProfileModel(
          id: 'lp-$learnerId',
          learnerId: learnerId,
          siteId: widget.siteId,
          legalName: _learnerName.text.trim().isEmpty ? null : _learnerName.text.trim(),
          preferredName: _learnerPreferred.text.trim().isEmpty ? null : _learnerPreferred.text.trim(),
          dateOfBirth: _learnerDob.text.trim().isEmpty ? null : _learnerDob.text.trim(),
          gradeLevel: _learnerGrade.text.trim().isEmpty ? null : _learnerGrade.text.trim(),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await auditRepo.log(
        AuditLogModel(
          id: 'audit-learner-$learnerId-${now.millisecondsSinceEpoch}',
          actorId: actorId,
          actorRole: widget.appState.role ?? 'site',
          action: 'learner.provision',
          entityType: 'learnerProfile',
          entityId: 'lp-$learnerId',
          siteId: widget.siteId,
          details: <String, dynamic>{'learnerId': learnerId, 'email': email},
          createdAt: Timestamp.now(),
        ),
      );
      if (!mounted) return;
      _toast(context, 'Learner provisioned');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createParent() async {
    if (_busy) return;
    final parentId = _parentId.text.trim();
    final email = _parentEmail.text.trim();
    if (parentId.isEmpty || email.isEmpty) {
      _toast(context, 'Parent ID and email are required');
      return;
    }
    final actorId = widget.appState.user?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (actorId == null) {
      _toast(context, 'Sign in required');
      return;
    }
    setState(() => _busy = true);
    try {
      final userRepo = UserRepository();
      final parentRepo = ParentProfileRepository();
      final auditRepo = AuditLogRepository();
      final now = Timestamp.now();
      await userRepo.upsert(
        UserModel(
          id: parentId,
          email: email,
          role: 'parent',
          displayName: _parentName.text.trim().isEmpty ? null : _parentName.text.trim(),
          siteIds: <String>[widget.siteId],
          activeSiteId: widget.siteId,
          provisionedBy: actorId,
          provisionedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await parentRepo.upsert(
        ParentProfileModel(
          id: 'pp-$parentId',
          parentId: parentId,
          siteId: widget.siteId,
          legalName: _parentName.text.trim().isEmpty ? null : _parentName.text.trim(),
          preferredName: _parentName.text.trim().isEmpty ? null : _parentName.text.trim(),
          phone: _parentPhone.text.trim().isEmpty ? null : _parentPhone.text.trim(),
          preferredLanguage: _parentLang.text.trim().isEmpty ? null : _parentLang.text.trim(),
          communicationPreferences: const <String>['email'],
          createdAt: now,
          updatedAt: now,
        ),
      );
      await auditRepo.log(
        AuditLogModel(
          id: 'audit-parent-$parentId-${now.millisecondsSinceEpoch}',
          actorId: actorId,
          actorRole: widget.appState.role ?? 'site',
          action: 'parent.provision',
          entityType: 'parentProfile',
          entityId: 'pp-$parentId',
          siteId: widget.siteId,
          details: <String, dynamic>{'parentId': parentId, 'email': email},
          createdAt: Timestamp.now(),
        ),
      );
      if (!mounted) return;
      _toast(context, 'Parent provisioned');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _linkGuardian() async {
    if (_busy) return;
    final parentId = _linkParentId.text.trim();
    final learnerId = _linkLearnerId.text.trim();
    if (parentId.isEmpty || learnerId.isEmpty) {
      _toast(context, 'Parent ID and learner ID are required');
      return;
    }
    final actorId = widget.appState.user?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (actorId == null) {
      _toast(context, 'Sign in required');
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = GuardianLinkRepository();
      final auditRepo = AuditLogRepository();
      final now = Timestamp.now();
      final linkId = 'gl-$parentId-$learnerId';
      await repo.upsert(
        GuardianLinkModel(
          id: linkId,
          parentId: parentId,
          learnerId: learnerId,
          siteId: widget.siteId,
          relationship: _relationship,
          isPrimary: _isPrimary,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await auditRepo.log(
        AuditLogModel(
          id: 'audit-guardian-$linkId-${now.millisecondsSinceEpoch}',
          actorId: actorId,
          actorRole: widget.appState.role ?? 'site',
          action: 'guardian.link',
          entityType: 'guardianLink',
          entityId: linkId,
          siteId: widget.siteId,
          details: <String, dynamic>{'parentId': parentId, 'learnerId': learnerId, 'relationship': _relationship},
          createdAt: Timestamp.now(),
        ),
      );
      if (!mounted) return;
      _toast(context, 'Guardian link saved');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      title: 'Admin provisioning',
      subtitle: 'HQ/Site can create learners, parents, and guardian links (site scoped).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Create learner', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _TextField(controller: _learnerId, label: 'Learner ID', hint: 'uid'),
          const SizedBox(height: 8),
          _TextField(controller: _learnerEmail, label: 'Learner email', hint: 'learner@example.com'),
          const SizedBox(height: 8),
          _TextField(controller: _learnerName, label: 'Legal name', hint: 'Full name'),
          const SizedBox(height: 8),
          _TextField(controller: _learnerPreferred, label: 'Preferred name (optional)', hint: 'Nickname'),
          const SizedBox(height: 8),
          _TextField(controller: _learnerGrade, label: 'Grade level (optional)', hint: 'Grade'),
          const SizedBox(height: 8),
          _TextField(controller: _learnerDob, label: 'Date of birth (YYYY-MM-DD)', hint: '2009-06-01'),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _createLearner,
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: Text(_busy ? 'Working...' : 'Create learner'),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          const Text('Create parent', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _TextField(controller: _parentId, label: 'Parent ID', hint: 'uid'),
          const SizedBox(height: 8),
          _TextField(controller: _parentEmail, label: 'Parent email', hint: 'parent@example.com'),
          const SizedBox(height: 8),
          _TextField(controller: _parentName, label: 'Name', hint: 'Legal name'),
          const SizedBox(height: 8),
          _TextField(controller: _parentPhone, label: 'Phone (optional)', hint: '+1...'),
          const SizedBox(height: 8),
          _TextField(controller: _parentLang, label: 'Preferred language (optional)', hint: 'en'),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _createParent,
              icon: const Icon(Icons.family_restroom, color: Colors.white),
              label: Text(_busy ? 'Working...' : 'Create parent'),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          const Text('Link parent to learner', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _TextField(controller: _linkParentId, label: 'Parent ID', hint: 'parent uid'),
          const SizedBox(height: 8),
          _TextField(controller: _linkLearnerId, label: 'Learner ID', hint: 'learner uid'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _relationship,
            dropdownColor: const Color(0xFF0F172A),
            decoration: _inputDecoration('Relationship'),
            items: const [
              DropdownMenuItem(value: 'mother', child: Text('Mother')),
              DropdownMenuItem(value: 'father', child: Text('Father')),
              DropdownMenuItem(value: 'guardian', child: Text('Guardian')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (value) => setState(() => _relationship = value ?? 'guardian'),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _isPrimary,
            onChanged: (value) => setState(() => _isPrimary = value),
            title: const Text('Primary guardian', style: TextStyle(color: Colors.white70)),
            contentPadding: EdgeInsets.zero,
            activeTrackColor: const Color(0xFF38BDF8),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _linkGuardian,
              icon: const Icon(Icons.link, color: Colors.white),
              label: Text(_busy ? 'Working...' : 'Link guardian'),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          _ProvisionedList(
            title: 'Learners at this site',
            stream: FirebaseFirestore.instance
                .collection('learnerProfiles')
                .where('siteId', isEqualTo: widget.siteId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            itemBuilder: (data) {
              final name = (data['preferredName'] ?? data['legalName'] ?? '') as String?;
              return '${data['learnerId'] ?? ''}${name != null && name.isNotEmpty ? ' • $name' : ''}';
            },
          ),
          const SizedBox(height: 12),
          _ProvisionedList(
            title: 'Parents at this site',
            stream: FirebaseFirestore.instance
                .collection('parentProfiles')
                .where('siteId', isEqualTo: widget.siteId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            itemBuilder: (data) {
              final name = (data['preferredName'] ?? data['legalName'] ?? '') as String?;
              return '${data['parentId'] ?? ''}${name != null && name.isNotEmpty ? ' • $name' : ''}';
            },
          ),
          const SizedBox(height: 12),
          _ProvisionedList(
            title: 'Guardian links',
            stream: FirebaseFirestore.instance
                .collection('guardianLinks')
                .where('siteId', isEqualTo: widget.siteId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            itemBuilder: (data) {
              final rel = data['relationship'] as String?;
              final primary = data['isPrimary'] == true ? ' (primary)' : '';
              return '${data['parentId'] ?? ''} → ${data['learnerId'] ?? ''}${rel != null ? ' • $rel' : ''}$primary';
            },
          ),
        ],
      ),
    );
  }
}

class _ProvisionedList extends StatelessWidget {
  const _ProvisionedList({required this.title, required this.stream, required this.itemBuilder});

  final String title;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String Function(Map<String, dynamic>) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text('Loading...', style: TextStyle(color: Colors.white70))]),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Error loading $title', style: const TextStyle(color: Colors.redAccent)),
                );
              }
              final docs = snapshot.data?.docs ?? const [];
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('No records yet', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final data = docs[index].data();
                  return ListTile(
                    dense: true,
                    title: Text(itemBuilder(data), style: const TextStyle(color: Colors.white)),
                  );
                },
                separatorBuilder: (_, unused) => const Divider(color: Colors.white10, height: 1),
                itemCount: docs.length,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ParentSummaryCard extends StatefulWidget {
  const _ParentSummaryCard({required this.appState, this.siteId});

  final AppState appState;
  final String? siteId;

  @override
  State<_ParentSummaryCard> createState() => _ParentSummaryCardState();
}

class _MissionListCard extends StatefulWidget {
  const _MissionListCard({required this.siteId, required this.learnerId});

  final String siteId;
  final String? learnerId;

  @override
  State<_MissionListCard> createState() => _MissionListCardState();
}

class _MissionListCardState extends State<_MissionListCard> {
  List<MissionModel> _missions = <MissionModel>[];
  List<MissionAttemptModel> _attempts = <MissionAttemptModel>[];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final missions = await _fetchMissions();
      final attempts = await _fetchAttempts();
      if (!mounted) return;
      setState(() {
        _missions = missions;
        _attempts = attempts;
        _loading = false;
      });
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  Future<List<MissionModel>> _fetchMissions() async {
    final missions = <MissionModel>[];
    final siteSnap = await FirebaseFirestore.instance
        .collection('missions')
        .where('siteId', isEqualTo: widget.siteId)
        .get();
    missions.addAll(siteSnap.docs.map(MissionModel.fromDoc));
    final globalSnap = await FirebaseFirestore.instance
        .collection('missions')
        .where('siteId', isNull: true)
        .get();
    missions.addAll(globalSnap.docs.map(MissionModel.fromDoc));
    final seen = <String>{};
    final deduped = <MissionModel>[];
    for (final m in missions) {
      if (seen.add(m.id)) deduped.add(m);
    }
    return deduped;
  }

  Future<List<MissionAttemptModel>> _fetchAttempts() async {
    final learnerId = widget.learnerId;
    if (learnerId == null || learnerId.isEmpty) return <MissionAttemptModel>[];
    final snap = await FirebaseFirestore.instance
        .collection('missionAttempts')
        .where('learnerId', isEqualTo: learnerId)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();
    return snap.docs.map(MissionAttemptModel.fromDoc).toList();
  }

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      title: 'Available missions',
      subtitle: 'Site-specific and global missions with recent attempts.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Loading missions...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          if (_missions.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Missions', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _missions.length,
                  separatorBuilder: (_, unused) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, index) {
                    final m = _missions[index];
                    final pillars = (m.pillarCodes).join(' • ');
                    final scope = (m.siteId == null || (m.siteId?.isEmpty ?? true)) ? 'Global' : 'Site';
                    return ListTile(
                      dense: true,
                      title: Text(m.title, style: const TextStyle(color: Colors.white)),
                      subtitle: Text('$scope • $pillars', style: const TextStyle(color: Colors.white70)),
                    );
                  },
                ),
              ],
            ),
          if (_missions.isEmpty && !_loading)
            const Text('No missions available yet.', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          if (_attempts.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recent attempts', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _attempts.length,
                  separatorBuilder: (_, unused) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, index) {
                    final a = _attempts[index];
                    return ListTile(
                      dense: true,
                      title: Text(a.missionId, style: const TextStyle(color: Colors.white)),
                      subtitle: Text('Status: ${a.status}${a.reflection != null ? ' • ${a.reflection}' : ''}', style: const TextStyle(color: Colors.white70)),
                    );
                  },
                ),
              ],
            ),
          if (_attempts.isEmpty && !_loading)
            const Text('No attempts yet.', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _ParentSummaryCardState extends State<_ParentSummaryCard> {
  final TextEditingController _learnerId = TextEditingController();
  final TextEditingController _ackNote = TextEditingController();
  bool _loading = false;
  List<Map<String, String>> _portfolio = <Map<String, String>>[];

  @override
  void dispose() {
    _learnerId.dispose();
    _ackNote.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final learnerId = _learnerId.text.trim();
    if (learnerId.isEmpty) {
      _toast(context, 'Learner ID required');
      return;
    }
    setState(() => _loading = true);
    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('portfolioItems')
          .where('learnerId', isEqualTo: learnerId)
          .orderBy('createdAt', descending: true)
          .limit(5);
      if (widget.siteId != null) {
        query = query.where('siteId', isEqualTo: widget.siteId);
      }
      final snap = await query.get();
      if (mounted) {
        setState(() {
          _portfolio = snap.docs
              .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                final data = doc.data();
                final pillars = (data['pillarCodes'] as List?)?.whereType<String>().join(' • ');
                return <String, String>{
                  'title': data['title'] as String? ?? 'Untitled',
                  'description': data['description'] as String? ?? '',
                  'pillars': pillars ?? '',
                };
              })
              .toList();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _acknowledge() async {
    final learnerId = _learnerId.text.trim();
    final note = _ackNote.text.trim();
    final reviewerId = widget.appState.user?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (learnerId.isEmpty || reviewerId == null) {
      _toast(context, 'Learner ID and sign-in required');
      return;
    }
    final repo = AccountabilityReviewRepository();
    final model = AccountabilityReviewModel(
      id: FirebaseFirestore.instance.collection('accountabilityReviews').doc().id,
      cycleId: 'weekly-summary',
      reviewerId: reviewerId,
      revieweeId: learnerId,
      notes: note.isEmpty ? null : note,
      rating: 5,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
    await repo.upsert(model);
    if (!mounted) return;
    _toast(context, 'Summary acknowledged');
  }

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      title: 'Parent weekly summary',
      subtitle: 'View latest portfolio items and acknowledge.',
      child: Column(
        children: [
          _TextField(controller: _learnerId, label: 'Learner ID', hint: 'child uid'),
          const SizedBox(height: 8),
          _TextField(controller: _ackNote, label: 'Note (optional)', hint: 'Encouragement or feedback'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text('Load updates'),
                  onPressed: _loading ? null : _load,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text('Acknowledge'),
                  onPressed: _acknowledge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading) const CircularProgressIndicator(),
          if (!_loading && _portfolio.isNotEmpty)
            Column(
              children: _portfolio
                  .map(
                    (Map<String, String> item) => ListTile(
                      title: Text(item['title'] ?? '', style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        [item['description'], item['pillars']].where((String? v) => v != null && v.isNotEmpty).join(' • '),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _SiteSessionForm extends StatefulWidget {
  const _SiteSessionForm({required this.siteId, required this.appState});

  final String siteId;
  final AppState appState;

  @override
  State<_SiteSessionForm> createState() => _SiteSessionFormState();
}

class _SiteSessionFormState extends State<_SiteSessionForm> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _educatorId = TextEditingController();
  final TextEditingController _pillars = TextEditingController(text: 'FUTURE_SKILLS');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _educatorId.dispose();
    _pillars.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _toast(context, 'Session name required');
      return;
    }
    setState(() => _saving = true);
    try {
      final sessionRepo = SessionRepository();
      final auditRepo = AuditLogRepository();
      final sessionId = FirebaseFirestore.instance.collection('sessions').doc().id;
      final model = SessionModel(
        id: sessionId,
        siteId: widget.siteId,
        name: name,
        educatorId: _educatorId.text.trim().isEmpty ? null : _educatorId.text.trim(),
        pillarEmphasis: _splitCodes(_pillars.text),
        schedule: null,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );
      await sessionRepo.upsert(model);
      final actorId = widget.appState.user?.uid ?? FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      await auditRepo.log(
        AuditLogModel(
          id: 'audit-session-$sessionId',
          actorId: actorId,
          actorRole: 'site',
          action: 'session.upsert',
          entityType: 'session',
          entityId: sessionId,
          siteId: widget.siteId,
          details: {'name': name, 'educatorId': model.educatorId},
          createdAt: Timestamp.now(),
        ),
      );
      if (mounted) {
        _toast(context, 'Session created');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      title: 'Site: add session',
      subtitle: 'Online create with pillar emphasis.',
      child: Column(
        children: [
          _TextField(controller: _name, label: 'Session name', hint: 'Robotics Lab'),
          const SizedBox(height: 8),
          _TextField(controller: _educatorId, label: 'Educator ID (optional)', hint: 'uid'),
          const SizedBox(height: 8),
          _TextField(controller: _pillars, label: 'Pillar codes (comma separated)', hint: 'FUTURE_SKILLS'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_circle, color: Colors.white),
              label: Text(_saving ? 'Saving...' : 'Create session'),
              onPressed: _saving ? null : _save,
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnerDeliverableForm extends StatefulWidget {
  const _PartnerDeliverableForm({required this.appState});

  final AppState appState;

  @override
  State<_PartnerDeliverableForm> createState() => _PartnerDeliverableFormState();
}

class _PartnerDeliverableFormState extends State<_PartnerDeliverableForm> {
  final TextEditingController _contractId = TextEditingController();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _url = TextEditingController();
  String _status = 'submitted';
  bool _saving = false;

  @override
  void dispose() {
    _contractId.dispose();
    _title.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final contractId = _contractId.text.trim();
    final title = _title.text.trim();
    if (contractId.isEmpty || title.isEmpty) {
      _toast(context, 'Contract ID and title required');
      return;
    }
    final partnerId = widget.appState.user?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (partnerId == null) {
      _toast(context, 'Sign in required');
      return;
    }
    setState(() => _saving = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('partnerDeliverables').add({
        'contractId': contractId,
        'title': title,
        'status': _status,
        'url': _url.text.trim().isEmpty ? null : _url.text.trim(),
        'partnerId': partnerId,
        'createdAt': Timestamp.now(),
      });
      await AuditLogRepository().log(
        AuditLogModel(
          id: 'audit-deliverable-${doc.id}',
          actorId: partnerId,
          actorRole: 'partner',
          action: 'deliverable.submit',
          entityType: 'partnerDeliverable',
          entityId: doc.id,
          siteId: null,
          details: {'contractId': contractId, 'status': _status},
          createdAt: Timestamp.now(),
        ),
      );
      if (mounted) {
        _toast(context, 'Deliverable submitted');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      title: 'Partner deliverable',
      subtitle: 'Online submission with status tracking.',
      child: Column(
        children: [
          _TextField(controller: _contractId, label: 'Contract ID', hint: 'contract-123'),
          const SizedBox(height: 8),
          _TextField(controller: _title, label: 'Deliverable title', hint: 'Workshop slides'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _status,
            dropdownColor: const Color(0xFF0F172A),
            decoration: _inputDecoration('Status'),
            items: const [
              DropdownMenuItem(value: 'submitted', child: Text('Submitted')),
              DropdownMenuItem(value: 'in_review', child: Text('In review')),
              DropdownMenuItem(value: 'approved', child: Text('Approved')),
            ],
            onChanged: (value) => setState(() => _status = value ?? 'submitted'),
          ),
          const SizedBox(height: 8),
          _TextField(controller: _url, label: 'Artifact URL (optional)', hint: 'https://...'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.cloud_upload, color: Colors.white),
              label: Text(_saving ? 'Submitting...' : 'Submit deliverable'),
              onPressed: _saving ? null : _save,
            ),
          ),
        ],
      ),
    );
  }
}

class _HqKpiForm extends StatefulWidget {
  const _HqKpiForm({required this.appState});

  final AppState appState;

  @override
  State<_HqKpiForm> createState() => _HqKpiFormState();
}

class _HqKpiFormState extends State<_HqKpiForm> {
  final TextEditingController _cycleId = TextEditingController(text: 'network-fy');
  final TextEditingController _name = TextEditingController();
  final TextEditingController _target = TextEditingController(text: '100');
  final TextEditingController _current = TextEditingController(text: '0');
  final TextEditingController _unit = TextEditingController(text: 'learners');
  bool _saving = false;

  @override
  void dispose() {
    _cycleId.dispose();
    _name.dispose();
    _target.dispose();
    _current.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final target = double.tryParse(_target.text.trim());
    final current = double.tryParse(_current.text.trim());
    if (name.isEmpty || target == null || current == null) {
      _toast(context, 'Name, target, and current value required');
      return;
    }
    final actorId = widget.appState.user?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (actorId == null) {
      _toast(context, 'Sign in required');
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = AccountabilityKPIRepository();
      final kpiId = FirebaseFirestore.instance.collection('accountabilityKPIs').doc().id;
      final model = AccountabilityKPIModel(
        id: kpiId,
        cycleId: _cycleId.text.trim(),
        name: name,
        target: target,
        currentValue: current,
        unit: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );
      await repo.upsert(model);
      await AuditLogRepository().log(
        AuditLogModel(
          id: 'audit-kpi-$kpiId',
          actorId: actorId,
          actorRole: 'hq',
          action: 'kpi.upsert',
          entityType: 'accountabilityKPI',
          entityId: kpiId,
          siteId: null,
          details: {'cycleId': model.cycleId, 'name': model.name},
          createdAt: Timestamp.now(),
        ),
      );
      if (mounted) {
        _toast(context, 'KPI saved');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      title: 'HQ KPI (online)',
      subtitle: 'Record network metrics for analytics.',
      child: Column(
        children: [
          _TextField(controller: _cycleId, label: 'Cycle ID', hint: 'network-fy'),
          const SizedBox(height: 8),
          _TextField(controller: _name, label: 'KPI name', hint: 'Active learners'),
          const SizedBox(height: 8),
          _TextField(controller: _target, label: 'Target', hint: '100'),
          const SizedBox(height: 8),
          _TextField(controller: _current, label: 'Current value', hint: '42'),
          const SizedBox(height: 8),
          _TextField(controller: _unit, label: 'Unit (optional)', hint: 'learners'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.insights, color: Colors.white),
              label: Text(_saving ? 'Saving...' : 'Save KPI'),
              onPressed: _saving ? null : _save,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 12))],
        gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF111827)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({required this.controller, required this.label, this.hint});

  final TextEditingController controller;
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label).copyWith(hintText: hint, hintStyle: const TextStyle(color: Colors.white54)),
    );
  }
}

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white70),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.05),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
  );
}

List<String> _splitCodes(String raw) {
  return raw
      .split(RegExp('[,\\s]+'))
      .map((String value) => value.trim())
      .where((String value) => value.isNotEmpty)
      .toList();
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF38BDF8),
    ),
  );
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
                (DashboardItem item) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 8))],
                  ),
                  child: ListTile(
                    title: Text(item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    subtitle: item.subtitle != null
                        ? Text(item.subtitle!, style: const TextStyle(color: Colors.white70))
                        : null,
                    trailing: const Icon(Icons.chevron_right, color: Colors.white54),
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
      color: Colors.white.withValues(alpha: 0.06),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Colors.white12)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(card.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(card.description, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF6366F1)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                card.pillar,
                style: TextStyle(color: scheme.onSecondaryContainer, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      width: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]),
    );
  }
}
