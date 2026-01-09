import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';

class PartnerPayoutsScreen extends StatefulWidget {
  const PartnerPayoutsScreen({super.key});

  @override
  State<PartnerPayoutsScreen> createState() => _PartnerPayoutsScreenState();
}

class _PartnerPayoutsScreenState extends State<PartnerPayoutsScreen> {
  late Future<List<PayoutModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<PayoutModel>> _load() async {
    // Show pending approvals globally; adjust when contract context is available.
    return PayoutRepository().listPendingApproval(limit: 50);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payouts')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<PayoutModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final payouts = snapshot.data ?? <PayoutModel>[];
            if (payouts.isEmpty) {
              return const Center(child: Text('No payouts available.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: payouts.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final p = payouts[index];
                return ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: Text('${p.amount} ${p.currency}'),
                  subtitle: Text('Status: ${p.status} • Contract: ${p.contractId}'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
