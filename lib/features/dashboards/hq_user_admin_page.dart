import 'package:flutter/material.dart';

import 'hq_user_admin_service.dart';

const String buildTag = '2026-01-05c';

class HqUserAdminPage extends StatefulWidget {
  const HqUserAdminPage({super.key});

  @override
  State<HqUserAdminPage> createState() => _HqUserAdminPageState();
}

class _HqUserAdminPageState extends State<HqUserAdminPage> {
  final HqUserAdminService service = HqUserAdminService();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController siteController = TextEditingController();

  bool loading = false;
  String? error;
  String? roleFilter;
  List<AdminUser> users = <AdminUser>[];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    emailController.dispose();
    siteController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final List<AdminUser> fetched = await service.fetchUsers(
        role: roleFilter,
        siteId: siteController.text.trim().isEmpty ? null : siteController.text.trim(),
        email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
      );
      setState(() => users = fetched);
    } catch (e) {
      setState(() => error = 'Failed to load users: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _resetPassword(String email) async {
    try {
      final String link = await service.sendReset(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(link.isNotEmpty ? 'Reset link generated' : 'Reset link requested')), // minimal hint
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset failed: $e')),
      );
    }
  }

  Future<void> _editUser(AdminUser user) async {
    final roleController = ValueNotifier<String?>(user.role);
    final sitesController = TextEditingController(text: user.siteIds.join(','));
    final activeSiteController = TextEditingController(text: user.activeSiteId ?? '');
    bool isActive = user.isActive ?? true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(user.email ?? user.id, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Tooltip(
                message: 'Assign platform role',
                child: DropdownButtonFormField<String>(
                  value: roleController.value,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'learner', child: Text('Learner')),
                    DropdownMenuItem(value: 'educator', child: Text('Educator')),
                    DropdownMenuItem(value: 'parent', child: Text('Parent')),
                    DropdownMenuItem(value: 'site', child: Text('Site Lead')),
                    DropdownMenuItem(value: 'partner', child: Text('Partner')),
                    DropdownMenuItem(value: 'hq', child: Text('HQ')),
                  ],
                  onChanged: (value) => setState(() => roleController.value = value),
                ),
              ),
              const SizedBox(height: 8),
              Tooltip(
                message: 'Comma-separated site IDs',
                child: TextField(
                  controller: sitesController,
                  decoration: const InputDecoration(labelText: 'Site IDs (comma separated)'),
                ),
              ),
              const SizedBox(height: 8),
              Tooltip(
                message: 'Active site must be in Site IDs',
                child: TextField(
                  controller: activeSiteController,
                  decoration: const InputDecoration(labelText: 'Active siteId'),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: isActive,
                title: const Text('Active user'),
                onChanged: (value) => setState(() => isActive = value),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final newSites = sitesController.text
                        .split(',')
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty)
                        .toList();
                    try {
                      await service.updateUser(
                        uid: user.id,
                        role: roleController.value,
                        siteIds: newSites,
                        activeSiteId: activeSiteController.text.trim().isEmpty
                            ? null
                            : activeSiteController.text.trim(),
                        isActive: isActive,
                      );
                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('User updated')),
                      );
                      await _loadUsers();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Update failed: $e')),
                      );
                    }
                  },
                  child: const Text('Save changes'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Administration'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                SizedBox(
                  width: 220,
                  child: Tooltip(
                    message: 'Filter by email',
                    child: TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: Tooltip(
                    message: 'Filter by site ID',
                    child: TextField(
                      controller: siteController,
                      decoration: const InputDecoration(labelText: 'Site ID'),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: Tooltip(
                    message: 'Filter by role',
                    child: DropdownButtonFormField<String?>(
                      value: roleFilter,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: const <DropdownMenuItem<String?>>[
                        DropdownMenuItem(value: null, child: Text('Any')),
                        DropdownMenuItem(value: 'learner', child: Text('Learner')),
                        DropdownMenuItem(value: 'educator', child: Text('Educator')),
                        DropdownMenuItem(value: 'parent', child: Text('Parent')),
                        DropdownMenuItem(value: 'site', child: Text('Site Lead')),
                        DropdownMenuItem(value: 'partner', child: Text('Partner')),
                        DropdownMenuItem(value: 'hq', child: Text('HQ')),
                      ],
                      onChanged: (String? value) => setState(() => roleFilter = value),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: loading ? null : _loadUsers,
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
                ),
                TextButton(
                  onPressed: loading
                      ? null
                      : () {
                          emailController.clear();
                          siteController.clear();
                          setState(() => roleFilter = null);
                          _loadUsers();
                        },
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            if (loading) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Expanded(
              child: users.isEmpty && !loading
                  ? const Center(child: Text('No users found'))
                  : ListView.separated(
                      itemCount: users.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final AdminUser user = users[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(user.email ?? user.id),
                            subtitle: Text('Role: ${user.role ?? 'unknown'} • Sites: ${user.siteIds.join(', ')}'),
                            trailing: Wrap(
                              spacing: 8,
                              children: <Widget>[
                                Tooltip(
                                  message: 'Edit role and site access',
                                  child: IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _editUser(user),
                                  ),
                                ),
                                if (user.email != null)
                                  Tooltip(
                                    message: 'Send password reset link',
                                    child: IconButton(
                                      icon: const Icon(Icons.lock_reset),
                                      onPressed: () => _resetPassword(user.email!),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Text('Build: $buildTag', style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
