// =============================================================================
// ExamVault - Admin Announcements CRUD Screen
// Admin creates announcements → users see them in Home ticker + dedicated page
// =============================================================================

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/announcement_model.dart';
import '../../services/firestore_service.dart';

class AdminAnnouncementsScreen extends StatelessWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<List<AnnouncementModel>>(
        stream: FirestoreService.getAllAnnouncementsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No announcements yet.\nTap + to add one.',
                  textAlign: TextAlign.center),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final a = snapshot.data![index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _typeColor(a.type).withOpacity(0.15),
                    child: Icon(_typeIcon(a.type), color: _typeColor(a.type)),
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (a.isPinned)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.push_pin, size: 16, color: Colors.orange),
                        ),
                      if (!a.isPublished)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Draft', style: TextStyle(fontSize: 10)),
                        ),
                    ],
                  ),
                  subtitle: Text(a.message, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'pin', child: Text('Toggle Pin')),
                      const PopupMenuItem(value: 'publish', child: Text('Toggle Publish')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                    onSelected: (value) async {
                      if (value == 'edit') {
                        _showAddEditDialog(context, announcement: a);
                      } else if (value == 'pin') {
                        await FirestoreService.updateAnnouncement(
                          AnnouncementModel(
                            id: a.id,
                            title: a.title,
                            message: a.message,
                            type: a.type,
                            imageUrl: a.imageUrl,
                            link: a.link,
                            linkLabel: a.linkLabel,
                            isPinned: !a.isPinned,
                            isPublished: a.isPublished,
                            order: a.order,
                            expiresAt: a.expiresAt,
                            createdAt: a.createdAt,
                            updatedAt: DateTime.now(),
                          ),
                        );
                      } else if (value == 'publish') {
                        await FirestoreService.updateAnnouncement(
                          AnnouncementModel(
                            id: a.id,
                            title: a.title,
                            message: a.message,
                            type: a.type,
                            imageUrl: a.imageUrl,
                            link: a.link,
                            linkLabel: a.linkLabel,
                            isPinned: a.isPinned,
                            isPublished: !a.isPublished,
                            order: a.order,
                            expiresAt: a.expiresAt,
                            createdAt: a.createdAt,
                            updatedAt: DateTime.now(),
                          ),
                        );
                      } else if (value == 'delete') {
                        _confirmDelete(context, a);
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _typeColor(AnnouncementType t) {
    switch (t) {
      case AnnouncementType.success: return Colors.green;
      case AnnouncementType.warning: return Colors.orange;
      case AnnouncementType.error: return Colors.red;
      case AnnouncementType.promo: return AppTheme.accentColor;
      default: return AppTheme.primaryColor;
    }
  }

  IconData _typeIcon(AnnouncementType t) {
    switch (t) {
      case AnnouncementType.success: return Icons.check_circle_outline;
      case AnnouncementType.warning: return Icons.warning_amber;
      case AnnouncementType.error: return Icons.error_outline;
      case AnnouncementType.promo: return Icons.local_offer;
      default: return Icons.info_outline;
    }
  }

  void _showAddEditDialog(BuildContext context, {AnnouncementModel? announcement}) {
    final titleCtrl = TextEditingController(text: announcement?.title ?? '');
    final messageCtrl = TextEditingController(text: announcement?.message ?? '');
    final linkCtrl = TextEditingController(text: announcement?.link ?? '');
    final linkLabelCtrl = TextEditingController(text: announcement?.linkLabel ?? '');
    final orderCtrl = TextEditingController(text: (announcement?.order ?? 0).toString());
    AnnouncementType selectedType = announcement?.type ?? AnnouncementType.info;
    bool isPinned = announcement?.isPinned ?? false;
    bool isPublished = announcement?.isPublished ?? true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text(announcement == null ? 'Add Announcement' : 'Edit Announcement'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: messageCtrl,
                    decoration: const InputDecoration(labelText: 'Message *'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AnnouncementType>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: AnnouncementType.info, child: Text('Info')),
                      DropdownMenuItem(value: AnnouncementType.success, child: Text('Success')),
                      DropdownMenuItem(value: AnnouncementType.warning, child: Text('Warning')),
                      DropdownMenuItem(value: AnnouncementType.error, child: Text('Error')),
                      DropdownMenuItem(value: AnnouncementType.promo, child: Text('Promo')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => selectedType = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: linkCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Link URL (optional)',
                      hintText: 'https://...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: linkLabelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Link button text (optional)',
                      hintText: 'Apply Now',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: orderCtrl,
                    decoration: const InputDecoration(labelText: 'Order (lower = first)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Pin to top'),
                    value: isPinned,
                    onChanged: (v) => setState(() => isPinned = v),
                  ),
                  SwitchListTile(
                    title: const Text('Published'),
                    value: isPublished,
                    onChanged: (v) => setState(() => isPublished = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty || messageCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Title and message are required')),
                    );
                    return;
                  }
                  final now = DateTime.now();
                  final model = AnnouncementModel(
                    id: announcement?.id ?? '',
                    title: titleCtrl.text.trim(),
                    message: messageCtrl.text.trim(),
                    type: selectedType,
                    link: linkCtrl.text.trim().isEmpty ? null : linkCtrl.text.trim(),
                    linkLabel: linkLabelCtrl.text.trim().isEmpty ? null : linkLabelCtrl.text.trim(),
                    isPinned: isPinned,
                    isPublished: isPublished,
                    order: int.tryParse(orderCtrl.text) ?? 0,
                    createdAt: announcement?.createdAt ?? now,
                    updatedAt: now,
                  );
                  if (announcement == null) {
                    await FirestoreService.addAnnouncement(model);
                  } else {
                    await FirestoreService.updateAnnouncement(model);
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  void _confirmDelete(BuildContext context, AnnouncementModel a) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Announcement?'),
          content: Text('Are you sure you want to delete "${a.title}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
              onPressed: () async {
                await FirestoreService.deleteAnnouncement(a.id);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
