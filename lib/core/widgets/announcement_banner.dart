// lib/core/widgets/announcement_banner.dart
//
// Usage — drop this anywhere near the top of your dashboard home screen:
//
//   AnnouncementBanner(userRole: currentUser.role)
//
// It reads app_config/settings from Firestore, checks whether the
// announcement is enabled and whether this user's role is in the target
// list, and renders a dismissible card if so.
// Once dismissed it stays hidden for the rest of the session (in-memory).
// No persistent storage is used — the banner reappears next app launch,
// which is intentional (announcements are time-sensitive).

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnnouncementBanner extends StatefulWidget {
  final String userRole;

  const AnnouncementBanner({super.key, required this.userRole});

  @override
  State<AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<AnnouncementBanner>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  bool _dismissed = false;
  bool _loading = true;
  String? _message;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

    _fetchAnnouncement();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Fetch from Firestore ───────────────────────────────────────────────────
  Future<void> _fetchAnnouncement() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('settings')
          .get();

      if (!doc.exists) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final data = doc.data()!;
      final enabled = data['announcementEnabled'] as bool? ?? false;
      final text = (data['announcementText'] as String? ?? '').trim();
      final targetRoles =
          (data['announcementRoles'] as List?)?.cast<String>() ??
          ['customer', 'employee', 'athlete', 'admin'];

      final shouldShow =
          enabled &&
          text.isNotEmpty &&
          targetRoles.contains(widget.userRole.toLowerCase());

      if (mounted) {
        setState(() {
          _message = shouldShow ? text : null;
          _loading = false;
        });
        if (shouldShow) _animCtrl.forward();
      }
    } catch (_) {
      // Silently fail — don't break the dashboard if config is unreachable
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Dismiss ────────────────────────────────────────────────────────────────
  Future<void> _dismiss() async {
    await _animCtrl.reverse();
    if (mounted) setState(() => _dismissed = true);
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Nothing to show
    if (_loading || _dismissed || _message == null) {
      return const SizedBox.shrink();
    }

    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF8F00), Color(0xFFF57C00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF8F00).withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      margin: const EdgeInsets.only(top: 1),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Message
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Announcement',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _message!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Dismiss button
                    GestureDetector(
                      onTap: _dismiss,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
