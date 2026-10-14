// =============================================================================
// ExamVault - My Purchases Screen
// =============================================================================
// User dashboard showing all their purchases (premium subscription, exam
// packs, subject packs, individual tests) and recent payment history with
// invoice download. Data is fetched from GET /api/user/purchases on the
// admin panel origin. If the endpoint is not built yet (404), a friendly
// "rolling out" message is shown instead of crashing.
// =============================================================================

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/access_service.dart';
import '../../services/payment_api_service.dart';
import '../../services/firestore_service.dart';
import '../../models/test_model.dart';
import '../../models/category_model.dart';
import '../../models/subject_model.dart';
import '../../theme/app_theme.dart';
import '../tests/test_instructions_screen.dart';
import '../tests/test_list_screen.dart';
import '../home/category_detail_screen.dart';

class MyPurchasesScreen extends StatefulWidget {
  const MyPurchasesScreen({super.key});

  @override
  State<MyPurchasesScreen> createState() => _MyPurchasesScreenState();
}

class _MyPurchasesScreenState extends State<MyPurchasesScreen> {
  // Purchase payload from GET /api/user/purchases. May be null while loading
  // or if the endpoint 404s (backend not built yet).
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  bool _isCancelling = false;
  String? _error; // friendly message shown in the body

  // Issue #22: guards the invoice download + open flow so a user can't tap
  // multiple invoice buttons simultaneously and pile up concurrent fetches.
  bool _isDownloadingInvoice = false;

  @override
  void initState() {
    super.initState();
    _fetchPurchases();
  }

