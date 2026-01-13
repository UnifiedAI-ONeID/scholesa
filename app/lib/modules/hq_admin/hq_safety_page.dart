import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ui/theme/scholesa_theme.dart';
import '../site/incident_service.dart';

/// HQ Safety page for monitoring safety incidents across all sites
/// Based on docs/41_SAFETY_CONSENT_INCIDENTS_SPEC.md
class HqSafetyPage extends StatefulWidget {
  const HqSafetyPage({super.key});

  @override
  State<HqSafetyPage> createState() => _HqSafetyPageState();
}

class _HqSafetyPageState extends State<HqSafetyPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IncidentService>().loadIncidents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScholesaColors.background,
      appBar: AppBar(
        title: const Text('Safety Overview'),
        backgroundColor: ScholesaColors.safetyGradient.colors.first,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<IncidentService>().loadIncidents(),
            tooltip: 'Refresh',
          ),
        ],
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
          if (service.incidents.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.verified_user_rounded, size: 64, color: Colors.green.shade400),
                  const SizedBox(height: 16),
                  const Text('No safety incidents reported', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  const Text('All sites operating safely', style: TextStyle(color: ScholesaColors.textSecondary)),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _buildSafetyMetrics(service),
              const SizedBox(height: 24),
              _buildEscalatedSection(service),
              const SizedBox(height: 24),
              _buildRecentIncidents(service),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSafetyMetrics(IncidentService service) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: ScholesaColors.safetyGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _buildMetric('Open', service.openIncidents.length.toString(), Icons.warning_rounded),
          _buildMetric('Major', service.majorIncidents.length.toString(), Icons.priority_high_rounded),
          _buildMetric('Critical', service.criticalIncidents.length.toString(), Icons.error_rounded),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, IconData icon) {
    return Column(
      children: <Widget>[
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9))),
      ],
    );
  }

  Widget _buildEscalatedSection(IncidentService service) {
    // Critical and major incidents are escalated to HQ
    final List<Incident> escalated = service.incidents
        .where((Incident i) => i.severity == IncidentSeverity.critical || i.severity == IncidentSeverity.major)
        .toList();
    if (escalated.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.priority_high_rounded, color: Colors.red.shade700, size: 20),
            const SizedBox(width: 8),
            Text(
              'Escalated to HQ (${escalated.length})',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...escalated.map((Incident incident) => _buildIncidentCard(incident, isEscalated: true)),
      ],
    );
  }

  Widget _buildRecentIncidents(IncidentService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'All Recent Incidents (${service.incidents.length})',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ScholesaColors.textPrimary),
        ),
        const SizedBox(height: 12),
        ...service.incidents.map((Incident incident) => _buildIncidentCard(incident)),
      ],
    );
  }

  Widget _buildIncidentCard(Incident incident, {bool isEscalated = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isEscalated ? Colors.red.shade50 : ScholesaColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isEscalated ? BorderSide(color: Colors.red.shade200) : BorderSide.none,
      ),
      child: ListTile(
        leading: _buildSeverityIcon(incident.severity),
        title: Text(incident.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${incident.siteId} • ${_formatTime(incident.reportedAt)} • ${incident.status.name}'),
        trailing: IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () => _showIncidentDetails(incident),
        ),
        onTap: () => _showIncidentDetails(incident),
      ),
    );
  }

  Widget _buildSeverityIcon(IncidentSeverity severity) {
    Color color;
    switch (severity) {
      case IncidentSeverity.minor:
        color = Colors.orange;
      case IncidentSeverity.major:
        color = Colors.deepOrange;
      case IncidentSeverity.critical:
        color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Icon(Icons.warning_rounded, color: color, size: 20),
    );
  }

  void _showIncidentDetails(Incident incident) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ScholesaColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(incident.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildDetailRow('Site', incident.siteId),
            _buildDetailRow('Severity', incident.severity.name.toUpperCase()),
            _buildDetailRow('Status', incident.status.name.toUpperCase()),
            _buildDetailRow('Reported', _formatTime(incident.reportedAt)),
            if (incident.description.isNotEmpty) _buildDetailRow('Description', incident.description),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Opening full incident report...')),
                      );
                    },
                    child: const Text('View Full Report'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(color: ScholesaColors.textSecondary)),
          const SizedBox(width: 16),
          Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500), textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final Duration diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
