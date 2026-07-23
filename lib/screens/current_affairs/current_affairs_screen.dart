// =============================================================================
// ExamVault - Current Affairs Screen
// =============================================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/current_affair_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/localized_content.dart';
import '../../utils/share_helper.dart';

class CurrentAffairsScreen extends StatefulWidget {
  const CurrentAffairsScreen({super.key});

  @override
  State<CurrentAffairsScreen> createState() => _CurrentAffairsScreenState();
}

class _CurrentAffairsScreenState extends State<CurrentAffairsScreen> {
  DateTime? _selectedDate;
  // Empty string is the "All Categories" sentinel — see `ca_all_categories`.
  String _selectedCategory = '';
  // Most recent list of affairs emitted by the stream. Cached here so the
  // category filter button (which lives outside the StreamBuilder) can read
  // the unique categories to populate the picker modal.
  List<CurrentAffairModel> _latestAffairs = const [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'ca_title')),
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() {
                          _selectedDate = date;
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _selectedDate != null
                          ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                          : 'Select Date',
                    ),
                  ),
                ),
                if (_selectedDate != null) ...[
                  IconButton(
                    tooltip: tr(context, 'ca_clear_date'),
                    onPressed: () {
                      setState(() {
                        _selectedDate = null;
                      });
                    },
                    icon: const Icon(Icons.close, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showCategoryPicker,
                    icon: const Icon(Icons.filter_list, size: 16),
                    label: Text(
                      _selectedCategory.isEmpty
                          ? tr(context, 'ca_all_categories')
                          : _selectedCategory,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: StreamBuilder<List<CurrentAffairModel>>(
              stream: FirestoreService.getCurrentAffairsStream(limit: 50),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.newspaper, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No current affairs available'),
                      ],
                    ),
                  );
                }
                // Cache the latest snapshot so the category picker (which
                // lives outside this builder) can read the unique categories.
                _latestAffairs = snapshot.data!;
                // Apply local filters (Critical #8 + #9). The Firestore stream
                // is not parameterised by category/date, so we filter the full
                // list in-place here.
                final filtered = snapshot.data!.where((affair) {
                  final matchesCategory =
                      _selectedCategory.isEmpty ||
                          affair.category == _selectedCategory;
                  final matchesDate = _selectedDate == null ||
                      DateUtils.isSameDay(affair.date, _selectedDate!);
                  return matchesCategory && matchesDate;
                }).toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.filter_alt_off,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(tr(context, 'ca_no_results')),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final affair = filtered[index];
                    return _buildAffairCard(affair);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAffairCard(CurrentAffairModel affair) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          _showDetail(affair);
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (affair.imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: CachedNetworkImage(
                  imageUrl: affair.imageUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey.shade200,
                    height: 180,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${affair.date.day} ${_monthName(affair.date.month)} ${affair.date.year}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (affair.isImportant) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Important',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        affair.category,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lc(context, affair.title, affair.titleAs),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lc(context, affair.summary, affair.summaryAs),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (affair.pdfUrl != null)
                        TextButton.icon(
                          onPressed: () async {
                            // Open PDF in the external browser.
                            final uri = Uri.tryParse(affair.pdfUrl!);
                            if (uri == null) return;
                            try {
                              final ok = await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                              if (!ok) {
                                await launchUrl(uri,
                                    mode: LaunchMode.inAppBrowserView);
                              }
                            } catch (_) {}
                          },
                          icon: const Icon(Icons.picture_as_pdf, size: 16),
                          label: const Text('PDF'),
                        ),
                      const Spacer(),
                      TextButton.icon(
                        // Shares this affair via the platform share sheet.
                        // The shared text always includes the ExamVault Play
                        // Store link so recipients can download the app.
                        onPressed: () {
                          ShareHelper.shareCurrentAffair(affair);
                        },
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('Share'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Shows a modal bottom sheet listing every unique category present in the
  // currently loaded current-affairs, plus an "All Categories" option at the
  // top that clears the filter. (Critical #8 fix.)
  void _showCategoryPicker() {
    final categories = <String>{};
    for (final a in _latestAffairs) {
      if (a.category.isNotEmpty) categories.add(a.category);
    }
    final sorted = categories.toList()..sort();
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tr(context, 'ca_select_category'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.list),
                title: Text(tr(context, 'ca_all_categories')),
                trailing: _selectedCategory.isEmpty
                    ? const Icon(Icons.check, color: AppTheme.primaryColor)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedCategory = '';
                  });
                  Navigator.of(sheetContext).pop();
                },
              ),
              if (sorted.isEmpty)
                ListTile(
                  leading: const Icon(Icons.inbox, color: Colors.grey),
                  title: Text(
                    tr(context, 'ca_no_results'),
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              else
                ...sorted.map(
                  (c) => ListTile(
                    leading: const Icon(Icons.label_outline),
                    title: Text(c),
                    trailing: _selectedCategory == c
                        ? const Icon(Icons.check,
                            color: AppTheme.primaryColor)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedCategory = c;
                      });
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showDetail(CurrentAffairModel affair) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lc(context, affair.title, affair.titleAs),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '${affair.date.day} ${_monthName(affair.date.month)} ${affair.date.year}',
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            affair.source,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        affair.content,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}
