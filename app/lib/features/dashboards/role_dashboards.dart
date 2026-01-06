import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../auth/app_state.dart';
import '../offline/offline_queue.dart';
import '../offline/offline_service.dart';

/// Role dashboard with lean attendance + mission submission slices.
class RoleDashboard extends StatelessWidget {
  const RoleDashboard({super.key, required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final managedSites = appState.siteIds;
    final defaultSite = appState.primarySiteId ?? (managedSites.isNotEmpty ? managedSites.first : '');
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard • $role'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              context.read<AppState>().clearAuth();
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
                  if (role == 'hq' && managedSites.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Text('Managed site:', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: defaultSite.isNotEmpty ? defaultSite : managedSites.first,
                                items: managedSites
                                    .map((id) => DropdownMenuItem<String>(value: id, child: Text(id)))
                                    .toList(),
                                onChanged: (value) async {
                                  await appState.setPrimarySite(value);
                                },
                                decoration: const InputDecoration(labelText: 'Select site'),
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
                  if (role == 'hq') ...[
                    const _CardTitle('Site provisioning'),
                    const _SiteProvisionCard(),
                    const SizedBox(height: 16),
                  ],
                  if (role == 'educator' || role == 'site') ...[
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
                  if (role == 'educator' || role == 'hq' || role == 'site') ...[
                    const _CardTitle('Issue credential'),
                    _CredentialCard(role: role, initialSiteId: defaultSite),
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
