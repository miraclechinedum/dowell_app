// lib/features/dashboard/screens/admin/admin_notifications.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/providers/auth_provider.dart';

class AdminNotificationsScreen extends ConsumerStatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  ConsumerState<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState
    extends ConsumerState<AdminNotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = ref.read(authProvider).user?.uid;
      if (uid == null) {
        setState(() => _loading = false);
        return;
      }

      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .get();

      final list = snap.docs.map((d) {
        final data = d.data();
        return <String, dynamic>{'id': d.id, ...data};
      }).toList();

      // Sort newest first in Dart (avoids needing a Firestore composite index)
      list.sort((a, b) {
        final at = (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final bt = (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return bt.compareTo(at);
      });

      if (mounted)
        setState(() {
          _notifications = list;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  Future<void> _markAllRead() async {
    final uid = ref.read(authProvider).user?.uid;
    if (uid == null) return;

    final unread = _notifications.where((n) => n['read'] != true).toList();
    if (unread.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final n in unread) {
      batch.update(
        FirebaseFirestore.instance
            .collection('notifications')
            .doc(n['id'] as String),
        {'read': true},
      );
    }
    await batch.commit();
    // Update local state instantly — no need to re-fetch
    setState(() {
      for (final n in _notifications) {
        n['read'] = true;
      }
    });
  }

  Future<void> _markRead(String id) async {
    await FirebaseFirestore.instance.collection('notifications').doc(id).update(
      {'read': true},
    );
    setState(() {
      final idx = _notifications.indexWhere((n) => n['id'] == id);
      if (idx != -1) _notifications[idx]['read'] = true;
    });
  }

  Future<void> _delete(String id) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(id)
        .delete();
    setState(() => _notifications.removeWhere((n) => n['id'] == id));
  }

  int get _unreadCount => _notifications.where((n) => n['read'] != true).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Notifications',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
          ? _buildError()
          : _notifications.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                itemCount: _notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) => _NotificationCard(
                  data: _notifications[i],
                  onTap: () {
                    if (_notifications[i]['read'] != true) {
                      _markRead(_notifications[i]['id'] as String);
                    }
                  },
                  onDismiss: () => _delete(_notifications[i]['id'] as String),
                ),
              ),
            ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.07),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            size: 40,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'No notifications yet',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            'You\'ll receive notifications here when users submit tasks, role requests, payout requests, and more.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textNeutral,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 48, color: AppColors.error),
        const SizedBox(height: 12),
        const Text(
          'Failed to load notifications',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textNeutral),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _load,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Retry', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification card (swipe-to-dismiss + tap-to-read)
// ─────────────────────────────────────────────────────────────────────────────
class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationCard({
    required this.data,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isRead = data['read'] == true;
    final type = data['type'] as String? ?? '';
    final date = (data['createdAt'] as Timestamp?)?.toDate();
    final info = _typeInfo(type);

    return Dismissible(
      key: ValueKey(data['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.error,
          size: 22,
        ),
      ),
      confirmDismiss: (_) async {
        onDismiss();
        return false; // we handle removal ourselves
      },
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : info.$1.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isRead
                  ? const Color(0xFFF0F0F0)
                  : info.$1.withOpacity(0.25),
              width: isRead ? 1 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isRead ? 0.03 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: info.$1.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(info.$2, color: info.$1, size: 20),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              data['title'] as String? ?? 'Notification',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isRead
                                    ? FontWeight.w600
                                    : FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          if (!isRead) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: info.$1,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['message'] as String? ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: isRead
                              ? AppColors.textNeutral
                              : AppColors.textDark.withOpacity(0.75),
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (date != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 10,
                              color: AppColors.textLight,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _formatDate(date),
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textLight,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'swipe to delete',
                              style: TextStyle(
                                fontSize: 9,
                                color: AppColors.textLight.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (Color, IconData) _typeInfo(String type) {
    switch (type.toLowerCase()) {
      case 'welcome':
        return (AppColors.primary, Icons.waving_hand_rounded);
      case 'role_request':
        return (Colors.orange, Icons.manage_accounts_rounded);
      case 'role_approved':
        return (AppColors.success, Icons.verified_rounded);
      case 'role_rejected':
        return (AppColors.error, Icons.cancel_rounded);
      case 'task_bonus':
      case 'task_approved':
        return (AppColors.success, Icons.task_alt_rounded);
      case 'task_rejected':
        return (AppColors.error, Icons.task_alt_rounded);
      case 'payout_processed':
        return (AppColors.success, Icons.payments_rounded);
      case 'payout_failed':
        return (AppColors.error, Icons.payments_rounded);
      case 'referral':
      case 'referral_converted':
        return (const Color(0xFF1565C0), Icons.handshake_rounded);
      case 'admin_adjustment':
        return (Colors.orange, Icons.account_balance_wallet_rounded);
      default:
        return (AppColors.primary, Icons.notifications_rounded);
    }
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, yyyy · h:mm a').format(date);
  }
}