  Future<void> _fetchPurchases() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await PaymentApiService.getUserPurchases();
      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } on PaymentApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load purchases. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelSubscription() async {
    // Confirm before cancelling.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Premium?'),
        content: const Text(
          'Your premium subscription will remain active until the end of the '
          'current billing period, but will not renew. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Premium'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isCancelling = true);
    try {
      await PaymentApiService.cancelSubscription();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subscription cancelled. It will not renew.'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      // Refresh + clear cached access decisions.
      AccessService.clearCache();
      await _fetchPurchases();
      // Refresh the user in AuthProvider so isPremium updates UI-wide.
      if (mounted) {
        Provider.of<AuthProvider>(context, listen: false).loadUserData();
      }
    } on PaymentApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.errorColor),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not cancel subscription. Please try again.'),
            backgroundColor: AppTheme.errorColor),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _openInvoice(String paymentId) async {
    // Issue #22: the invoice endpoint requires a Bearer JWT — url_launcher
    // can't attach auth headers, so the old approach 401'd. Now we fetch
    // the PDF bytes with the user's Firebase ID token, write them to a
    // temp file, and open the file:// URI via url_launcher (the system's
    // native PDF viewer handles rendering). This is the robust option (a)
    // from the task spec.
    if (_isDownloadingInvoice) return;
    setState(() => _isDownloadingInvoice = true);
    final messenger = ScaffoldMessenger.of(context);
    // Show a non-blocking loading SnackBar so the user knows something is
    // happening (the download can take a few seconds on slow networks).
    messenger.showSnackBar(
      SnackBar(
        content: L10nText('invoice_downloading'),
        duration: const Duration(seconds: 30),
      ),
    );
    try {
      final url = await PaymentApiService.getInvoiceUrl(paymentId);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: L10nText('invoice_download_failed'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
      final String token;
      try {
        token = (await user.getIdToken())!;
      } catch (_) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: L10nText('invoice_download_failed'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }

      // Fetch the PDF bytes with the Bearer token attached.
      final http.Response res = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: L10nText('invoice_download_failed'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }

      // Write the bytes to a temp file named by paymentId (deterministic —
      // re-downloading the same invoice overwrites instead of piling up
      // orphan files in the cache dir).
      final Uint8List bytes = res.bodyBytes;
      final dir = await getTemporaryDirectory();
      final String filePath = '${dir.path}/invoice_$paymentId.pdf';
      final File file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      // Open the file:// URI via url_launcher. On Android 11+ this may
      // require a <queries> element in AndroidManifest for canLaunchUrl to
      // return true; we skip the canLaunchUrl check and just try launchUrl
      // directly (it throws on failure, which we catch).
      messenger.hideCurrentSnackBar();
      final fileUri = Uri.file(filePath);
      bool opened = false;
      try {
        opened = await launchUrl(fileUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        opened = false;
      }
      if (!mounted) return;
      if (opened) {
        messenger.showSnackBar(
          SnackBar(
            content: L10nText('invoice_download_success'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else {
        // The download succeeded but url_launcher couldn't hand off to a
        // PDF viewer. Tell the user where the file is so they can open it
        // from their Files app.
        messenger.showSnackBar(
          SnackBar(
            content: L10nText('invoice_open_failed'),
            backgroundColor: AppTheme.warningColor,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      messenger.hideCurrentSnackBar();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: L10nText('invoice_download_failed'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDownloadingInvoice = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Navigation helpers — navigate to category / subject from purchased packs
  // ---------------------------------------------------------------------------

  /// Tap on an exam pack → navigate to that category's detail screen so the
  /// user can start any test they've unlocked.
  Future<void> _openCategory(String categoryId, String packName) async {
    if (categoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category info not available. Try refreshing.')),
      );
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Opening category…'),
          ]),
        ),
      ),
    );
    try {
      // Try direct id lookup first; fall back to slug resolution.
      CategoryModel? cat = await FirestoreService.getCategoryById(categoryId);
      if (cat == null) {
        final resolved = await FirestoreService.resolveCategoryId(categoryId);
        if (resolved != null && resolved != categoryId) {
          cat = await FirestoreService.getCategoryById(resolved);
        }
      }
      if (!mounted) return;
      Navigator.pop(context); // dismiss loader
      if (cat == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$packName" category not found.')),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CategoryDetailScreen(category: cat!)),
      );
    } catch (_) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open category. Please try again.')),
        );
      }
    }
  }

  /// Tap on a subject pack → navigate to that subject's test list.
  Future<void> _openSubject(String subjectId, String packName) async {
    if (subjectId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject info not available. Try refreshing.')),
      );
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Opening subject…'),
          ]),
        ),
      ),
    );
    try {
      final subject = await FirestoreService.getSubjectById(subjectId);
      if (!mounted) return;
      Navigator.pop(context);
      if (subject == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$packName" subject not found.')),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TestListScreen(subject: subject),
        ),
      );
    } catch (_) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open subject. Please try again.')),
        );
      }
    }
  }

  /// Shows a payment detail bottom sheet — no external URL needed.
  void _showPaymentDetail(Map<String, dynamic> m) {
    final product = (m['productName'] ?? m['description'] ?? 'Payment').toString();
    final date = _parseDate(m['createdAt'] ?? m['completedAt'] ?? m['date']);
    final amountPaise = _toInt(m['amount'], 0);
    final status = (m['status'] ?? 'created').toString().toLowerCase();
    final razorpayId = (m['paymentId'] ?? m['id'] ?? '').toString();
    final method = (m['method'] ?? '').toString();

    final statusColor = status == 'captured' || status == 'success'
        ? AppTheme.successColor
        : status == 'failed'
            ? AppTheme.errorColor
            : status == 'refunded'
                ? AppTheme.infoColor
                : AppTheme.warningColor;
    final statusLabel = status == 'captured' || status == 'success'
        ? 'Success'
        : status[0].toUpperCase() + status.substring(1);

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.receipt_outlined, color: statusColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(product,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(statusLabel,
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
              Text('₹${(amountPaise / 100).toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            if (date != null) ...[
              _detailRow('Date', _formatDate(date)),
              const SizedBox(height: 8),
            ],
            if (method.isNotEmpty) ...[
              _detailRow('Method', method),
              const SizedBox(height: 8),
            ],
            if (razorpayId.isNotEmpty) ...[
              _detailRow('Payment ID', razorpayId),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  /// Opens a purchased test from the "Individual Tests" section. Fetches the
  /// test from Firestore by testId and navigates to TakeTestScreen. Shows a
  /// loading dialog while fetching (the test may have been archived or the
  /// network may be slow).
  Future<void> _openTest(String testId, String title) async {
    // Show a loading indicator while we fetch the test from Firestore.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Opening test...'),
            ],
          ),
        ),
      ),
    );
    try {
      final test = await FirestoreService.getTest(testId);
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading dialog
      if (test == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$title" is no longer available.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
      // Navigate to TakeTestScreen. The test is already purchased, so the
      // access check will pass (either via the local purchasedTests list or
      // via the server-side access check).
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TestInstructionsScreen(test: test)),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open test. Please try again.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Purchases'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _fetchPurchases,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPurchases,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      // Friendly error / "rolling out" message.
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 60),
          Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _fetchPurchases,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      );
    }
    final data = _data ?? const <String, dynamic>{};
    final subscription = data['subscription'] as Map<String, dynamic>?;
    final examPacks = _asList(data['examPacks']);
    final subjectPacks = _asList(data['subjectPacks']);
    final tests = _asList(data['tests']);
    final payments = _asList(data['payments']);

    final isEmpty = subscription == null &&
        examPacks.isEmpty &&
        subjectPacks.isEmpty &&
        tests.isEmpty &&
        payments.isEmpty;

    if (isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 60),
          Icon(Icons.shopping_bag_outlined,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'No purchases yet',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Your premium subscription, exam packs and test purchases will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/premium'),
            icon: const Icon(Icons.workspace_premium),
            label: const Text('Explore Premium'),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (subscription != null) ...[
          _buildSubscriptionCard(subscription),
          const SizedBox(height: 16),
        ],
        if (examPacks.isNotEmpty) ...[
          _buildSectionHeader('Exam Packs', examPacks.length),
          const SizedBox(height: 8),
          ...examPacks.map(_buildExamPackTile),
          const SizedBox(height: 16),
        ],
        if (subjectPacks.isNotEmpty) ...[
          _buildSectionHeader('Subject Packs', subjectPacks.length),
          const SizedBox(height: 8),
          ...subjectPacks.map(_buildSubjectPackTile),
          const SizedBox(height: 16),
        ],
        if (tests.isNotEmpty) ...[
          _buildSectionHeader('Individual Tests', tests.length),
          const SizedBox(height: 8),
          ...tests.map(_buildTestTile),
          const SizedBox(height: 16),
        ],
        if (payments.isNotEmpty) ...[
          _buildSectionHeader('Payment History', payments.length),
          const SizedBox(height: 8),
          ...payments.map(_buildPaymentTile),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  // ==================== SECTION BUILDERS ====================

  Widget _buildSubscriptionCard(Map<String, dynamic> sub) {
    final planName = (sub['planName'] ?? 'Premium').toString();
    final tier = sub['planTier']?.toString();
    final startsAt = _parseDate(sub['startsAt'] ?? sub['createdAt']);
    final expiresAt = _parseDate(sub['expiresAt'] ?? sub['expiry']);
    final now = DateTime.now();
    final isActive = expiresAt == null || expiresAt.isAfter(now);
    final status = sub['status']?.toString() ?? (isActive ? 'active' : 'expired');

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.workspace_premium,
                      color: AppTheme.accentColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        planName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (tier != null && tier.isNotEmpty)
                        Text(
                          tier,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildStatusBadge(isActive ? 'Active' : 'Expired',
                    isActive ? AppTheme.successColor : AppTheme.errorColor),
              ],
            ),
            const SizedBox(height: 14),
            if (startsAt != null)
              _buildRow('Started', _formatDate(startsAt)),
            if (expiresAt != null) ...[
              const SizedBox(height: 6),
              _buildRow('Expires', _formatDate(expiresAt)),
            ],
            if (status.toLowerCase() == 'cancelled') ...[
              const SizedBox(height: 6),
              _buildRow('Status', 'Cancelled — will not renew',
                  color: AppTheme.warningColor),
            ],
            if (isActive) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isCancelling ? null : _cancelSubscription,
                  icon: _isCancelling
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cancel_outlined,
                          color: AppTheme.errorColor),
                  label: Text(
                    _isCancelling ? 'Cancelling...' : 'Cancel Subscription',
                    style: const TextStyle(color: AppTheme.errorColor),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.errorColor),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExamPackTile(dynamic pack) {
    final m = pack is Map ? Map<String, dynamic>.from(pack) : <String, dynamic>{};
    final name = (m['productName'] ?? m['name'] ?? 'Exam Pack').toString();
    final meta = m['meta'];
    final categoryId = (m['categoryId'] ??
            (meta is Map ? meta['categoryId'] : null) ??
            '')
        .toString();
    final categoryName = (m['categoryName'] ??
            (meta is Map ? meta['categoryName'] : null) ??
            '')
        .toString();
    final purchasedAt = _parseDate(m['purchasedAt'] ?? m['createdAt']);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.folder_special, color: AppTheme.primaryColor),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (categoryName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(categoryName,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              ),
            if (purchasedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Purchased ${_formatDate(purchasedAt)}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Active',
                  style: TextStyle(
                      color: AppTheme.successColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios, size: 14),
          ],
        ),
        // Tap → open the category directly so the user can start their tests.
        onTap: () => _openCategory(categoryId, name),
      ),
    );
  }

  Widget _buildSubjectPackTile(dynamic pack) {
    final m = pack is Map ? Map<String, dynamic>.from(pack) : <String, dynamic>{};
    final name = (m['productName'] ?? m['name'] ?? 'Subject Pack').toString();
    final meta = m['meta'];
    final subjectId = (m['subjectId'] ??
            (meta is Map ? meta['subjectId'] : null) ??
            '')
        .toString();
    final subjectName = (m['subjectName'] ??
            (meta is Map ? meta['subjectName'] : null) ??
            '')
        .toString();
    final purchasedAt = _parseDate(m['purchasedAt'] ?? m['createdAt']);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.library_books, color: AppTheme.infoColor),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subjectName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(subjectName,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              ),
            if (purchasedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Purchased ${_formatDate(purchasedAt)}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Active',
                  style: TextStyle(
                      color: AppTheme.successColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios, size: 14),
          ],
        ),
        // Tap → open the subject's test list so the user can start their tests.
        onTap: () => _openSubject(subjectId, name),
      ),
    );
  }

  Widget _buildTestTile(dynamic t) {
    final m = t is Map ? Map<String, dynamic>.from(t) : <String, dynamic>{};
    final title = (m['productName'] ?? m['title'] ?? 'Test').toString();
    final testId = m['testId']?.toString() ?? '';
    final purchasedAt = _parseDate(m['purchasedAt'] ?? m['createdAt']);
    final paymentId = m['paymentId']?.toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading:
            const Icon(Icons.assignment_turned_in, color: AppTheme.successColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: purchasedAt != null
            ? Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Purchased ${_formatDate(purchasedAt)}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              )
            : null,
        trailing: OutlinedButton.icon(
          onPressed: testId.isNotEmpty
              ? () => _openTest(testId, title)
              : null,
          icon: const Icon(Icons.play_arrow, size: 18),
          label: const Text('Open'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.successColor,
            side: const BorderSide(color: AppTheme.successColor),
          ),
        ),
        // Tapping the row opens the invoice (if available). The "Open"
        // button is the primary action for opening the test.
        onTap: paymentId != null && paymentId.isNotEmpty
            ? () => _openInvoice(paymentId)
            : null,
      ),
    );
  }

  Widget _buildPaymentTile(dynamic p) {
    final m = p is Map ? Map<String, dynamic>.from(p) : <String, dynamic>{};
    final product = (m['productName'] ?? m['description'] ?? 'Payment').toString();
    final date = _parseDate(m['createdAt'] ?? m['completedAt'] ?? m['date']);
    final amountPaise = _toInt(m['amount'], 0);
    final status = (m['status'] ?? 'created').toString().toLowerCase();
    final paymentId = (m['id'] ?? m['paymentId'] ?? '').toString();

    final statusColor = status == 'captured' || status == 'success'
        ? AppTheme.successColor
        : status == 'failed'
            ? AppTheme.errorColor
            : status == 'refunded'
                ? AppTheme.infoColor
                : AppTheme.warningColor;
    final statusLabel = status == 'captured' || status == 'success'
        ? 'Success'
        : status[0].toUpperCase() + status.substring(1);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.receipt_outlined, color: Colors.grey),
        title: Text(product, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (date != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(_formatDate(date),
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ),
          ],
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('₹${(amountPaise / 100).toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(statusLabel,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        // Tap → show in-app payment detail sheet. No external URLs needed.
        onTap: () => _showPaymentDetail(m),
      ),
    );
  }

  // ==================== SMALL HELPERS ====================

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(title,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildRow(String label, String value, {Color? color}) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color ?? Colors.black87)),
      ],
    );
  }

  // ==================== PARSING HELPERS ====================

  List<Map<String, dynamic>> _asList(dynamic v) {
    if (v is! List) return const [];
    return v
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList(growable: false);
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) {
      return DateTime.tryParse(v);
    }
    return null;
  }

  String _formatDate(DateTime d) {
    return DateFormat('d MMM yyyy').format(d);
  }

  int _toInt(dynamic v, int fallback) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }
}
