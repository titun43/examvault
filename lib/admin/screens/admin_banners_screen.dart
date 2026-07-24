// =============================================================================
// ExamVault - Admin Banners CRUD Screen
// Admin uploads a banner image + optional link → users see carousel on Home.
// Image is uploaded to Firebase Storage under /banner_images.
// =============================================================================

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import '../../models/banner_model.dart';
import '../../services/firestore_service.dart';
import '../../services/firebase_service.dart';

class AdminBannersScreen extends StatelessWidget {
  const AdminBannersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Banners'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<List<BannerModel>>(
        stream: FirestoreService.getAllBannersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No banners yet.\nTap + to add one.',
                  textAlign: TextAlign.center),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
            ),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final b = snapshot.data![index];
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final placeholderBg = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: b.imageUrl.isEmpty
                        ? Container(
                            color: placeholderBg,
                            child: const Center(child: Icon(Icons.image, size: 40)),
                          )
                        : CachedNetworkImage(
                            imageUrl: b.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            placeholder: (_, __) => Container(
                              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: placeholderBg,
                              child: const Center(child: Icon(Icons.broken_image, size: 40)),
                            ),
                          ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: b.isActive ? Colors.green : Colors.grey,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        b.isActive ? 'Active' : 'Inactive',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              b.title,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          PopupMenuButton(
                            icon: const Icon(Icons.more_vert, color: Colors.white, size: 18),
                            padding: EdgeInsets.zero,
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              const PopupMenuItem(value: 'toggle', child: Text('Toggle Active')),
                              const PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                            onSelected: (value) async {
                              if (value == 'edit') {
                                _showAddEditDialog(context, banner: b);
                              } else if (value == 'toggle') {
                                await FirestoreService.updateBanner(BannerModel(
                                  id: b.id,
                                  title: b.title,
                                  subtitle: b.subtitle,
                                  imageUrl: b.imageUrl,
                                  link: b.link,
                                  linkLabel: b.linkLabel,
                                  order: b.order,
                                  isActive: !b.isActive,
                                  startsAt: b.startsAt,
                                  endsAt: b.endsAt,
                                  createdAt: b.createdAt,
                                  updatedAt: DateTime.now(),
                                ));
                              } else if (value == 'delete') {
                                _confirmDelete(context, b);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showAddEditDialog(BuildContext context, {BannerModel? banner}) {
    final titleCtrl = TextEditingController(text: banner?.title ?? '');
    final subtitleCtrl = TextEditingController(text: banner?.subtitle ?? '');
    final linkCtrl = TextEditingController(text: banner?.link ?? '');
    final linkLabelCtrl = TextEditingController(text: banner?.linkLabel ?? '');
    final orderCtrl = TextEditingController(text: (banner?.order ?? 0).toString());
    String? imageUrl = banner?.imageUrl;
    bool isActive = banner?.isActive ?? true;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            title: Text(banner == null ? 'Add Banner' : 'Edit Banner'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image picker preview
                  GestureDetector(
                    onTap: isUploading
                        ? null
                        : () async {
                            final picker = ImagePicker();
                            final xfile = await picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 80,
                            );
                            if (xfile == null) return;
                            setState(() => isUploading = true);
                            try {
                              final fileName =
                                  'banner_${DateTime.now().millisecondsSinceEpoch}.jpg';
                              final ref = FirebaseService.storage
                                  .ref()
                                  .child('banner_images')
                                  .child(fileName);
                              // Web returns bytes; mobile returns a File path.
                              if (kIsWeb) {
                                final bytes = await xfile.readAsBytes();
                                await ref.putData(bytes,
                                    SettableMetadata(contentType: 'image/jpeg'));
                              } else {
                                await ref.putFile(File(xfile.path));
                              }
                              final url = await ref.getDownloadURL();
                              setState(() {
                                imageUrl = url;
                                isUploading = false;
                              });
                            } catch (e) {
                              setState(() => isUploading = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Upload failed: $e')),
                                );
                              }
                            }
                          },
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                      ),
                      child: isUploading
                          ? const Center(child: CircularProgressIndicator())
                          : (imageUrl != null && imageUrl!.isNotEmpty)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: imageUrl!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate,
                                        size: 40, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500),
                                    const SizedBox(height: 8),
                                    Text('Tap to upload banner image',
                                        style: TextStyle(
                                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                            fontSize: 12)),
                                  ],
                                ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subtitleCtrl,
                    decoration: const InputDecoration(labelText: 'Subtitle (optional)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: linkCtrl,
                    decoration: const InputDecoration(labelText: 'Link URL (optional)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: linkLabelCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Link button text (optional)',
                        hintText: 'Apply Now'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: orderCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Order (lower = shown first)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (v) => setState(() => isActive = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Title is required')),
                    );
                    return;
                  }
                  if (imageUrl == null || imageUrl!.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please upload a banner image')),
                    );
                    return;
                  }
                  final now = DateTime.now();
                  final model = BannerModel(
                    id: banner?.id ?? '',
                    title: titleCtrl.text.trim(),
                    subtitle: subtitleCtrl.text.trim().isEmpty ? null : subtitleCtrl.text.trim(),
                    imageUrl: imageUrl!,
                    link: linkCtrl.text.trim().isEmpty ? null : linkCtrl.text.trim(),
                    linkLabel: linkLabelCtrl.text.trim().isEmpty
                        ? null
                        : linkLabelCtrl.text.trim(),
                    order: int.tryParse(orderCtrl.text) ?? 0,
                    isActive: isActive,
                    startsAt: banner?.startsAt,
                    endsAt: banner?.endsAt,
                    createdAt: banner?.createdAt ?? now,
                    updatedAt: now,
                  );
                  if (banner == null) {
                    await FirestoreService.addBanner(model);
                  } else {
                    await FirestoreService.updateBanner(model);
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

  void _confirmDelete(BuildContext context, BannerModel b) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Banner?'),
          content: Text('Are you sure you want to delete "${b.title}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
              onPressed: () async {
                await FirestoreService.deleteBanner(b.id);
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
