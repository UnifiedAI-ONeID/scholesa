import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/audit_log_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

/// HQ Audit page for viewing audit logs and compliance reports
/// Based on docs/43_EXPORT_RETENTION_BACKUP_SPEC.md
/// Wired to AuditLogService for live Firestore data
class HqAuditPage extends StatefulWidget {
  const HqAuditPage({super.key});

  @override
  State<HqAuditPage> createState() => _HqAuditPageState();
}

class _HqAuditPageState extends State<HqAuditPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _filterAction;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Load audit logs on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final AuditLogService service = context.read<AuditLogService>();
      service.loadAuditLogs();
      service.loadExportRequests();
      service.loadDeletionRequests();
      
      // Track audit log view
      context.read<TelemetryService>().trackAuditLogViewed();
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
        title: const Text('Audit & Compliance'),
        backgroundColor: ScholesaColors.hqGradient.colors.first,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () => _showFilterDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              final AuditLogService service = context.read<AuditLogService>();
              service.loadAuditLogs();
              service.loadExportRequests();
              service.loadDeletionRequests();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const <Widget>[
            Tab(text: 'Audit Logs'),
            Tab(text: 'Exports'),
            Tab(text: 'Deletions'),
          ],
        ),
      ),
      body: Consumer<AuditLogService>(
        builder: (BuildContext context, AuditLogService service, _) {
          if (service.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (service.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.withValues(alpha: 0.7)),
                  const SizedBox(height: 16),
                  Text(service.error!, style: const TextStyle(color: ScholesaColors.textSecondary)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => service.loadAuditLogs(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: <Widget>[
              _buildAuditLogList(service),
              _buildExportRequestList(service),
              _buildDeletionRequestList(service),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAuditLogList(AuditLogService service) {
    final List<AuditLogEntry> logs = _filterAction != null
        ? service.logs.where((AuditLogEntry l) => l.action.contains(_filterAction!)).toList()
        : service.logs;

    if (logs.isEmpty) {
      return const Center(
        child: Text('No audit logs found', style: TextStyle(color: ScholesaColors.textSecondary)),
      );
    }

    return Column(
      children: <Widget>[
        _buildSummaryHeader(service),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => service.loadAuditLogs(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              itemBuilder: (BuildContext context, int index) => _buildAuditCard(logs[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryHeader(AuditLogService service) {
    final int authCount = service.logs.where((AuditLogEntry l) => l.action.startsWith('auth.')).length;
    final int dataCount = service.logs.where((AuditLogEntry l) => l.action.startsWith('data.')).length;
    final int adminCount = service.logs.where((AuditLogEntry l) => l.action.contains('admin') || l.action.contains('user')).length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: ScholesaColors.surface,
      child: Row(
        children: <Widget>[
          Expanded(child: _buildSummaryStat('Total', service.logs.length.toString(), Colors.blue)),
          Expanded(child: _buildSummaryStat('Auth', authCount.toString(), Colors.green)),
          Expanded(child: _buildSummaryStat('Data', dataCount.toString(), Colors.orange)),
          Expanded(child: _buildSummaryStat('Admin', adminCount.toString(), Colors.purple)),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, Color color) {
    return Column(
      children: <Widget>[
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: ScholesaColors.textSecondary)),
      ],
    );
  }

  Widget _buildAuditCard(AuditLogEntry log) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: _buildActionIcon(log.action),
        title: Text(log.action, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (log.targetType != null)
              Text('${log.targetType}: ${log.targetId ?? 'N/A'}', style: const TextStyle(fontSize: 12, color: ScholesaColors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              '${log.userId ?? 'System'} • ${_formatTime(log.timestamp)}',
              style: const TextStyle(fontSize: 11, color: ScholesaColors.textSecondary),
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () => _showLogDetails(log),
      ),
    );
  }

  Widget _buildActionIcon(String action) {
    IconData icon;
    Color color;

    if (action.startsWith('auth.')) {
      icon = Icons.login_rounded;
      color = Colors.green;
    } else if (action.contains('export') || action.contains('data')) {
      icon = Icons.storage_rounded;
      color = Colors.blue;
    } else if (action.contains('admin') || action.contains('user') || action.contains('role')) {
      icon = Icons.admin_panel_settings_rounded;
      color = Colors.orange;
    } else {
      icon = Icons.settings_rounded;
      color = Colors.purple;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildExportRequestList(AuditLogService service) {
    if (service.exports.isEmpty) {
      return const Center(
        child: Text('No export requests', style: TextStyle(color: ScholesaColors.textSecondary)),
      );
    }

    return RefreshIndicator(
      onRefresh: () => service.loadExportRequests(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: service.exports.length,
        itemBuilder: (BuildContext context, int index) => _buildExportCard(service.exports[index]),
      ),
    );
  }

  Widget _buildExportCard(ExportRequest request) {
    Color statusColor;
    switch (request.status) {
      case ExportStatus.completed:
        statusColor = Colors.green;
      case ExportStatus.processing:
        statusColor = Colors.blue;
      case ExportStatus.failed:
        statusColor = Colors.red;
      case ExportStatus.expired:
        statusColor = Colors.grey;
      case ExportStatus.pending:
        statusColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.download_rounded, color: statusColor, size: 20),
        ),
        title: Text(request.exportType, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${request.requestedBy ?? 'Unknown'} • ${_formatTime(request.requestedAt)}',
          style: const TextStyle(fontSize: 12, color: ScholesaColors.textSecondary),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(request.status.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: statusColor)),
        ),
      ),
    );
  }

  Widget _buildDeletionRequestList(AuditLogService service) {
    if (service.deletions.isEmpty) {
      return const Center(
        child: Text('No deletion requests', style: TextStyle(color: ScholesaColors.textSecondary)),
      );
    }

    return RefreshIndicator(
      onRefresh: () => service.loadDeletionRequests(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: service.deletions.length,
        itemBuilder: (BuildContext context, int index) => _buildDeletionCard(service.deletions[index], service),
      ),
    );
  }

  Widget _buildDeletionCard(DeletionRequest request, AuditLogService service) {
    Color statusColor;
    switch (request.stage) {
      case DeletionStage.softDelete:
        statusColor = Colors.orange;
      case DeletionStage.hardDeleteScheduled:
        statusColor = Colors.red;
      case DeletionStage.hardDeleteCompleted:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.delete_outline_rounded, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('${request.targetType}: ${request.targetId}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        '${request.requestedBy ?? 'Unknown'} • ${_formatTime(request.requestedAt)}',
                        style: const TextStyle(fontSize: 12, color: ScholesaColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(request.stage.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: statusColor)),
                ),
              ],
            ),
            if (request.legalHold) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.gavel_rounded, size: 16, color: Colors.red.shade700),
                    const SizedBox(width: 6),
                    Text('Legal Hold Active', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.red.shade700)),
                  ],
                ),
              ),
            ],
            if (!request.legalHold && request.stage == DeletionStage.softDelete) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  TextButton.icon(
                    onPressed: () => _setLegalHold(service, request.id, true),
                    icon: const Icon(Icons.gavel_rounded, size: 16),
                    label: const Text('Set Legal Hold'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _setLegalHold(AuditLogService service, String requestId, bool hold) async {
    final bool success = await service.setLegalHold(requestId, hold);
    
    // Track telemetry
    final TelemetryService telemetry = context.read<TelemetryService>();
    await telemetry.trackLegalHoldSet(requestId: requestId, isHeld: hold);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Legal hold ${hold ? 'set' : 'released'}' : 'Failed to update legal hold'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _showFilterDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: ScholesaColors.surface,
        title: const Text('Filter Audit Logs'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildFilterOption('All', null),
            _buildFilterOption('Auth Events', 'auth.'),
            _buildFilterOption('User/Role Events', 'user'),
            _buildFilterOption('Data Events', 'data'),
            _buildFilterOption('Admin Events', 'admin'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String label, String? filter) {
    return ListTile(
      title: Text(label),
      leading: Radio<String?>(
        value: filter,
        groupValue: _filterAction,
        onChanged: (String? value) {
          setState(() => _filterAction = value);
          Navigator.pop(context);
        },
      ),
      onTap: () {
        setState(() => _filterAction = filter);
        Navigator.pop(context);
      },
    );
  }

  void _showLogDetails(AuditLogEntry log) {
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
            Text(log.action, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildDetailRow('User', log.userId ?? 'System'),
            _buildDetailRow('Time', _formatTime(log.timestamp)),
            if (log.targetType != null) _buildDetailRow('Target Type', log.targetType!),
            if (log.targetId != null) _buildDetailRow('Target ID', log.targetId!),
            if (log.metadata != null && log.metadata!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              const Text('Metadata', style: TextStyle(fontWeight: FontWeight.w600, color: ScholesaColors.textSecondary)),
              const SizedBox(height: 4),
              Text(log.metadata.toString(), style: const TextStyle(fontSize: 12)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
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
        children: <Widget>[
          Text(label, style: const TextStyle(color: ScholesaColors.textSecondary)),
          Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500), textAlign: TextAlign.right)),
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
