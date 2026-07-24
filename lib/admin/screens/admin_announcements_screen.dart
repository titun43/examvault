// =============================================================================
// ExamVault - Admin Announcements CRUD Screen
// Admin creates announcements → users see them in Home ticker + dedicated page
// =============================================================================

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/announcement_model.dart';
import '../../models/action_button.dart';
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
          if (snapshot.hasError) {
            return _ErrorState(message: snapshot.error.toString());
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
                        const _DraftBadge(),
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
                        await _safeUpdate(
                          context,
                          a.copyWith(isPinned: !a.isPinned),
                        );
                      } else if (value == 'publish') {
                        await _safeUpdate(
                          context,
                          a.copyWith(isPublished: !a.isPublished),
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
    // Assamese bilingual fields — preserve when editing.
    final titleAsCtrl =
        TextEditingController(text: announcement?.titleAs ?? '');
    final messageAsCtrl =
        TextEditingController(text: announcement?.messageAs ?? '');
    final linkCtrl = TextEditingController(text: announcement?.link ?? '');
    final linkLabelCtrl = TextEditingController(text: announcement?.linkLabel ?? '');
    final imageUrlCtrl =
        TextEditingController(text: announcement?.imageUrl ?? '');
    final orderCtrl = TextEditingController(text: (announcement?.order ?? 0).toString());
    AnnouncementType selectedType = announcement?.type ?? AnnouncementType.info;
    bool isPinned = announcement?.isPinned ?? false;
    bool isPublished = announcement?.isPublished ?? true;
    // Preserve the existing expiry when editing (nullable).
    DateTime? expiresAt = announcement?.expiresAt;

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
                  TextField(
                    controller: titleAsCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Title (Assamese, optional)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: messageAsCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Message (Assamese, optional)'),
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
                    controller: imageUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Image URL (optional)',
                      hintText: 'https://...',
                    ),
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
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Expiry date (optional)'),
                    subtitle: Text(expiresAt == null
                        ? 'Never expires'
                        : '${expiresAt!.day}/${expiresAt!.month}/${expiresAt!.year}'),
                    trailing: expiresAt == null
                        ? const Icon(Icons.add_circle_outline)
                        : const Icon(Icons.clear),
                    onTap: () async {
                      if (expiresAt != null) {
                        setState(() => expiresAt = null);
                        return;
                      }
                      final d = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setState(() => expiresAt = d);
                    },
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
                  // IMPORTANT: preserve ALL fields that aren't edited in this
                  // dialog (primaryButton, secondaryButton) from the existing
                  // announcement. Previously editing wiped these silently.
                  final model = AnnouncementModel(
                    id: announcement?.id ?? '',
                    title: titleCtrl.text.trim(),
                    message: messageCtrl.text.trim(),
                    titleAs: titleAsCtrl.text.trim().isEmpty
                        ? null
                        : titleAsCtrl.text.trim(),
                    messageAs: messageAsCtrl.text.trim().isEmpty
                        ? null
                        : messageAsCtrl.text.trim(),
                    type: selectedType,
                    imageUrl: imageUrlCtrl.text.trim().isEmpty
                        ? null
                        : imageUrlCtrl.text.trim(),
                    link: linkCtrl.text.trim().isEmpty ? null : linkCtrl.text.trim(),
                    linkLabel: linkLabelCtrl.text.trim().isEmpty ? null : linkLabelCtrl.text.trim(),
                    // Preserve existing action buttons (not edited here).
                    primaryButton: announcement?.primaryButton,
                    secondaryButton: announcement?.secondaryButton,
                    isPinned: isPinned,
                    isPublished: isPublished,
                    order: int.tryParse(orderCtrl.text) ?? 0,
                    expiresAt: expiresAt,
                    createdAt: announcement?.createdAt ?? now,
                    updatedAt: now,
                  );
                  Navigator.pop(context); // close dialog first
                  await _safeUpdate(context, model, isCreate: announcement == null);
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  /// Wraps a Firestore write in try/catch and shows a SnackBar on failure.
  /// Avoids leaving the user with no feedback when a save fails.
  Future<void> _safeUpdate(BuildContext context, AnnouncementModel model,
      {bool isCreate = false}) async {
    try {
      if (isCreate) {
        await FirestoreService.addAnnouncement(model);
      } else {
        await FirestoreService.updateAnnouncement(model);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isCreate ? 'Announcement created' : 'Announcement updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
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
                Navigator.pop(context); // close confirm dialog
                try {
                  await FirestoreService.deleteAnnouncement(a.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Announcement deleted')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete: $e')),
                    );
                  }
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

/// Dark-mode-aware "Draft" badge — used by announcements + upcoming exams.
/// Uses a muted amber background so the badge stays readable in both themes
/// (the old `Colors.grey.shade300` was invisible in dark mode).
class _DraftBadge extends StatelessWidget {
  const _DraftBadge();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.warningColor.withOpacity(0.22)
            : AppTheme.warningColor.withOpacity(0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Draft',
        style: TextStyle(
          fontSize: 10,
          color: isDark ? AppTheme.warningColor : AppTheme.warningColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Generic error state widget for StreamBuilders.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off,
                size: 56,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(
              'Failed to load',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade200 : Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// extension to copy-with an AnnouncementModel preserving fields.
/// AnnouncementModel has no copyWith, so we define one locally to keep the
/// toggle handlers (pin/publish) from wiping bilingual + button fields.
extension _AnnouncementCopyWith on AnnouncementModel {
  AnnouncementModel copyWith({
    String? title,
    String? message,
    String? titleAs,
    String? messageAs,
    AnnouncementType? type,
    String? imageUrl,
    String? link,
    String? linkLabel,
    ActionButton? primaryButton,
    ActionButton? secondaryButton,
    bool? isPinned,
    bool? isPublished,
    int? order,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    // Sentinels to allow setting nullable fields back to null explicitly.
    bool clearImageUrl = false,
    bool clearLink = false,
    bool clearLinkLabel = false,
    bool clearPrimaryButton = false,
    bool clearSecondaryButton = false,
    bool clearExpiresAt = false,
    bool clearTitleAs = false,
    bool clearMessageAs = false,
  }) {
    return AnnouncementModel(
      id: id,
      title: title ?? this.title,
      message: message ?? this.message,
      titleAs: clearTitleAs ? null : (titleAs ?? this.titleAs),
      messageAs: clearMessageAs ? null : (messageAs ?? this.messageAs),
      type: type ?? this.type,
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      link: clearLink ? null : (link ?? this.link),
      linkLabel: clearLinkLabel ? null : (linkLabel ?? this.linkLabel),
      primaryButton:
          clearPrimaryButton ? null : (primaryButton ?? this.primaryButton),
      secondaryButton: clearSecondaryButton
          ? null
          : (secondaryButton ?? this.secondaryButton),
      isPinned: isPinned ?? this.isPinned,
      isPublished: isPublished ?? this.isPublished,
      order: order ?? this.order,
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
