// =============================================================================
// ExamVault - Scrolling Announcement Banner (marquee)
// =============================================================================
// Shows active announcements scrolling horizontally. Appears at the top of
// both the admin dashboard and the user home screen.
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/local_data_service.dart';
import '../theme/app_theme.dart';

class ScrollingAnnouncementBanner extends StatefulWidget {
  final bool isAdmin;
  const ScrollingAnnouncementBanner({super.key, this.isAdmin = false});

  @override
  State<ScrollingAnnouncementBanner> createState() =>
      _ScrollingAnnouncementBannerState();
}

class _ScrollingAnnouncementBannerState extends State<ScrollingAnnouncementBanner> {
  final ScrollController _controller = ScrollController();
  Timer? _timer;
  List<LocalAnnouncement> _announcements = [];
  double _offset = 0;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  void _loadAnnouncements() {
    final all = LocalDataService.getAnnouncements();
    setState(() {
      _announcements = all.where((a) => a.isActive).toList();
    });
    if (_announcements.isNotEmpty) {
      _startScrolling();
    }
  }

  void _startScrolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 30), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (!_controller.hasClients) return;
      final max = _controller.position.maxScrollExtent;
      _offset += 1.5;
      if (_offset > max + 200) {
        _offset = -MediaQuery.of(context).size.width;
      }
      _controller.jumpTo(_offset);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_announcements.isEmpty) {
      return const SizedBox.shrink();
    }

    final text = _announcements.map((a) => a.title).join('    •    ');

    return Container(
      width: double.infinity,
      height: 38,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.isAdmin
              ? [const Color(0xFF1A1A2E), const Color(0xFF0F0F1A)]
              : [AppTheme.primaryColor, const Color(0xFF003C8F)],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: const Icon(Icons.campaign, color: Colors.amber, size: 20),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                children: [
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 80),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}
