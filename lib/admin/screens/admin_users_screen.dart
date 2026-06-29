// =============================================================================
// ExamVault - Admin Users Management Screen (offline)
// =============================================================================

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/local_data_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late List<LocalUser> _items;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _items = LocalDataService.getAllUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        automaticallyImplyLeading: false,
      ),
      body: _items.isEmpty
          ? const Center(child: Text('No users'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final u = _items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: u.isPremium
                          ? AppTheme.accentColor.withOpacity(0.15)
                          : AppTheme.primaryColor.withOpacity(0.15),
                      child: const Icon(Icons.person),
                    ),
                    title: Row(
                      children: [
                        Text(u.name),
                        const SizedBox(width: 8),
                        if (u.role == 'admin')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'ADMIN',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        if (u.isPremium) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'PREMIUM',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                        '${u.email ?? "—"} • ${u.phone ?? "—"} • Created ${u.createdAt.day}/${u.createdAt.month}/${u.createdAt.year}'),
                    trailing: PopupMenuButton(
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                            value: 'toggle', child: Text('Toggle Premium')),
                        const PopupMenuItem(
                            value: 'delete', child: Text('Delete User')),
                      ],
                      onSelected: (value) async {
                        if (value == 'toggle') {
                          await LocalDataService.toggleUserPremium(u.id);
                          setState(_reload);
                        } else if (value == 'delete') {
                          if (u.role == 'admin') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Cannot delete the admin account.')),
                            );
                            return;
                          }
                          await LocalDataService.deleteUser(u.id);
                          setState(_reload);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
