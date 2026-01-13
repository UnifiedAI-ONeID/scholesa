import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ui/theme/scholesa_theme.dart';
import '../../services/telemetry_service.dart';
import 'incident_service.dart';

/// Site incidents management page
/// Based on docs/41_SAFETY_CONSENT_INCIDENTS_SPEC.md
/// Wired to IncidentService for live Firestore data
class SiteIncidentsPage extends StatefulWidget {
  const SiteIncidentsPage({super.key});

  @override
  State<SiteIncidentsPage> createState() => _SiteIncidentsPageState();
}

class _SiteIncidentsPageState extends State<SiteIncidentsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IncidentService>().loadIncidents();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: const Text('Safety & Incidents'),
        backgroundColor: ScholesaColors.safetyGradient.colors.first,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<IncidentService>().loadIncidents(),
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const <Widget>[
            Tab(text: 'Open'),
            Tab(text: 'Reviewed'),
            Tab(text: 'Closed'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateIncidentDialog(),
        backgroundColor: ScholesaColors.safetyGradient.colors.first,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Report Incident'),
      ),
      body: Consumer<IncidentService>(
        builder: (BuildContext context, IncidentService service, Widget? child) {
          if (service.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (service.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                  const SizedBox(height: 16),
                  Text('Error: ${service.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => service.loadIncidents(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          return TabBarView(
            controller: _tabController,
            children: <Widget>[
              _buildIncidentList(service, IncidentStatus.submitted),
              _buildIncidentList(service, IncidentStatus.reviewed),
              _buildIncidentList(service, IncidentStatus.closed),
            ],
          );
        },
      ),
    );
  }

  Widget _buildIncidentList(IncidentService service, IncidentStatus statusFilter) {
    final List<Incident> filtered = service.incidents
        .where((Incident i) => i.status == statusFilter)
        .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.check_circle_rounded,
              size: 64,
              color: Colors.green.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No ${statusFilter.name} incidents',
              style: const TextStyle(
                fontSize: 16,
                color: ScholesaColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => service.loadIncidents(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (BuildContext context, int index) {
          return _buildIncidentCard(filtered[index]);
        },
      ),
    );
  }

  Widget _buildIncidentCard(Incident incident) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showIncidentDetails(incident),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _buildSeverityBadge(incident.severity),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      incident.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: ScholesaColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  const Icon(Icons.person_rounded, size: 16, color: ScholesaColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    incident.learnerName,
                    style: const TextStyle(
                      fontSize: 13,
                      color: ScholesaColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.schedule_rounded, size: 16, color: ScholesaColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(incident.reportedAt),
                    style: const TextStyle(
                      fontSize: 13,
                      color: ScholesaColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Reported by ${incident.reportedBy}',
                style: const TextStyle(
                  fontSize: 12,
                  color: ScholesaColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeverityBadge(IncidentSeverity severity) {
    Color color;
    String label;
    switch (severity) {
      case IncidentSeverity.minor:
        color = Colors.orange;
        label = 'Minor';
      case IncidentSeverity.major:
        color = Colors.deepOrange;
        label = 'Major';
      case IncidentSeverity.critical:
        color = Colors.red;
        label = 'Critical';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  void _showIncidentDetails(Incident incident) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ScholesaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _buildSeverityBadge(incident.severity),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    incident.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Learner', incident.learnerName),
            _buildInfoRow('Reported By', incident.reportedBy),
            _buildInfoRow('Date', _formatDateTime(incident.reportedAt)),
            _buildInfoRow('Status', incident.status.name.toUpperCase()),
            if (incident.description.isNotEmpty)
              _buildInfoRow('Description', incident.description),
            const SizedBox(height: 24),
            if (incident.status != IncidentStatus.closed)
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        final IncidentService service = this.context.read<IncidentService>();
                        final IncidentStatus newStatus = incident.status == IncidentStatus.submitted 
                            ? IncidentStatus.reviewed 
                            : IncidentStatus.closed;
                        await service.updateIncidentStatus(incidentId: incident.id, newStatus: newStatus);
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(content: Text('Incident ${newStatus.name}')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ScholesaColors.safetyGradient.colors.first,
                      ),
                      child: Text(incident.status == IncidentStatus.submitted ? 'Review' : 'Close Incident'),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(color: ScholesaColors.textSecondary),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateIncidentDialog() {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descController = TextEditingController();
    final TextEditingController learnerController = TextEditingController();
    IncidentSeverity severity = IncidentSeverity.minor;

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
          backgroundColor: ScholesaColors.surface,
          title: const Text('Report New Incident'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Incident Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: learnerController,
                  decoration: const InputDecoration(
                    labelText: 'Learner Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<IncidentSeverity>(
                  value: severity,
                  decoration: const InputDecoration(
                    labelText: 'Severity',
                    border: OutlineInputBorder(),
                  ),
                  items: IncidentSeverity.values.map((IncidentSeverity s) => DropdownMenuItem<IncidentSeverity>(
                    value: s,
                    child: Text(s.name.toUpperCase()),
                  )).toList(),
                  onChanged: (IncidentSeverity? val) {
                    if (val != null) {
                      setDialogState(() => severity = val);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty || learnerController.text.isEmpty) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Please fill in title and learner name')),
                  );
                  return;
                }
                Navigator.pop(dialogContext);
                
                final IncidentService service = this.context.read<IncidentService>();
                await service.createIncident(
                  title: titleController.text,
                  description: descController.text,
                  severity: severity,
                  learnerId: 'temp_learner_id', // In real app, select from dropdown
                  learnerName: learnerController.text,
                  category: 'general',
                );
                
                // Track telemetry
                this.context.read<TelemetryService>().logEvent('incident.created', metadata: <String, dynamic>{
                  'severity': severity.name,
                });
                
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Incident reported')),
                  );
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
