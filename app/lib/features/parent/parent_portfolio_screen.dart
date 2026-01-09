import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';

class ParentPortfolioScreen extends StatefulWidget {
  const ParentPortfolioScreen({super.key});

  @override
  State<ParentPortfolioScreen> createState() => _ParentPortfolioScreenState();
}

class _ParentPortfolioScreenState extends State<ParentPortfolioScreen> {
  late Future<List<PortfolioItemModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  // TODO: replace hard-coded learner selection with actual linked learner(s) for the parent.
  Future<List<PortfolioItemModel>> _load() async {
    const learnerId = 'demo-learner';
    return PortfolioItemRepository().listByLearner(learnerId);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Portfolio Highlights')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<PortfolioItemModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data ?? <PortfolioItemModel>[];
            if (items.isEmpty) {
              return const Center(child: Text('No portfolio items available.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  leading: const Icon(Icons.photo_album),
                  title: Text(item.title ?? 'Item ${item.id}'),
                  subtitle: Text(item.description ?? ''),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
