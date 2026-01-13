import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/approval_service.dart';
import '../../services/telemetry_service.dart';
import '../../ui/theme/scholesa_theme.dart';

/// HQ Approvals page for approving partner contracts, marketplace listings, payouts
/// Based on docs/16_PARTNER_CONTRACTING_WORKFLOWS_SPEC.md
/// Wired to ApprovalService for live Firestore data
class HqApprovalsPage extends StatefulWidget {
  const HqApprovalsPage({super.key});

  @override
  State<HqApprovalsPage> createState() => _HqApprovalsPageState();
}

class _HqApprovalsPageState extends State<HqApprovalsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Load pending approvals on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ApprovalService>().loadAllPending();
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
        title: const Text('Approvals'),
        backgroundColor: ScholesaColors.hqGradient.colors.first,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<ApprovalService>().loadAllPending(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const <Widget>[
            Tab(text: 'Listings'),
            Tab(text: 'Contracts'),
            Tab(text: 'Payouts'),
          ],
        ),
      ),
      body: Consumer<ApprovalService>(
        builder: (BuildContext context, ApprovalService service, _) {
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
                    onPressed: () => service.loadAllPending(),
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
              _buildApprovalList(service.pendingListings, ApprovalType.listing),
              _buildApprovalList(service.pendingContracts, ApprovalType.contract),
              _buildApprovalList(service.pendingPayouts, ApprovalType.payout),
            ],
          );
        },
      ),
    );
  }

  Widget _buildApprovalList(List<ApprovalItem> items, ApprovalType type) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.green.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No pending ${type.name}s',
              style: const TextStyle(fontSize: 16, color: ScholesaColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<ApprovalService>().loadAllPending(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (BuildContext context, int index) => _buildApprovalCard(items[index]),
      ),
    );
  }

  Widget _buildApprovalCard(ApprovalItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: ScholesaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _buildTypeIcon(item.type),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      if (item.description != null)
                        Text(
                          item.description!,
                          style: const TextStyle(fontSize: 13, color: ScholesaColors.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                _buildWaitTimeBadge(item.waitTime),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleReject(item),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleApprove(item),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeIcon(ApprovalType type) {
    IconData icon;
    Color color;
    switch (type) {
      case ApprovalType.listing:
        icon = Icons.storefront_rounded;
        color = Colors.purple;
      case ApprovalType.contract:
        icon = Icons.handshake_rounded;
        color = Colors.blue;
      case ApprovalType.payout:
        icon = Icons.account_balance_rounded;
        color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildWaitTimeBadge(Duration waitTime) {
    String label;
    Color color;
    
    if (waitTime.inDays > 0) {
      label = '${waitTime.inDays}d';
      color = Colors.red;
    } else if (waitTime.inHours > 0) {
      label = '${waitTime.inHours}h';
      color = Colors.orange;
    } else {
      label = '${waitTime.inMinutes}m';
      color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
    );
  }

  Future<void> _handleApprove(ApprovalItem item) async {
    final ApprovalService service = context.read<ApprovalService>();
    final TelemetryService telemetry = context.read<TelemetryService>();
    bool success = false;

    switch (item.type) {
      case ApprovalType.listing:
        success = await service.approveListing(item.id);
        await telemetry.trackListingReviewed(listingId: item.id, decision: 'approved');
      case ApprovalType.contract:
        success = await service.approveContract(item.id);
        await telemetry.trackContractReviewed(contractId: item.id, decision: 'approved');
      case ApprovalType.payout:
        success = await service.approvePayout(item.id);
        final double amount = (item.metadata?['amount'] as num?)?.toDouble() ?? 0;
        await telemetry.trackPayoutReviewed(payoutId: item.id, decision: 'approved', amount: amount);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Approved: ${item.title}' : 'Failed to approve'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _handleReject(ApprovalItem item) async {
    // Show rejection reason dialog
    final String? reason = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        final TextEditingController controller = TextEditingController();
        return AlertDialog(
          title: const Text('Rejection Reason'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter reason for rejection (optional)',
            ),
            maxLines: 3,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (reason == null) return; // Cancelled

    final ApprovalService service = context.read<ApprovalService>();
    final TelemetryService telemetry = context.read<TelemetryService>();
    final String? rejectionReason = reason.isEmpty ? null : reason;
    bool success = false;

    switch (item.type) {
      case ApprovalType.listing:
        success = await service.rejectListing(item.id, reason: rejectionReason);
        await telemetry.trackListingReviewed(listingId: item.id, decision: 'rejected', reason: rejectionReason);
      case ApprovalType.contract:
        success = await service.rejectContract(item.id, reason: rejectionReason);
        await telemetry.trackContractReviewed(contractId: item.id, decision: 'rejected', reason: rejectionReason);
      case ApprovalType.payout:
        success = await service.rejectPayout(item.id, reason: rejectionReason);
        final double amount = (item.metadata?['amount'] as num?)?.toDouble() ?? 0;
        await telemetry.trackPayoutReviewed(payoutId: item.id, decision: 'rejected', amount: amount, reason: rejectionReason);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Rejected: ${item.title}' : 'Failed to reject'),
          backgroundColor: success ? Colors.orange : Colors.red,
        ),
      );
    }
  }
}
