// =============================================================================
// ExamVault - Study Material List Screen
// =============================================================================
// Shows all published study materials of a SPECIFIC TYPE for a subject.
// Examples:
//   - "Previous Papers in History" → list of all previousPaper PDFs
//   - "Study Notes in History" → list of all notes PDFs
//   - "Syllabus in History" → list of syllabus PDFs
//
// Real-time: if the admin adds/removes a material while the user is viewing
// this list, the list updates immediately (Firestore snapshots stream).
//
// Premium gating: materials with isPremium=true show a 👑 lock badge. When a
// non-premium user taps a premium material, a paywall dialog is shown.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/study_material_model.dart';
import '../../models/subject_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/offline_aware_stream_builder.dart';
import 'pdf_viewer_screen.dart';
import '../auth/login_screen.dart';
import '../premium/premium_screen.dart';

class MaterialListScreen extends StatefulWidget {
  final SubjectModel subject;
  final StudyMaterialType type;

  const MaterialListScreen({
    super.key,
    required this.subject,
    required this.type,
  });

  @override
  State<MaterialListScreen> createState() => _MaterialListScreenState();
}

class _MaterialListScreenState extends State<MaterialListScreen> {
  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    return Scaffold(
      appBar: AppBar(
        title: Text(type.label),
        actions: [
          // Quick subject indicator in the app bar
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                widget.subject.name,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header strip with subject info + count
          _buildHeader(),
          // Material list
          Expanded(
            child: OfflineAwareStreamBuilder<List<StudyMaterialModel>>(
              stream: FirestoreService.getStudyMaterialsByTypeStream(
                widget.subject.id,
                type,
              ),
              loadingBuilder: (_) => _buildShimmerList(),
              emptyBuilder: (_, retry) => _buildEmptyState(retry),
              offlineBuilder: (_, retry) => _buildOfflineState(retry),
              errorBuilder: (_, error, retry) => _buildErrorState(error, retry),
              dataBuilder: (context, materials, isStale) =>
                  _buildMaterialList(materials, isStale),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            AppTheme.primaryColor.withOpacity(0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.primaryColor.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                widget.type.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.subject.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.type.emoji} ${widget.type.label}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialList(List<StudyMaterialModel> materials, bool isStale) {
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: materials.length,
          itemBuilder: (context, index) =>
              _buildMaterialCard(materials[index]),
        ),
        if (isStale) _buildStaleBanner(),
      ],
    );
  }

  Widget _buildMaterialCard(StudyMaterialModel material) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _onMaterialTap(material),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // PDF icon / thumbnail
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _typeColor(material.type).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.picture_as_pdf,
                  color: Colors.red,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              // Title + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            material.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (material.isPremium) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.workspace_premium,
                            size: 18,
                            color: Color(0xFFFF6F00),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (material.year != null)
                          _buildMetaChip('${material.year}'),
                        if (material.pages != null)
                          _buildMetaChip('${material.pages} pages'),
                        _buildMetaChip(
                          material.isPremium ? 'Premium' : 'Free',
                          isPremium: material.isPremium,
                        ),
                      ],
                    ),
                    if (material.description != null &&
                        material.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        material.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: Colors.grey,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip(String text, {bool isPremium = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPremium
            ? const Color(0xFFFF6F00).withOpacity(0.15)
            : Colors.grey.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isPremium
              ? const Color(0xFFFF6F00)
              : Colors.grey[700],
        ),
      ),
    );
  }

  void _onMaterialTap(StudyMaterialModel material) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // If not logged in → prompt login.
    if (auth.user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    // Premium gate: if material is premium and user is not premium → paywall.
    if (material.isPremium && !_isUserPremium(auth.user)) {
      _showPaywallDialog(material);
      return;
    }

    // All checks passed → open the PDF viewer.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          pdfUrl: material.pdfUrl,
          title: material.title,
          materialId: material.id,
        ),
      ),
    );

    // Fire-and-forget analytics: increment download count.
    FirestoreService.incrementMaterialDownloadCount(material.id);
  }

  bool _isUserPremium(UserModel? user) {
    if (user == null) return false;
    // SubscriptionStatus is an enum (free / premium / expired). Admin users
    // (UserRole.admin) also get full premium access.
    return user.subscriptionStatus == SubscriptionStatus.premium ||
        user.role == UserRole.admin;
  }

  void _showPaywallDialog(StudyMaterialModel material) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Color(0xFFFF6F00), size: 28),
            SizedBox(width: 8),
            Text('Premium Content'),
          ],
        ),
        content: Text(
          '"${material.title}" is a premium study material. '
          'Upgrade to ExamVault Premium to access all papers, notes, and syllabi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Maybe later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6F00),
            ),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  Color _typeColor(StudyMaterialType type) {
    switch (type) {
      case StudyMaterialType.previousPaper:
        return const Color(0xFF1565C0);
      case StudyMaterialType.notes:
        return const Color(0xFF388E3C);
      case StudyMaterialType.syllabus:
        return const Color(0xFFF57C00);
    }
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(VoidCallback retry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.type.emoji,
              style: const TextStyle(fontSize: 56),
            ),
            const SizedBox(height: 16),
            Text(
              'No ${widget.type.pluralLabel} available yet',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'New content will appear here automatically '
              'when the admin adds it.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineState(VoidCallback retry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'You are offline',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connect to the internet to load study materials.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error, VoidCallback retry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaleBanner() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: Colors.orange.withOpacity(0.9),
        child: const Row(
          children: [
            Icon(Icons.cloud_off, size: 16, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Showing cached content (offline)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
