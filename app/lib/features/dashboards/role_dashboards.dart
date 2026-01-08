import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../auth/app_state.dart';
import '../offline/offline_queue.dart';
import '../offline/offline_service.dart';
import '../../services/telemetry_service.dart';
import '../../services/notification_service.dart';
import '../../services/billing_service.dart';
import '../../services/storage_service.dart';
import '../offline/offline_queue.dart';
import '../offline/offline_service.dart';

/// Role dashboard with lean attendance + mission submission slices.
class RoleDashboard extends StatefulWidget {
  const RoleDashboard({super.key, required this.role});

  final String role;

  @override
  State<RoleDashboard> createState() => _RoleDashboardState();
}

class _RoleDashboardState extends State<RoleDashboard> {
  final TextEditingController _manualSite = TextEditingController();

  @override
  void dispose() {
    _manualSite.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.role;
    final appState = context.watch<AppState>();
    final entitlements = appState.entitlements;
    bool hasAny(List<String> roles) => roles.any(entitlements.contains);
    final managedSites = appState.siteIds;
    final defaultSite = appState.primarySiteId ?? (managedSites.isNotEmpty ? managedSites.first : '');
    if (_manualSite.text.isEmpty && defaultSite.isNotEmpty) {
      _manualSite.text = defaultSite;
    }
                  if (hasAny(['hq', 'site'])) ...[
      appBar: AppBar(
        title: Text('Dashboard • $role'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final appState = context.read<AppState>();
              final role = appState.role;
              final siteId = appState.primarySiteId;
              TelemetryService.instance.logEvent(
                event: 'auth.logout',
                role: role,
                siteId: siteId,
              );
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              appState.clearAuth();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer2<OfflineQueue, OfflineService>(
          builder: (context, queue, offline, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (role == 'hq') ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Managed site', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            if (managedSites.isNotEmpty)
                              DropdownButtonFormField<String>(
                                initialValue: defaultSite.isNotEmpty ? defaultSite : managedSites.first,
                                items: managedSites
                                    .map((id) => DropdownMenuItem<String>(value: id, child: Text(id)))
                                    .toList(),
                                onChanged: (value) async {
                                  await appState.setPrimarySite(value);
                                  if (value != null) _manualSite.text = value;
                                  setState(() {});
                                },
                                decoration: const InputDecoration(labelText: 'Select site'),
                              )
                            else
                              const Text('No managed sites loaded for this HQ user.'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _manualSite,
                              decoration: const InputDecoration(
                                labelText: 'Override / enter site ID',
                                hintText: 'site-123',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final value = _manualSite.text.trim();
                                  await appState.setPrimarySite(value.isEmpty ? null : value);
                                  setState(() {});
                                },
                                icon: const Icon(Icons.check),
                                label: const Text('Apply site'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _QueueStatus(queue: queue, offline: offline),
                  const SizedBox(height: 12),
                  _QueueInspector(queue: queue),
                  const SizedBox(height: 16),
                  if (role == 'hq' || role == 'site') ...[
                    const _CardTitle('Site provisioning'),
                    const _SiteProvisionCard(),
                    const SizedBox(height: 12),
                    _CardTitle('${role.toUpperCase()} admin provisioning'),
                    _LearnerProfileCard(role: role, initialSiteId: defaultSite),
                    const SizedBox(height: 12),
                    _ParentProfileCard(role: role, initialSiteId: defaultSite),
                    const SizedBox(height: 12),
                    _GuardianLinkCard(role: role, initialSiteId: defaultSite),
                    const SizedBox(height: 16),
                  ],
                  if (hasAny(['educator', 'site'])) ...[
                    const _CardTitle('Quick attendance'),
                    _AttendanceCard(initialSiteId: defaultSite),
                    const SizedBox(height: 24),
                  ],
                  const _CardTitle('Submit mission attempt'),
                  _MissionAttemptCard(role: role),
                  const SizedBox(height: 24),
                  const _CardTitle('Portfolio'),
                  _PortfolioCard(role: role, initialSiteId: defaultSite),
                  const SizedBox(height: 24),
                  if (hasAny(['educator', 'hq', 'site'])) ...[
                    const _CardTitle('Issue credential'),
                    _CredentialCard(role: role, initialSiteId: defaultSite),
                    const SizedBox(height: 24),
                  ],
                  const _CardTitle('Messaging'),
                  _MessagingCard(role: role, initialSiteId: defaultSite),
                  const SizedBox(height: 24),
                  if (hasAny(['hq', 'site'])) ...[
                    const _CardTitle('Marketplace checkout'),
                    _MarketplaceCheckoutCard(role: role, initialSiteId: defaultSite),
                    const SizedBox(height: 24),
                    const _CardTitle('Order paid telemetry'),
                    _OrderTelemetryCard(initialSiteId: defaultSite, role: role),
                    const SizedBox(height: 24),
                  ],
                  if (hasAny(['partner', 'hq'])) ...[
                    const _CardTitle('Partner contracting'),
                    _PartnerContractingCard(role: role),
                    const SizedBox(height: 24),
                  ],
                  if (hasAny(['hq', 'educator', 'site'])) ...[
                    const _CardTitle('AI drafts (human-in-loop)'),
                    _AiDraftCard(role: role, initialSiteId: defaultSite),
                    const SizedBox(height: 24),
                  ],
                  const _CardTitle('KPIs'),
                  _KpiCard(role: role),
                  const SizedBox(height: 24),
                  const _CardTitle('Announcements'),
                  _AnnouncementCard(role: role),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PortfolioCard extends StatefulWidget {
  const _PortfolioCard({required this.role, this.initialSiteId});

  final String role;
  final String? initialSiteId;

  @override
  State<_PortfolioCard> createState() => _PortfolioCardState();
}

class _PortfolioCardState extends State<_PortfolioCard> {
  final _siteId = TextEditingController();
  final _learnerId = TextEditingController();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _artifactUrls = TextEditingController();
  final _pillarCodes = TextEditingController(text: 'FUTURE_SKILLS,LEADERSHIP_AGENCY,IMPACT_INNOVATION');
  final _pillarFilter = TextEditingController();
  final _skillIds = TextEditingController();
  final _repo = PortfolioItemRepository();
  List<PortfolioItemModel> _items = <PortfolioItemModel>[];
  bool _submitting = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _learnerId.text = user.uid;
    }
    if (widget.initialSiteId != null && widget.initialSiteId!.isNotEmpty) {
      _siteId.text = widget.initialSiteId!;
    }
  }

  @override
  void dispose() {
    _siteId.dispose();
    _learnerId.dispose();
    _title.dispose();
    _description.dispose();
    _artifactUrls.dispose();
    _pillarCodes.dispose();
    _pillarFilter.dispose();
    _skillIds.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final siteId = _siteId.text.trim();
    final learnerId = _learnerId.text.trim().isEmpty
        ? (FirebaseAuth.instance.currentUser?.uid ?? '')
        : _learnerId.text.trim();
    final title = _title.text.trim();
    if (siteId.isEmpty || learnerId.isEmpty || title.isEmpty) {
      _toast('Fill site, learner, and title.');
      return;
    }
    setState(() => _submitting = true);
    final queue = context.read<OfflineQueue>();
    final offline = context.read<OfflineService>();
    final action = PendingAction(
      id: _buildId('portfolio', learnerId),
      type: 'portfolioItem',
      payload: {
        'siteId': siteId,
        'learnerId': learnerId,
        'title': title,
        'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
        'artifactUrls': _splitList(_artifactUrls.text),
        'pillarCodes': _splitList(_pillarCodes.text),
        'skillIds': _splitList(_skillIds.text),
        'actorRole': widget.role,
      },
      createdAt: DateTime.now().toUtc(),
    );
    await queue.enqueue(action);
    await queue.flush(online: !offline.isOffline);
    if (!mounted) return;
    setState(() => _submitting = false);
    _toast(offline.isOffline ? 'Queued offline' : 'Saved portfolio item');
    if (!offline.isOffline) {
      await _load(silent: true);
    }
  }

  Future<void> _load({bool silent = false}) async {
    final learnerId = _learnerId.text.trim().isEmpty
        ? (FirebaseAuth.instance.currentUser?.uid ?? '')
        : _learnerId.text.trim();
    if (learnerId.isEmpty) {
      if (!silent) _toast('Enter learner ID');
      return;
    }
    setState(() => _loading = true);
    try {
      final items = await _repo.listByLearner(learnerId);
      if (!mounted) return;
      final siteFilter = _siteId.text.trim();
      Iterable<PortfolioItemModel> filtered = items;
      if (siteFilter.isNotEmpty) {
        filtered = filtered.where((i) => i.siteId == siteFilter);
      }
      final pillarFilter = _pillarFilter.text.trim().toUpperCase();
      if (pillarFilter.isNotEmpty) {
        filtered = filtered.where((i) => i.pillarCodes.any((p) => p.toUpperCase().contains(pillarFilter)));
      }
      final list = filtered.toList();
      setState(() => _items = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _splitList(String text) {
    return text
        .split(',')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _copyLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final y = local.year.toString();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final offline = context.watch<OfflineService>().isOffline;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LabeledField(label: 'Site ID', controller: _siteId, hint: 'site-123'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Learner ID', controller: _learnerId, hint: 'learner-123 (defaults to you)'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Title', controller: _title, hint: 'Prototype submission'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Description', controller: _description, hint: 'Reflection or summary'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Artifact URLs (comma separated)', controller: _artifactUrls, hint: 'https://...'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Pillar codes (comma separated)', controller: _pillarCodes, hint: 'FUTURE_SKILLS'),
            const SizedBox(height: 8),
            _LabeledField(
              label: 'Filter by pillar (optional)',
              controller: _pillarFilter,
              hint: 'FUTURE_SKILLS',
              onChanged: (_) => _load(silent: true),
            ),
            const SizedBox(height: 8),
            _LabeledField(label: 'Skill IDs (comma separated)', controller: _skillIds, hint: 'skill-123'),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add_box),
                  label: Text(_submitting ? 'Saving...' : 'Add portfolio item'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _loading || offline ? null : _load,
                  icon: _loading
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh),
                  label: Text(_loading ? 'Loading...' : 'Load items'),
                ),
                const Spacer(),
                if (offline)
                  const Row(
                    children: [
                      Icon(Icons.wifi_off, color: Colors.redAccent),
                      SizedBox(width: 4),
                      Text('Offline', style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_items.isEmpty)
              const Text('No portfolio items loaded yet.')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final created = item.createdAt?.toDate();
                  return ListTile(
                    title: Text(item.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.description != null && item.description!.isNotEmpty)
                          Text(item.description!),
                        Text('Site: ${item.siteId}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        if (created != null)
                          Text(_fmt(created), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        if (item.artifactUrls.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: item.artifactUrls
                                  .map(
                                    (url) => ActionChip(
                                      avatar: const Icon(Icons.link, size: 16),
                                      label: Text(url.length > 20 ? '${url.substring(0, 20)}…' : url),
                                      onPressed: () => _copyLink(url),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (item.pillarCodes.isNotEmpty)
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: item.pillarCodes
                                .map((p) => Chip(label: Text(p), padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap))
                                .toList(),
                          ),
                        if (item.skillIds.isNotEmpty)
                          Text('${item.skillIds.length} skill link(s)',
                              style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _CredentialCard extends StatefulWidget {
  const _CredentialCard({required this.role, this.initialSiteId});

  final String role;
  final String? initialSiteId;

  @override
  State<_CredentialCard> createState() => _CredentialCardState();
}

class _CredentialCardState extends State<_CredentialCard> {
  final _siteId = TextEditingController();
  final _learnerId = TextEditingController();
  final _title = TextEditingController();
  final _pillarCodes = TextEditingController(text: 'FUTURE_SKILLS,LEADERSHIP_AGENCY,IMPACT_INNOVATION');
  final _skillIds = TextEditingController();
  final _repo = CredentialRepository();
  List<CredentialModel> _items = <CredentialModel>[];
  bool _submitting = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSiteId != null && widget.initialSiteId!.isNotEmpty) {
      _siteId.text = widget.initialSiteId!;
    }
  }

  @override
  void dispose() {
    _siteId.dispose();
    _learnerId.dispose();
    _title.dispose();
    _pillarCodes.dispose();
    _skillIds.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final siteId = _siteId.text.trim();
    final learnerId = _learnerId.text.trim().isEmpty
        ? (FirebaseAuth.instance.currentUser?.uid ?? '')
        : _learnerId.text.trim();
    final title = _title.text.trim();
    if (siteId.isEmpty || learnerId.isEmpty || title.isEmpty) {
      _toast('Fill site, learner, and title.');
      return;
    }
    setState(() => _submitting = true);
    final queue = context.read<OfflineQueue>();
    final offline = context.read<OfflineService>();
    final now = DateTime.now().toUtc();
    final action = PendingAction(
      id: _buildId('credential', learnerId),
      type: 'credential',
      payload: {
        'siteId': siteId,
        'learnerId': learnerId,
        'title': title,
        'pillarCodes': _splitList(_pillarCodes.text),
        'skillIds': _splitList(_skillIds.text),
        'issuedAt': now.toIso8601String(),
        'actorRole': widget.role,
      },
      createdAt: now,
    );
    await queue.enqueue(action);
    await queue.flush(online: !offline.isOffline);
    if (!mounted) return;
    setState(() => _submitting = false);
    _toast(offline.isOffline ? 'Queued offline' : 'Credential saved');
  }

  Future<void> _load() async {
    final learnerId = _learnerId.text.trim().isEmpty
        ? (FirebaseAuth.instance.currentUser?.uid ?? '')
        : _learnerId.text.trim();
    if (learnerId.isEmpty) {
      _toast('Enter learner ID');
      return;
    }
    setState(() => _loading = true);
    try {
      final items = await _repo.listByLearner(learnerId, siteId: _siteId.text.trim().isEmpty ? null : _siteId.text.trim());
      if (!mounted) return;
      setState(() => _items = items);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _splitList(String text) {
    return text
        .split(',')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmtCredential(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final offline = context.watch<OfflineService>().isOffline;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _LabeledField(label: 'Site ID', controller: _siteId, hint: 'site-123'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Learner ID', controller: _learnerId, hint: 'learner-123'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Title', controller: _title, hint: 'Certification title'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Pillar codes (comma separated)', controller: _pillarCodes, hint: 'FUTURE_SKILLS'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Skill IDs (comma separated)', controller: _skillIds, hint: 'skill-123'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.verified),
                    label: Text(_submitting ? 'Saving...' : 'Issue credential'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _loading || offline ? null : _load,
                  icon: _loading
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh),
                  label: Text(_loading ? 'Loading...' : 'Load issued'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (offline) ...[
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.wifi_off, color: Colors.redAccent),
                  SizedBox(width: 4),
                  Text('Offline', style: TextStyle(color: Colors.redAccent)),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (_items.isEmpty)
              const Text('No credentials loaded yet.')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final issued = item.issuedAt.toDate();
                  return ListTile(
                    title: Text(item.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Site: ${item.siteId}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        Text('Learner: ${item.learnerId}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        Text(_fmtCredential(issued), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (item.pillarCodes.isNotEmpty)
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: item.pillarCodes
                                .map((p) => Chip(label: Text(p), padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap))
                                .toList(),
                          ),
                        if (item.skillIds.isNotEmpty)
                          Text('${item.skillIds.length} skill link(s)',
                              style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _QueueStatus extends StatelessWidget {
  const _QueueStatus({required this.queue, required this.offline});

  final OfflineQueue queue;
  final OfflineService offline;

  @override
  Widget build(BuildContext context) {
    final pending = queue.pending.length;
    final syncing = queue.isFlushing;
    final color = offline.isOffline
        ? Colors.red.shade100
        : (pending > 0 ? Colors.blue.shade100 : Colors.green.shade100);
    final textColor = offline.isOffline
        ? Colors.red.shade800
        : (pending > 0 ? Colors.blue.shade800 : Colors.green.shade800);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(offline.isOffline
              ? Icons.wifi_off
              : syncing
                  ? Icons.sync
                  : (pending > 0 ? Icons.cloud_upload : Icons.check_circle),
              color: textColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              offline.isOffline
                  ? (pending > 0
                      ? 'Offline • $pending update(s) queued'
                      : 'Offline • queue empty')
                  : syncing
                      ? 'Syncing $pending update(s)...'
                      : (pending > 0 ? '$pending update(s) queued. Sync now?' : 'All synced'),
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
            ),
          ),
          if (!offline.isOffline)
            TextButton.icon(
              onPressed: syncing
                  ? null
                  : () {
                      queue.flush(online: true);
                    },
              icon: syncing
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: Text(syncing ? 'Syncing' : 'Sync now'),
            ),
        ],
      ),
    );
  }
}

class _QueueInspector extends StatelessWidget {
  const _QueueInspector({required this.queue});

  final OfflineQueue queue;

  @override
  Widget build(BuildContext context) {
    final pending = queue.pending;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Queued actions', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: pending.isEmpty
                      ? null
                      : () async {
                          await queue.clear();
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('Cleared queued actions')));
                        },
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (pending.isEmpty)
              const Text('Queue empty.')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pending.length,
                separatorBuilder: (_, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final p = pending[index];
                  return ListTile(
                    dense: true,
                    title: Text(p.type),
                    subtitle: Text(p.id),
                    trailing: Text(_fmt(p.createdAt)),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    final local = dt.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$m-$d $h:$min';
  }
}

class _SiteProvisionCard extends StatefulWidget {
  const _SiteProvisionCard();

  @override
  State<_SiteProvisionCard> createState() => _SiteProvisionCardState();
}

class _SiteProvisionCardState extends State<_SiteProvisionCard> {
  final _siteId = TextEditingController();
  final _name = TextEditingController();
  final _timezone = TextEditingController(text: 'UTC');
  final _address = TextEditingController();
  final _adminIds = TextEditingController();
  final _repo = SiteRepository();
  bool _saving = false;

  @override
  void dispose() {
    _siteId.dispose();
    _name.dispose();
    _timezone.dispose();
    _address.dispose();
    _adminIds.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final id = _siteId.text.trim();
    final name = _name.text.trim();
    if (id.isEmpty || name.isEmpty) {
      _toast('Site ID and name are required');
      return;
    }
    setState(() => _saving = true);
    final admins = _adminIds.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final model = SiteModel(
      id: id,
      name: name,
      timezone: _timezone.text.trim().isEmpty ? null : _timezone.text.trim(),
      address: _address.text.trim().isEmpty ? null : _address.text.trim(),
      adminUserIds: admins,
      createdAt: null,
      updatedAt: null,
    );
    try {
      await _repo.upsert(model);
      if (!mounted) return;
      _toast('Site saved');
    } catch (e) {
      if (!mounted) return;
      _toast('Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _LabeledField(label: 'Site ID', controller: _siteId, hint: 'site-123'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Name', controller: _name, hint: 'New Studio'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Timezone', controller: _timezone, hint: 'UTC or Continent/City'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Address (optional)', controller: _address, hint: 'City, Country'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Admin user IDs (comma separated)', controller: _adminIds, hint: 'uid1,uid2'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Saving...' : 'Save site'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LearnerProfileCard extends StatefulWidget {
  const _LearnerProfileCard({required this.role, this.initialSiteId});

  final String role;
  final String? initialSiteId;

  @override
  State<_LearnerProfileCard> createState() => _LearnerProfileCardState();
}

class _LearnerProfileCardState extends State<_LearnerProfileCard> {
  final _siteId = TextEditingController();
  final _learnerId = TextEditingController();
  final _legalName = TextEditingController();
  final _preferredName = TextEditingController();
  final _grade = TextEditingController();
  final _strengths = TextEditingController();
  final _needs = TextEditingController();
  final _interests = TextEditingController();
  final _goals = TextEditingController();
  final _emergency = TextEditingController();
  final _repo = LearnerProfileRepository();
  final _auditRepo = AuditLogRepository();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSiteId != null && widget.initialSiteId!.isNotEmpty) {
      _siteId.text = widget.initialSiteId!;
    }
  }

  @override
  void dispose() {
    _siteId.dispose();
    _learnerId.dispose();
    _legalName.dispose();
    _preferredName.dispose();
    _grade.dispose();
    _strengths.dispose();
    _needs.dispose();
    _interests.dispose();
    _goals.dispose();
    _emergency.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final siteId = _siteId.text.trim();
    final learnerId = _learnerId.text.trim();
    if (siteId.isEmpty || learnerId.isEmpty) {
      _toast('Site ID and learner ID are required');
      return;
    }
    setState(() => _saving = true);
    final model = LearnerProfileModel(
      id: learnerId,
      learnerId: learnerId,
      siteId: siteId,
      legalName: _legalName.text.trim().isEmpty ? null : _legalName.text.trim(),
      preferredName: _preferredName.text.trim().isEmpty ? null : _preferredName.text.trim(),
      gradeLevel: _grade.text.trim().isEmpty ? null : _grade.text.trim(),
      strengths: _splitList(_strengths.text),
      learningNeeds: _splitList(_needs.text),
      interests: _splitList(_interests.text),
      goals: _splitList(_goals.text),
      emergencyContact: _parseJson(_emergency.text),
      createdAt: null,
      updatedAt: null,
    );
    try {
      await _repo.upsert(model);
      final user = FirebaseAuth.instance.currentUser;
      await _auditRepo.log(
        AuditLogModel(
          id: 'audit-learnerProfile-$learnerId-${DateTime.now().millisecondsSinceEpoch}',
          actorId: user?.uid ?? 'unknown',
          actorRole: widget.role,
          action: 'learnerProfile.upsert',
          entityType: 'learnerProfile',
          entityId: learnerId,
          siteId: siteId,
          details: {'gradeLevel': model.gradeLevel},
          createdAt: Timestamp.now(),
        ),
      );
      if (!mounted) return;
      _toast('Learner profile saved');
    } catch (e) {
      if (!mounted) return;
      _toast('Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> _splitList(String value) {
    return value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Map<String, dynamic>? _parseJson(String value) {
    if (value.trim().isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(value) as Map);
    } catch (_) {
      return null;
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LabeledField(label: 'Site ID', controller: _siteId, hint: 'site-123'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Learner ID', controller: _learnerId, hint: 'uid-learner'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Legal name', controller: _legalName, hint: 'Full legal name'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Preferred name', controller: _preferredName, hint: 'Preferred'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Grade level', controller: _grade, hint: 'G7'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Strengths (comma separated)', controller: _strengths, hint: 'math, robotics'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Learning needs (comma separated)', controller: _needs, hint: 'visual supports'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Interests (comma separated)', controller: _interests, hint: 'AI, music'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Goals (comma separated)', controller: _goals, hint: 'present a demo'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Emergency contact JSON (optional)', controller: _emergency, hint: '{"name":"Guardian","phone":"+1"}'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Saving...' : 'Save learner profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParentProfileCard extends StatefulWidget {
  const _ParentProfileCard({required this.role, this.initialSiteId});

  final String role;
  final String? initialSiteId;

  @override
  State<_ParentProfileCard> createState() => _ParentProfileCardState();
}

class _ParentProfileCardState extends State<_ParentProfileCard> {
  final _siteId = TextEditingController();
  final _parentId = TextEditingController();
  final _legalName = TextEditingController();
  final _preferredName = TextEditingController();
  final _phone = TextEditingController();
  final _language = TextEditingController();
  final _commPrefs = TextEditingController();
  final _repo = ParentProfileRepository();
  final _auditRepo = AuditLogRepository();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSiteId != null && widget.initialSiteId!.isNotEmpty) {
      _siteId.text = widget.initialSiteId!;
    }
  }

  @override
  void dispose() {
    _siteId.dispose();
    _parentId.dispose();
    _legalName.dispose();
    _preferredName.dispose();
    _phone.dispose();
    _language.dispose();
    _commPrefs.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final siteId = _siteId.text.trim();
    final parentId = _parentId.text.trim();
    if (siteId.isEmpty || parentId.isEmpty) {
      _toast('Site ID and parent ID are required');
      return;
    }
    setState(() => _saving = true);
    final model = ParentProfileModel(
      id: parentId,
      parentId: parentId,
      siteId: siteId,
      legalName: _legalName.text.trim().isEmpty ? null : _legalName.text.trim(),
      preferredName: _preferredName.text.trim().isEmpty ? null : _preferredName.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      preferredLanguage: _language.text.trim().isEmpty ? null : _language.text.trim(),
      communicationPreferences: _splitList(_commPrefs.text),
      createdAt: null,
      updatedAt: null,
    );
    try {
      await _repo.upsert(model);
      final user = FirebaseAuth.instance.currentUser;
      await _auditRepo.log(
        AuditLogModel(
          id: 'audit-parentProfile-$parentId-${DateTime.now().millisecondsSinceEpoch}',
          actorId: user?.uid ?? 'unknown',
          actorRole: widget.role,
          action: 'parentProfile.upsert',
          entityType: 'parentProfile',
          entityId: parentId,
          siteId: siteId,
          details: {'phone': model.phone},
          createdAt: Timestamp.now(),
        ),
      );
      if (!mounted) return;
      _toast('Parent profile saved');
    } catch (e) {
      if (!mounted) return;
      _toast('Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> _splitList(String value) {
    return value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LabeledField(label: 'Site ID', controller: _siteId, hint: 'site-123'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Parent ID', controller: _parentId, hint: 'uid-parent'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Legal name', controller: _legalName, hint: 'Full legal name'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Preferred name', controller: _preferredName, hint: 'Preferred'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Phone', controller: _phone, hint: '+1 555'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Preferred language', controller: _language, hint: 'en'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Communication prefs (comma separated)', controller: _commPrefs, hint: 'sms,email'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Saving...' : 'Save parent profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuardianLinkCard extends StatefulWidget {
  const _GuardianLinkCard({required this.role, this.initialSiteId});

  final String role;
  final String? initialSiteId;

  @override
  State<_GuardianLinkCard> createState() => _GuardianLinkCardState();
}

class _GuardianLinkCardState extends State<_GuardianLinkCard> {
  final _siteId = TextEditingController();
  final _parentId = TextEditingController();
  final _learnerId = TextEditingController();
  final _relationship = TextEditingController();
  bool _isPrimary = false;
  final _repo = GuardianLinkRepository();
  final _auditRepo = AuditLogRepository();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSiteId != null && widget.initialSiteId!.isNotEmpty) {
      _siteId.text = widget.initialSiteId!;
    }
  }

  @override
  void dispose() {
    _siteId.dispose();
    _parentId.dispose();
    _learnerId.dispose();
    _relationship.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final siteId = _siteId.text.trim();
    final parentId = _parentId.text.trim();
    final learnerId = _learnerId.text.trim();
    if (siteId.isEmpty || parentId.isEmpty || learnerId.isEmpty) {
      _toast('Site, parent, learner IDs required');
      return;
    }
    setState(() => _saving = true);
    final id = 'link-$parentId-$learnerId-$siteId';
    final model = GuardianLinkModel(
      id: id,
      parentId: parentId,
      learnerId: learnerId,
      siteId: siteId,
      relationship: _relationship.text.trim().isEmpty ? null : _relationship.text.trim(),
      isPrimary: _isPrimary,
      createdAt: null,
      updatedAt: null,
    );
    try {
      await _repo.upsert(model);
      final user = FirebaseAuth.instance.currentUser;
      await _auditRepo.log(
        AuditLogModel(
          id: 'audit-guardianLink-$id-${DateTime.now().millisecondsSinceEpoch}',
          actorId: user?.uid ?? 'unknown',
          actorRole: widget.role,
          action: 'guardianLink.upsert',
          entityType: 'guardianLink',
          entityId: id,
          siteId: siteId,
          details: {'relationship': model.relationship, 'isPrimary': model.isPrimary},
          createdAt: Timestamp.now(),
        ),
      );
      if (!mounted) return;
      _toast('Guardian link saved');
    } catch (e) {
      if (!mounted) return;
      _toast('Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LabeledField(label: 'Site ID', controller: _siteId, hint: 'site-123'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Parent ID', controller: _parentId, hint: 'uid-parent'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Learner ID', controller: _learnerId, hint: 'uid-learner'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Relationship (optional)', controller: _relationship, hint: 'mother/father/guardian'),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _isPrimary,
                  onChanged: (value) => setState(() => _isPrimary = value ?? false),
                ),
                const Text('Primary guardian'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Saving...' : 'Save guardian link'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessagingCard extends StatefulWidget {
  const _MessagingCard({required this.role, this.initialSiteId});

  final String role;
  final String? initialSiteId;

  @override
  State<_MessagingCard> createState() => _MessagingCardState();
}

class _MessagingCardState extends State<_MessagingCard> {
  final _siteId = TextEditingController();
  final _subject = TextEditingController();
  final _participants = TextEditingController();
  final _threadId = TextEditingController();
  final _messageBody = TextEditingController();
  final _threads = <MessageThreadModel>[];
  List<MessageModel> _messages = <MessageModel>[];
  bool _loadingThreads = false;
  bool _sending = false;
  bool _creatingThread = false;
  DateTime? _lastSentAt;
  bool _queuedOffline = false;

  final _threadRepo = MessageThreadRepository();
  final _messageRepo = MessageRepository();
  bool _requestExternal = false;
  final _channel = TextEditingController(text: 'email');
  final _attachmentUrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialSiteId != null && widget.initialSiteId!.isNotEmpty) {
      _siteId.text = widget.initialSiteId!;
    }
    _loadThreads();
  }

  @override
  void dispose() {
    _siteId.dispose();
    _subject.dispose();
    _participants.dispose();
    _threadId.dispose();
    _messageBody.dispose();
    _channel.dispose();
    _attachmentUrl.dispose();
    super.dispose();
  }

  Future<void> _loadThreads() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _loadingThreads = true);
    try {
      final list = await _threadRepo.listByParticipant(userId: user.uid, siteId: _siteId.text.trim().isEmpty ? null : _siteId.text.trim(), limit: 20);
      if (!mounted) return;
      _threads
        ..clear()
        ..addAll(list);
      if (list.isNotEmpty && _threadId.text.isEmpty) {
        _threadId.text = list.first.id;
        await _loadMessages(list.first.id);
      }
    } finally {
      if (mounted) setState(() => _loadingThreads = false);
    }
  }

  Future<void> _loadMessages(String threadId) async {
    setState(() => _loadingThreads = true);
    try {
      final msgs = await _messageRepo.listByThread(threadId, limit: 50);
      if (!mounted) return;
      setState(() => _messages = msgs);
    } finally {
      if (mounted) setState(() => _loadingThreads = false);
    }
  }

  Future<void> _createThread() async {
    final siteId = _siteId.text.trim();
    final subject = _subject.text.trim();
    final participants = _splitList(_participants.text);
    final user = FirebaseAuth.instance.currentUser;
    if (siteId.isEmpty || user == null) {
      _toast('Site ID required');
      return;
    }
    if (!participants.contains(user.uid)) {
      participants.add(user.uid);
    }
    final threadId = _threadId.text.trim().isEmpty
      ? 'thread-$siteId-${DateTime.now().millisecondsSinceEpoch}'
      : _threadId.text.trim();
    final model = MessageThreadModel(
      id: threadId,
      siteId: siteId,
      participantIds: participants,
      subject: subject.isEmpty ? null : subject,
      createdAt: null,
    );
    setState(() => _creatingThread = true);
    try {
      await _threadRepo.upsert(model);
      if (!mounted) return;
      _toast('Thread saved');
      _threadId.text = threadId;
      await _loadThreads();
    } catch (e) {
      if (!mounted) return;
      _toast('Failed: $e');
    } finally {
      if (mounted) setState(() => _creatingThread = false);
    }
  }

  Future<void> _sendMessage({required bool offline}) async {
    final siteId = _siteId.text.trim();
    final threadId = _threadId.text.trim();
    final body = _messageBody.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (siteId.isEmpty || threadId.isEmpty || body.isEmpty || user == null) {
      _toast('Site, thread, message required');
      return;
    }
    if (body.length > 2000) {
      _toast('Message too long (2000 char max)');
      return;
    }
    final now = DateTime.now();
    if (_lastSentAt != null && now.difference(_lastSentAt!).inSeconds < 5) {
      _toast('Please wait a moment before sending another message.');
      return;
    }
    if (_requestExternal && _channel.text.trim().isEmpty) {
      _toast('Channel required when requesting external notification');
      return;
    }
    if (offline && _requestExternal) {
      _toast('External notifications require connectivity');
      return;
    }
    setState(() => _sending = true);
    final msgId = 'msg-$threadId-${DateTime.now().millisecondsSinceEpoch}-${user.uid}';
    final model = MessageModel(
      id: msgId,
      threadId: threadId,
      siteId: siteId,
      senderId: user.uid,
      senderRole: widget.role,
      body: body,
      createdAt: null,
    );
    try {
      if (offline) {
        final queue = context.read<OfflineQueue>();
        await queue.enqueue(PendingAction(
          id: msgId,
          type: 'message',
          payload: {
            'siteId': siteId,
            'threadId': threadId,
            'body': body,
            'role': widget.role,
          },
          createdAt: now,
        ));
        _queuedOffline = true;
      } else {
        await _messageRepo.add(model);
        await TelemetryService.instance.logEvent(
          event: 'message.sent',
          role: widget.role,
          siteId: siteId,
          metadata: {
            'threadId': threadId,
            'length': body.length,
            if (_attachmentUrl.text.isNotEmpty) 'attachment': true,
          },
        );
        if (_requestExternal && _channel.text.trim().isNotEmpty) {
          await NotificationService.instance.requestSend(
            channel: _channel.text.trim(),
            threadId: threadId,
            messageId: msgId,
            siteId: siteId,
          );
        }
        _lastSentAt = now;
        await _loadMessages(threadId);
      }
      _messageBody.clear();
      _attachmentUrl.clear();
    } catch (e) {
      _toast('Failed: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  List<String> _splitList(String value) {
    return value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final offline = context.watch<OfflineService>().isOffline;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LabeledField(label: 'Site ID', controller: _siteId, hint: 'site-123'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Thread ID (existing or new)', controller: _threadId, hint: 'thread-...'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Subject (optional)', controller: _subject, hint: 'Progress update'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Participant IDs (comma separated)', controller: _participants, hint: 'uid1,uid2'),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _requestExternal,
                  onChanged: (value) => setState(() => _requestExternal = value ?? false),
                ),
                const Text('Request external notification'),
                const SizedBox(width: 8),
                Expanded(
                  child: _LabeledField(label: 'Channel (email/sms/push)', controller: _channel, hint: 'email'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _loadingThreads
                      ? null
                      : () async {
                          if (_threadId.text.trim().isEmpty) {
                            _toast('Set thread ID before uploading');
                            return;
                          }
                          try {
                            final url = await StorageService.instance.pickAndUploadNotificationAttachment(threadId: _threadId.text.trim());
                            if (url != null) {
                              setState(() => _attachmentUrl.text = url);
                              _toast('Attachment uploaded');
                            }
                          } catch (e) {
                            _toast('Upload failed: $e');
                          }
                        },
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Attach file'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _creatingThread || offline ? null : _createThread,
                  icon: _creatingThread
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.forum),
                  label: Text(_creatingThread ? 'Saving...' : 'Create/Update thread'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _loadingThreads || offline ? null : _loadThreads,
                  icon: _loadingThreads
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh),
                  label: Text(_loadingThreads ? 'Loading...' : 'Refresh threads'),
                ),
                const Spacer(),
                if (offline)
                  const Row(
                    children: [
                      Icon(Icons.wifi_off, color: Colors.redAccent),
                      SizedBox(width: 4),
                      Text('Offline', style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_threads.isEmpty)
              const Text('No threads yet.')
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _threads.take(5).map((t) {
                  return ListTile(
                    dense: true,
                    title: Text(t.subject ?? t.id),
                    subtitle: Text('${t.participantIds.join(', ')} • ${t.siteId}'),
                    onTap: () async {
                      _threadId.text = t.id;
                      await _loadMessages(t.id);
                    },
                  );
                }).toList(),
              ),
            const Divider(),
            _LabeledField(label: 'Message', controller: _messageBody, hint: 'Type a message'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Attachment URL (optional)', controller: _attachmentUrl, hint: 'https://...'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : () => _sendMessage(offline: offline),
                icon: _sending
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: Text(_sending ? 'Sending...' : offline ? 'Queue message (offline)' : 'Send message'),
              ),
            ),
            const SizedBox(height: 8),
            if (_messages.isEmpty)
              const Text('No messages loaded.')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _messages.length,
                separatorBuilder: (context, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final m = _messages[index];
                  final ts = m.createdAt?.toDate();
                  return ListTile(
                    title: Text(m.body),
                    subtitle: Text('${m.senderId} (${m.senderRole})${ts != null ? ' • ${ts.toLocal()}' : ''}'),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceCheckoutCard extends StatefulWidget {
  const _MarketplaceCheckoutCard({required this.role, this.initialSiteId});

  final String role;
  final String? initialSiteId;

  @override
  State<_MarketplaceCheckoutCard> createState() => _MarketplaceCheckoutCardState();
}

class _MarketplaceCheckoutCardState extends State<_MarketplaceCheckoutCard> {
  final _siteId = TextEditingController();
  final _userId = TextEditingController();
  final _amount = TextEditingController();
  final _currency = TextEditingController(text: 'USD');
  String _productId = 'learner-seat';
  bool _submitting = false;
  String? _status;
  String? _lastIntentId;

  final List<Map<String, dynamic>> _products = <Map<String, dynamic>>[
    <String, dynamic>{'id': 'learner-seat', 'label': 'Learner seat', 'amount': '25', 'roles': <String>['learner']},
    <String, dynamic>{'id': 'educator-seat', 'label': 'Educator seat', 'amount': '30', 'roles': <String>['educator']},
    <String, dynamic>{'id': 'parent-seat', 'label': 'Parent seat', 'amount': '10', 'roles': <String>['parent']},
    <String, dynamic>{'id': 'site-license', 'label': 'Site license', 'amount': '500', 'roles': <String>['site', 'hq']},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialSiteId != null && widget.initialSiteId!.isNotEmpty) {
      _siteId.text = widget.initialSiteId!;
    }
    _amount.text = _products.firstWhere((p) => p['id'] == _productId)['amount'] as String;
  }

  @override
  void dispose() {
    _siteId.dispose();
    _userId.dispose();
    _amount.dispose();
    _currency.dispose();
    super.dispose();
  }

  Future<void> _checkout() async {
    final siteId = _siteId.text.trim();
    final userId = _userId.text.trim();
    if (siteId.isEmpty || userId.isEmpty) {
      _toast('Site ID and user ID required');
      return;
    }
    setState(() {
      _submitting = true;
      _status = null;
    });
    try {
      final response = await BillingService.instance.createCheckoutIntent(
        siteId: siteId,
        userId: userId,
        productId: _productId,
        idempotencyKey: 'intent-$siteId-$userId-$_productId',
      );
      if (response == null) throw Exception('Billing service unavailable');
      if (!mounted) return;
      _lastIntentId = response['orderId'] as String?;
      setState(() {
        _status = 'Checkout intent ${response['orderId']} created. Fulfillment will grant entitlements.';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed: $e';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LabeledField(label: 'Site ID', controller: _siteId, hint: 'site-123'),
            const SizedBox(height: 8),
            _LabeledField(label: 'User ID to entitle', controller: _userId, hint: 'uid-target'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _productId,
              decoration: const InputDecoration(labelText: 'Product'),
              items: _products
                  .map((p) => DropdownMenuItem<String>(value: p['id'] as String, child: Text(p['label'] as String)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _productId = value;
                  _amount.text = _products.firstWhere((p) => p['id'] == value)['amount'] as String;
                });
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amount,
                    decoration: const InputDecoration(labelText: 'Amount (server-calculated)'),
                    readOnly: true,
                  ),
                ), 
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _currency,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    readOnly: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _checkout,
                icon: _submitting
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.shopping_cart_checkout),
                label: Text(_submitting ? 'Processing...' : 'Create checkout intent'),
              ),
            ),
            if (_status != null) ...[
              const SizedBox(height: 8),
              Text(_status!, style: TextStyle(color: _status!.startsWith('Failed') ? Colors.red : Colors.green)),
              if (_lastIntentId != null) Text('Intent ID: $_lastIntentId'),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderTelemetryCard extends StatefulWidget {
  const _OrderTelemetryCard({required this.initialSiteId, required this.role});

  final String? initialSiteId;
  final String role;

  @override
  State<_OrderTelemetryCard> createState() => _OrderTelemetryCardState();
}

class _OrderTelemetryCardState extends State<_OrderTelemetryCard> {
  final _siteId = TextEditingController();
  final _orderId = TextEditingController();
  final _amount = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSiteId != null && widget.initialSiteId!.isNotEmpty) {
      _siteId.text = widget.initialSiteId!;
    }
  }

  @override
  void dispose() {
    _siteId.dispose();
    _orderId.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _emit() async {
    final siteId = _siteId.text.trim();
    final orderId = _orderId.text.trim();
    final amount = _amount.text.trim();
    if (siteId.isEmpty || orderId.isEmpty) {
      _toast('Site and order ID required');
      return;
    }
    setState(() => _sending = true);
    try {
      await TelemetryService.instance.logEvent(
        event: 'order.paid',
        role: widget.role,
        siteId: siteId,
        metadata: {
          'orderId': orderId,
          if (amount.isNotEmpty) 'amount': amount,
        },
      );
      _toast('Order paid telemetry sent');
    } catch (e) {
      _toast('Failed: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LabeledField(label: 'Site ID', controller: _siteId, hint: 'site-123'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Order ID', controller: _orderId, hint: 'order-abc'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Amount (optional)', controller: _amount, hint: '100.00'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _emit,
                icon: _sending
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_circle),
                label: Text(_sending ? 'Sending...' : 'Record order paid telemetry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerContractingCard extends StatefulWidget {
  const _PartnerContractingCard({required this.role});

  final String role;

  @override
  State<_PartnerContractingCard> createState() => _PartnerContractingCardState();
}

class _PartnerContractingCardState extends State<_PartnerContractingCard> {
  final _orgName = TextEditingController();
  final _orgEmail = TextEditingController();
  final _contractTitle = TextEditingController();
  final _contractAmount = TextEditingController(text: '1000');
  final _contractCurrency = TextEditingController(text: 'USD');
  final _deliverableTitle = TextEditingController();
  final _deliverableEvidence = TextEditingController();
  final _payoutAmount = TextEditingController(text: '500');
  final _payoutCurrency = TextEditingController(text: 'USD');

  final _orgRepo = PartnerOrgRepository();
  final _contractRepo = PartnerContractRepository();
  final _deliverableRepo = PartnerDeliverableRepository();
  final _payoutRepo = PayoutRepository();
  final _auditRepo = AuditLogRepository();

  List<PartnerOrgModel> _orgs = <PartnerOrgModel>[];
  List<PartnerContractModel> _contracts = <PartnerContractModel>[];
  List<PartnerContractModel> _pendingContracts = <PartnerContractModel>[];
  List<PartnerDeliverableModel> _pendingDeliverables = <PartnerDeliverableModel>[];
  List<PayoutModel> _pendingPayouts = <PayoutModel>[];
  List<PartnerDeliverableModel> _contractDeliverables = <PartnerDeliverableModel>[];
  List<PayoutModel> _contractPayouts = <PayoutModel>[];
  String? _selectedOrgId;
  String? _selectedContractId;
  bool _loading = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _orgName.dispose();
    _orgEmail.dispose();
    _contractTitle.dispose();
    _contractAmount.dispose();
    _contractCurrency.dispose();
    _deliverableTitle.dispose();
    _deliverableEvidence.dispose();
    _payoutAmount.dispose();
    _payoutCurrency.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _status = null;
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      if (widget.role == 'partner') {
        _orgs = await _orgRepo.listMine(user.uid);
      } else {
        _orgs = await _orgRepo.listAll();
        _pendingContracts = await _contractRepo.listPendingApproval();
        _pendingDeliverables = await _deliverableRepo.listPendingAcceptance();
        _pendingPayouts = await _payoutRepo.listPendingApproval();
      }
      _selectedOrgId ??= _orgs.isNotEmpty ? _orgs.first.id : null;
      if (_selectedOrgId != null) {
        _contracts = await _contractRepo.listByOrg(_selectedOrgId!);
        _selectedContractId ??= _contracts.isNotEmpty ? _contracts.first.id : null;
        if (_selectedContractId != null) {
          _contractDeliverables = await _deliverableRepo.listByContract(_selectedContractId!);
          _contractPayouts = await _payoutRepo.listByContract(_selectedContractId!);
        }
      }
    } catch (e) {
      _status = 'Load failed: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createOrg() async {
    final name = _orgName.text.trim();
    if (name.isEmpty) {
      _toast('Org name required');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final orgId = await _orgRepo.create(name: name, ownerId: user.uid, contactEmail: _orgEmail.text.trim().isEmpty ? null : _orgEmail.text.trim());
      TelemetryService.instance.logEvent(event: 'contract.created', metadata: {'type': 'org'});
      await _audit('partnerOrg.create', 'partnerOrg', orgId, {'ownerId': user.uid});
      _orgName.clear();
      _orgEmail.clear();
      await _load();
      _toast('Org created');
    } catch (e) {
      _toast('Failed: $e');
    }
  }

  Future<void> _createContract() async {
    final orgId = _selectedOrgId;
    final title = _contractTitle.text.trim();
    if (orgId == null || title.isEmpty) {
      _toast('Org and title required');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    try {
      final contractId = await _contractRepo.createDraft(
        partnerOrgId: orgId,
        title: title,
        amount: _contractAmount.text.trim().isEmpty ? '0' : _contractAmount.text.trim(),
        currency: _contractCurrency.text.trim().isEmpty ? 'USD' : _contractCurrency.text.trim(),
        createdBy: user?.uid,
      );
      TelemetryService.instance.logEvent(event: 'contract.created', metadata: {'orgId': orgId, 'contractId': contractId});
      await _audit('contract.draft', 'partnerContract', contractId, {'title': title, 'amount': _contractAmount.text.trim(), 'currency': _contractCurrency.text.trim()});
      _contractTitle.clear();
      await _load();
      _toast('Contract drafted');
    } catch (e) {
      _toast('Failed: $e');
    }
  }

  Future<void> _approveContract(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _contractRepo.approve(id: id, approvedBy: user.uid);
      TelemetryService.instance.logEvent(event: 'contract.approved', metadata: {'contractId': id});
      await _audit('contract.approved', 'partnerContract', id, {});
      await _load();
      _toast('Contract approved');
    } catch (e) {
      _toast('Approve failed: $e');
    }
  }

  Future<void> _submitDeliverable() async {
    final contractId = _selectedContractId;
    final title = _deliverableTitle.text.trim();
    if (contractId == null || title.isEmpty) {
      _toast('Contract and title required');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    try {
      await _deliverableRepo.submit(
        contractId: contractId,
        title: title,
        description: null,
        evidenceUrl: _deliverableEvidence.text.trim().isEmpty ? null : _deliverableEvidence.text.trim(),
        submittedBy: user?.uid,
      );
      TelemetryService.instance.logEvent(event: 'deliverable.submitted', metadata: {'contractId': contractId});
      await _audit('deliverable.submitted', 'partnerDeliverable', contractId, {'title': title, 'evidenceUrl': _deliverableEvidence.text.trim()});
      _deliverableTitle.clear();
      _deliverableEvidence.clear();
      await _load();
      _toast('Deliverable submitted');
    } catch (e) {
      _toast('Failed: $e');
    }
  }

  Future<void> _acceptDeliverable(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _deliverableRepo.accept(id: id, acceptedBy: user.uid);
      TelemetryService.instance.logEvent(event: 'deliverable.accepted', metadata: {'deliverableId': id});
      await _audit('deliverable.accepted', 'partnerDeliverable', id, {});
      await _load();
      _toast('Deliverable accepted');
    } catch (e) {
      _toast('Accept failed: $e');
    }
  }

  Future<void> _createPayout() async {
    final contractId = _selectedContractId;
    if (contractId == null) {
      _toast('Contract required');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    try {
      final payoutId = await _payoutRepo.createPending(
        contractId: contractId,
        amount: _payoutAmount.text.trim().isEmpty ? '0' : _payoutAmount.text.trim(),
        currency: _payoutCurrency.text.trim().isEmpty ? 'USD' : _payoutCurrency.text.trim(),
        createdBy: user?.uid,
      );
      _payoutAmount.text = '500';
      TelemetryService.instance.logEvent(event: 'contract.created', metadata: {'type': 'payout', 'contractId': contractId, 'payoutId': payoutId});
      await _audit('payout.requested', 'payout', payoutId, {'contractId': contractId, 'amount': _payoutAmount.text.trim(), 'currency': _payoutCurrency.text.trim()});
      await _load();
      _toast('Payout requested');
    } catch (e) {
      _toast('Failed: $e');
    }
  }

  Future<void> _approvePayout(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _payoutRepo.approve(id: id, approvedBy: user.uid);
      TelemetryService.instance.logEvent(event: 'payout.approved', metadata: {'payoutId': id});
      await _audit('payout.approved', 'payout', id, {});
      await _load();
      _toast('Payout approved');
    } catch (e) {
      _toast('Approve failed: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _audit(String action, String entityType, String entityId, Map<String, dynamic> details) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _auditRepo.log(
        AuditLogModel(
          id: 'audit-$action-$entityId-${DateTime.now().millisecondsSinceEpoch}',
          actorId: user.uid,
          actorRole: widget.role,
          action: action,
          entityType: entityType,
          entityId: entityId,
          details: details,
          createdAt: Timestamp.now(),
        ),
      );
    } catch (_) {
      // Best effort.
    }
  }


class _AiDraftCard extends StatefulWidget {
  const _AiDraftCard({required this.role, this.initialSiteId});

  final String role;
  final String? initialSiteId;

  @override
  State<_AiDraftCard> createState() => _AiDraftCardState();
}

class _AiDraftCardState extends State<_AiDraftCard> {
  final _siteId = TextEditingController();
  final _title = TextEditingController();
  final _prompt = TextEditingController();
  final _reviewNotes = TextEditingController();

  final _repo = AiDraftRepository();
  final _auditRepo = AuditLogRepository();

  List<AiDraftModel> _mine = <AiDraftModel>[];
  List<AiDraftModel> _pending = <AiDraftModel>[];
  bool _loading = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSiteId != null && widget.initialSiteId!.isNotEmpty) {
      _siteId.text = widget.initialSiteId!;
    }
    _load();
  }

  @override
  void dispose() {
    _siteId.dispose();
    _title.dispose();
    _prompt.dispose();
    _reviewNotes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      _mine = await _repo.listMine(user.uid);
      if (widget.role == 'hq' || widget.role == 'site' || widget.role == 'educator') {
        _pending = await _repo.listPending();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestDraft() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final siteId = _siteId.text.trim();
    final title = _title.text.trim();
    final prompt = _prompt.text.trim();
    if (siteId.isEmpty || title.isEmpty || prompt.isEmpty) {
      _toast('Site, title, and prompt required');
      return;
    }
    setState(() => _submitting = true);
    try {
      final id = await _repo.createRequest(requesterId: user.uid, siteId: siteId, title: title, prompt: prompt);
      await TelemetryService.instance.logEvent(event: 'aiDraft.requested', role: widget.role, siteId: siteId, metadata: {'draftId': id});
      await _audit('aiDraft.requested', 'aiDraft', id, {'title': title});
      _title.clear();
      _prompt.clear();
      await _load();
      _toast('Draft requested');
    } catch (e) {
      _toast('Failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _review(String id, String status) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _submitting = true);
    try {
      await _repo.review(id: id, reviewerId: user.uid, status: status, notes: _reviewNotes.text.trim().isEmpty ? null : _reviewNotes.text.trim());
      await TelemetryService.instance.logEvent(event: 'aiDraft.reviewed', role: widget.role, metadata: {'draftId': id, 'status': status});
      await _audit('aiDraft.reviewed', 'aiDraft', id, {'status': status});
      _reviewNotes.clear();
      await _load();
      _toast('Updated');
    } catch (e) {
      _toast('Failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _audit(String action, String entityType, String entityId, Map<String, dynamic> details) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _auditRepo.log(
        AuditLogModel(
          id: 'audit-$action-$entityId-${DateTime.now().millisecondsSinceEpoch}',
          actorId: user.uid,
          actorRole: widget.role,
          action: action,
          entityType: entityType,
          entityId: entityId,
          details: details,
          createdAt: Timestamp.now(),
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loading) const LinearProgressIndicator(),
            _LabeledField(label: 'Site ID', controller: _siteId, hint: 'site-123'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Title', controller: _title, hint: 'Draft subject'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Prompt', controller: _prompt, hint: 'Describe the message'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _requestDraft,
                icon: _submitting
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_fix_high),
                label: Text(_submitting ? 'Submitting...' : 'Request draft'),
              ),
            ),
            const Divider(),
            const Text('My drafts'),
            if (_mine.isEmpty)
              const Text('No drafts yet.')
            else
              Column(
                children: _mine
                    .map((d) => ListTile(
                          dense: true,
                          title: Text('${d.title} (${d.status})'),
                          subtitle: Text(d.prompt),
                        ))
                    .toList(),
              ),
            if (widget.role == 'hq' || widget.role == 'site' || widget.role == 'educator') ...[
              const Divider(),
              const Text('Pending approvals'),
              if (_pending.isEmpty)
                const Text('No pending drafts.')
              else
                Column(
                  children: _pending
                      .map((d) => ListTile(
                            dense: true,
                            title: Text('${d.title} (${d.status})'),
                            subtitle: Text('By ${d.requesterId}'),
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                TextButton(onPressed: _submitting ? null : () => _review(d.id, 'approved'), child: const Text('Approve')),
                                TextButton(onPressed: _submitting ? null : () => _review(d.id, 'rejected'), child: const Text('Reject')),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              _LabeledField(label: 'Review notes (optional)', controller: _reviewNotes, hint: 'Feedback to requester'),
            ],
          ],
        ),
      ),
    );
  }
}
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_status != null) ...[
              Text(_status!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],
            if (widget.role == 'partner') ...[
              const Text('Create partner org', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              _LabeledField(label: 'Org name', controller: _orgName, hint: 'Acme Robotics'),
              const SizedBox(height: 6),
              _LabeledField(label: 'Contact email', controller: _orgEmail, hint: 'ops@example.com'),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(onPressed: _loading ? null : _createOrg, icon: const Icon(Icons.add_business), label: const Text('Create org')),
              ),
              const Divider(),
            ],
            DropdownButtonFormField<String>(
              value: _selectedOrgId,
              decoration: const InputDecoration(labelText: 'Partner org'),
              items: _orgs
                  .map((o) => DropdownMenuItem<String>(value: o.id, child: Text(o.name.isEmpty ? o.id : o.name)))
                  .toList(),
              onChanged: (value) async {
                _selectedOrgId = value;
                _selectedContractId = null;
                _contractDeliverables = <PartnerDeliverableModel>[];
                _contractPayouts = <PayoutModel>[];
                await _load();
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _LabeledField(label: 'Contract title', controller: _contractTitle, hint: 'STEM kits rollout')),
                const SizedBox(width: 8),
                SizedBox(width: 120, child: _LabeledField(label: 'Amount', controller: _contractAmount, hint: '1000')),
                const SizedBox(width: 8),
                SizedBox(width: 100, child: _LabeledField(label: 'Currency', controller: _contractCurrency, hint: 'USD')),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _createContract,
                icon: const Icon(Icons.description_outlined),
                label: const Text('Draft contract'),
              ),
            ),
            const Divider(),
            DropdownButtonFormField<String>(
              value: _selectedContractId,
              decoration: const InputDecoration(labelText: 'Contract'),
              items: _contracts
                  .map((c) => DropdownMenuItem<String>(value: c.id, child: Text('${c.title} • ${c.status}')))
                  .toList(),
              onChanged: (value) async {
                setState(() {
                  _selectedContractId = value;
                });
                if (value != null) {
                  try {
                    _contractDeliverables = await _deliverableRepo.listByContract(value);
                    _contractPayouts = await _payoutRepo.listByContract(value);
                  } catch (_) {
                    _contractDeliverables = <PartnerDeliverableModel>[];
                    _contractPayouts = <PayoutModel>[];
                  }
                  if (mounted) setState(() {});
                }
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _LabeledField(label: 'Deliverable title', controller: _deliverableTitle, hint: 'Workshop report')),
                const SizedBox(width: 8),
                Expanded(child: _LabeledField(label: 'Evidence URL', controller: _deliverableEvidence, hint: 'https://...')),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _loading
                      ? null
                      : () async {
                          if (_selectedContractId == null) {
                            _toast('Select a contract before uploading');
                            return;
                          }
                          setState(() => _loading = true);
                          try {
                            final url = await StorageService.instance.pickAndUploadDeliverable(contractId: _selectedContractId!);
                            if (url != null) {
                              _deliverableEvidence.text = url;
                              _toast('Uploaded');
                            }
                          } catch (e) {
                            _toast('Upload failed: $e');
                          } finally {
                            if (mounted) setState(() => _loading = false);
                          }
                        },
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Upload evidence'),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _loading ? null : _submitDeliverable,
                icon: const Icon(Icons.upload_file),
                label: const Text('Submit deliverable'),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                SizedBox(width: 120, child: _LabeledField(label: 'Payout amount', controller: _payoutAmount, hint: '500')),
                const SizedBox(width: 8),
                SizedBox(width: 100, child: _LabeledField(label: 'Currency', controller: _payoutCurrency, hint: 'USD')),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _createPayout,
                  icon: const Icon(Icons.request_quote),
                  label: const Text('Request payout'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_contracts.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _contracts
                    .map((c) => ListTile(
                          dense: true,
                          title: Text('${c.title} (${c.status})'),
                          subtitle: Text('Amount ${c.amount} ${c.currency}'),
                        ))
                    .toList(),
              ),
            if (_contractDeliverables.isNotEmpty) ...[
              const Divider(),
              const Text('Deliverables for selected contract'),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _contractDeliverables
                    .map((d) => ListTile(
                          dense: true,
                          title: Text('${d.title} (${d.status})'),
                          subtitle: Text(d.evidenceUrl ?? ''),
                        ))
                    .toList(),
              ),
            ],
            if (_contractPayouts.isNotEmpty) ...[
              const Divider(),
              const Text('Payouts for selected contract'),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _contractPayouts
                    .map((p) => ListTile(
                          dense: true,
                          title: Text('Payout ${p.amount} ${p.currency} (${p.status})'),
                          subtitle: Text('Requested by ${p.createdBy ?? ''}${p.approvedBy != null ? ' • Approved by ${p.approvedBy}' : ''}'),
                        ))
                    .toList(),
              ),
            ],
            if (widget.role == 'hq') ...[
              const Divider(),
              const Text('Pending approvals (HQ)', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              if (_pendingContracts.isEmpty)
                const Text('No draft contracts pending.')
              else
                Column(
                  children: _pendingContracts
                      .map((c) => ListTile(
                            dense: true,
                            title: Text('${c.title} • ${c.amount} ${c.currency}'),
                            subtitle: Text('Org ${c.partnerOrgId}'),
                            trailing: TextButton(onPressed: _loading ? null : () => _approveContract(c.id), child: const Text('Approve')),
                          ))
                      .toList(),
                ),
              const SizedBox(height: 6),
              if (_pendingDeliverables.isEmpty)
                const Text('No deliverables pending acceptance.')
              else
                Column(
                  children: _pendingDeliverables
                      .map((d) => ListTile(
                            dense: true,
                            title: Text(d.title),
                            subtitle: Text('Contract ${d.contractId} • ${d.evidenceUrl ?? ''}'),
                            trailing: TextButton(onPressed: _loading ? null : () => _acceptDeliverable(d.id), child: const Text('Accept')),
                          ))
                      .toList(),
                ),
              const SizedBox(height: 6),
              if (_pendingPayouts.isEmpty)
                const Text('No payouts pending approval.')
              else
                Column(
                  children: _pendingPayouts
                      .map((p) => ListTile(
                            dense: true,
                            title: Text('Payout ${p.amount} ${p.currency}'),
                            subtitle: Text('Contract ${p.contractId}'),
                            trailing: TextButton(onPressed: _loading ? null : () => _approvePayout(p.id), child: const Text('Approve')),
                          ))
                      .toList(),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _AttendanceCard extends StatefulWidget {
  const _AttendanceCard({this.initialSiteId});

  final String? initialSiteId;

  @override
  State<_AttendanceCard> createState() => _AttendanceCardState();
}

class _AttendanceCardState extends State<_AttendanceCard> {
  final _siteId = TextEditingController();
  final _sessionOccurrenceId = TextEditingController();
  final _learnerId = TextEditingController();
  String _status = 'present';
  bool _submitting = false;
  bool _loading = false;
  final _attendanceRepo = AttendanceRepository();
  List<AttendanceRecordModel> _recent = <AttendanceRecordModel>[];

  @override
  void initState() {
    super.initState();
    if (widget.initialSiteId != null && widget.initialSiteId!.isNotEmpty) {
      _siteId.text = widget.initialSiteId!;
    }
  }

  @override
  void dispose() {
    _siteId.dispose();
    _sessionOccurrenceId.dispose();
    _learnerId.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final siteId = _siteId.text.trim();
    final sessionOccurrenceId = _sessionOccurrenceId.text.trim();
    final learnerId = _learnerId.text.trim();
    if (siteId.isEmpty || sessionOccurrenceId.isEmpty || learnerId.isEmpty) {
      _toast('Fill site, session, learner.');
      return;
    }
    setState(() => _submitting = true);
    final queue = context.read<OfflineQueue>();
    final offline = context.read<OfflineService>();
    final user = FirebaseAuth.instance.currentUser;
    final action = PendingAction(
      id: _buildId('attendance', user?.uid),
      type: 'attendance',
      payload: {
        'siteId': siteId,
        'sessionOccurrenceId': sessionOccurrenceId,
        'learnerId': learnerId,
        'status': _status,
        'recordedBy': user?.uid,
        'actorRole': 'educator',
      },
      createdAt: DateTime.now().toUtc(),
    );
    await queue.enqueue(action);
    await queue.flush(online: !offline.isOffline);
    setState(() => _submitting = false);
    _toast(offline.isOffline ? 'Queued offline' : 'Recorded');
    if (!offline.isOffline) {
      await _load();
    }
  }

  Future<void> _load() async {
    final siteId = _siteId.text.trim();
    if (siteId.isEmpty) {
      _toast('Enter site ID');
      return;
    }
    setState(() => _loading = true);
    try {
      final items = await _attendanceRepo.listRecentBySite(siteId, limit: 8);
      if (!mounted) return;
      setState(() => _recent = items);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _deterministicIdHint() {
    final sessionId = _sessionOccurrenceId.text.trim();
    final learnerId = _learnerId.text.trim();
    if (sessionId.isEmpty || learnerId.isEmpty) return '';
    return AttendanceRepository().deterministicId(sessionId, learnerId);
  }

  String _fmt(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _LabeledField(label: 'Site ID', controller: _siteId, hint: 'site-123'),
            const SizedBox(height: 8),
            _LabeledField(
              label: 'Session occurrence ID',
              controller: _sessionOccurrenceId,
              hint: 'session-occ-123',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            _LabeledField(
              label: 'Learner ID',
              controller: _learnerId,
              hint: 'learner-123',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: DropdownButton<String>(
                value: _status,
                items: const [
                  DropdownMenuItem(value: 'present', child: Text('Present')),
                  DropdownMenuItem(value: 'late', child: Text('Late')),
                  DropdownMenuItem(value: 'absent', child: Text('Absent')),
                ],
                onChanged: (value) => setState(() => _status = value ?? 'present'),
              ),
            ),
            const SizedBox(height: 12),
            if (_deterministicIdHint().isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Deterministic ID: ${_deterministicIdHint()}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check),
                    label: Text(_submitting ? 'Saving...' : 'Save attendance'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _loading ? null : _load,
                  icon: _loading
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh),
                  label: Text(_loading ? 'Loading...' : 'Load recent'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_recent.isEmpty)
              const Text('No recent attendance loaded yet.')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recent.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _recent[index];
                  final created = item.createdAt?.toDate();
                  final idPreview = _attendanceRepo.deterministicId(item.sessionOccurrenceId, item.learnerId);
                  return ListTile(
                    title: Text('${item.learnerId} • ${item.status}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Session: ${item.sessionOccurrenceId}',
                            style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        if (created != null)
                          Text(_fmt(created), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        Text('Deterministic ID: $idPreview',
                            style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _MissionAttemptCard extends StatefulWidget {
  const _MissionAttemptCard({required this.role});

  final String role;

  @override
  State<_MissionAttemptCard> createState() => _MissionAttemptCardState();
}

class _MissionAttemptCardState extends State<_MissionAttemptCard> {
  final _siteId = TextEditingController();
  final _missionId = TextEditingController();
  final _sessionOccurrenceId = TextEditingController();
  final _reflection = TextEditingController();
  final _artifactUrls = TextEditingController();
  final _pillars = TextEditingController(text: 'FUTURE_SKILLS,LEADERSHIP_AGENCY,IMPACT_INNOVATION');
  bool _submitting = false;

  @override
  void dispose() {
    _siteId.dispose();
    _missionId.dispose();
    _sessionOccurrenceId.dispose();
    _reflection.dispose();
    _artifactUrls.dispose();
    _pillars.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final siteId = _siteId.text.trim();
    final missionId = _missionId.text.trim();
    if (siteId.isEmpty || missionId.isEmpty) {
      _toast('Fill site and mission.');
      return;
    }
    setState(() => _submitting = true);
    final queue = context.read<OfflineQueue>();
    final offline = context.read<OfflineService>();
    final user = FirebaseAuth.instance.currentUser;
    final learnerId = user?.uid ?? 'anonymous';
    final payload = {
      'siteId': siteId,
      'missionId': missionId,
      'sessionOccurrenceId': _sessionOccurrenceId.text.trim().isEmpty ? null : _sessionOccurrenceId.text.trim(),
      'reflection': _reflection.text.trim().isEmpty ? null : _reflection.text.trim(),
      'artifactUrls': _splitList(_artifactUrls.text),
      'pillarCodes': _splitList(_pillars.text),
      'learnerId': learnerId,
      'status': 'submitted',
      'actorRole': widget.role,
    };
    final action = PendingAction(
      id: _buildId('missionAttempt', learnerId),
      type: 'missionAttempt',
      payload: payload,
      createdAt: DateTime.now().toUtc(),
    );
    await queue.enqueue(action);
    await queue.flush(online: !offline.isOffline);
    setState(() => _submitting = false);
    _toast(offline.isOffline ? 'Queued offline' : 'Submitted');
  }

  List<String> _splitList(String text) {
    return text
        .split(',')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _LabeledField(label: 'Site ID', controller: _siteId, hint: 'site-123'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Mission ID', controller: _missionId, hint: 'mission-123'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Session occurrence (optional)', controller: _sessionOccurrenceId, hint: 'session-occ-123'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Artifact URLs (comma separated)', controller: _artifactUrls, hint: 'https://...'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Pillar codes (comma separated)', controller: _pillars, hint: 'FUTURE_SKILLS'),
            const SizedBox(height: 8),
            _LabeledField(label: 'Reflection', controller: _reflection, hint: 'What did you learn?'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: Text(_submitting ? 'Submitting...' : 'Submit mission attempt'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.controller, required this.hint, this.onChanged});

  final String label;
  final TextEditingController controller;
  final String hint;
  final void Function(String value)? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

String _buildId(String prefix, String? uid) {
  final ts = DateTime.now().millisecondsSinceEpoch;
  return '$prefix-$ts-${uid ?? 'anon'}';
}

class _AnnouncementCard extends StatefulWidget {
  const _AnnouncementCard({required this.role});

  final String role;

  @override
  State<_AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends State<_AnnouncementCard> {
  final _siteId = TextEditingController();
  final _repo = AnnouncementRepository();
  List<AnnouncementModel> _items = <AnnouncementModel>[];
  bool _loading = false;
  DateTime? _lastSeen;

  @override
  void initState() {
    super.initState();
    _loadLastSeen();
  }

  @override
  void dispose() {
    _siteId.dispose();
    super.dispose();
  }

  Future<void> _loadLastSeen() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString('announcements:lastSeen:${user.uid}');
    if (ts == null) return;
    setState(() => _lastSeen = DateTime.tryParse(ts)?.toUtc());
  }

  Future<void> _load() async {
    final siteId = _siteId.text.trim();
    if (siteId.isEmpty) {
      _toast('Enter site ID');
      return;
    }
    setState(() => _loading = true);
    try {
      final items = await _repo.listBySiteAndRole(siteId: siteId, role: widget.role);
      if (!mounted) return;
      setState(() => _items = items);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final now = DateTime.now().toUtc();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('announcements:lastSeen:${user.uid}', now.toIso8601String());
    if (!mounted) return;
    setState(() => _lastSeen = now);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  int _unreadCount() {
    if (_lastSeen == null) return _items.length;
    return _items.where((a) {
      final ts = a.publishedAt ?? a.createdAt;
      final dt = ts?.toDate().toUtc();
      return dt != null && dt.isAfter(_lastSeen!);
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final offline = context.watch<OfflineService>().isOffline;
    final unread = _unreadCount();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LabeledField(label: 'Site ID', controller: _siteId, hint: 'site-123'),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _loading || offline ? null : _load,
                  icon: _loading
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh),
                  label: Text(_loading ? 'Loading...' : 'Load announcements'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _items.isEmpty ? null : _markAllRead,
                  icon: const Icon(Icons.done_all),
                  label: const Text('Mark all read'),
                ),
                const Spacer(),
                if (offline)
                  const Row(
                    children: [
                      Icon(Icons.wifi_off, color: Colors.redAccent),
                      SizedBox(width: 4),
                      Text('Offline', style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(unread > 0 ? '$unread unread' : 'All caught up'),
            const SizedBox(height: 8),
            if (_items.isEmpty)
              const Text('No announcements loaded yet.')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                separatorBuilder: (_, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final a = _items[index];
                  final ts = (a.publishedAt ?? a.createdAt)?.toDate();
                  final isUnread = _lastSeen == null
                      ? true
                      : (ts != null && ts.toUtc().isAfter(_lastSeen!));
                  return ListTile(
                    leading: Icon(isUnread ? Icons.markunread : Icons.drafts),
                    title: Text(a.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.body),
                        if (ts != null)
                          Text(
                            _fmt(ts),
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                      ],
                    ),
                    trailing: Chip(
                      label: Text(a.roles.join(',')),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }
}

class _KpiCard extends StatefulWidget {
  const _KpiCard({required this.role});

  final String role;

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  final _repo = AccountabilityKPIRepository();
  List<AccountabilityKPIModel> _items = <AccountabilityKPIModel>[];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _repo.listRecent(limit: 6);
      if (!mounted) return;
      setState(() => _items = items);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(widget.role == 'hq' ? 'Network KPIs' : 'Site KPIs',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _loading ? null : _load,
                  icon: _loading
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Center(
                child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_items.isEmpty)
              const Text('No KPIs yet.')
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _items.map(_buildChip).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(AccountabilityKPIModel kpi) {
    final target = kpi.target == 0 ? 1 : kpi.target;
    final pct = (kpi.currentValue / target).clamp(0, 1).toDouble();
    final onTrack = pct >= 1;
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(kpi.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Chip(
                backgroundColor: onTrack ? Colors.green.shade100 : Colors.blue.shade100,
                label: Text(onTrack ? 'On track' : '${(pct * 100).round()}%'),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${kpi.currentValue}${kpi.unit != null ? ' ${kpi.unit}' : ''} / ${kpi.target}',
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: pct,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(onTrack ? Colors.green : Colors.blue),
            ),
          ),
        ],
      ),
    );
  }
}
