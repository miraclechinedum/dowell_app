// lib/features/dashboard/screens/employee/employee_notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/providers/auth_provider.dart';

class EmployeeNotificationsScreen extends ConsumerStatefulWidget {
  const EmployeeNotificationsScreen({super.key});

  @override
  ConsumerState<EmployeeNotificationsScreen> createState() =>
      _EmployeeNotificationsScreenState();
}

class _EmployeeNotificationsScreenState
    extends ConsumerState<EmployeeNotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
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

      final list =
          snap.docs.map((d) {
            return <String, dynamic>{'id': d.id, ...d.data()};
          }).toList()..sort((a, b) {
            final at =
                (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            final bt =
                (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            return bt.compareTo(at);
          });

      if (mounted)
        setState(() {
          _notifications = list;
          _loading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    final batch = FirebaseFirestore.instance.batch();
    for (final n in _notifications.where((n) => n['read'] != true)) {
      batch.update(
        FirebaseFirestore.instance
            .collection('notifications')
            .doc(n['id'] as String),
        {'read': true},
      );
    }
    await batch.commit();
    setState(() {
      for (final n in _notifications) n['read'] = true;
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
          : _notifications.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                itemCount: _notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final n = _notifications[i];
                  final isRead = n['read'] == true;
                  final type = n['type'] as String? ?? '';
                  final date = (n['createdAt'] as Timestamp?)?.toDate();
                  final info = _typeInfo(type);

                  return Dismissible(
                    key: ValueKey(n['id']),
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
                      _delete(n['id'] as String);
                      return false;
                    },
                    child: GestureDetector(
                      onTap: () {
                        if (!isRead) _markRead(n['id'] as String);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isRead
                              ? Colors.white
                              : info.$1.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isRead
                                ? const Color(0xFFF0F0F0)
                                : info.$1.withOpacity(0.25),
                            width: isRead ? 1 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                isRead ? 0.03 : 0.05,
                              ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            n['title'] as String? ??
                                                'Notification',
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
                                            margin: const EdgeInsets.only(
                                              top: 4,
                                            ),
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
                                      n['message'] as String? ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isRead
                                            ? AppColors.textNeutral
                                            : AppColors.textDark.withOpacity(
                                                0.75,
                                              ),
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
                                              color: AppColors.textLight
                                                  .withOpacity(0.6),
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
                },
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
            'You\'ll be notified here when your tasks are approved or rejected, and when payouts are processed.',
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

  (Color, IconData) _typeInfo(String type) {
    switch (type.toLowerCase()) {
      case 'welcome':
        return (AppColors.primary, Icons.waving_hand_rounded);
      case 'task_approved':
      case 'task_bonus':
        return (AppColors.success, Icons.task_alt_rounded);
      case 'task_rejected':
        return (AppColors.error, Icons.cancel_rounded);
      case 'payout_processed':
        return (AppColors.success, Icons.payments_rounded);
      case 'payout_failed':
        return (AppColors.error, Icons.payments_rounded);
      case 'admin_adjustment':
        return (Colors.orange, Icons.account_balance_wallet_rounded);
      case 'role_approved':
        return (AppColors.success, Icons.verified_rounded);
      case 'role_rejected':
        return (AppColors.error, Icons.cancel_rounded);
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
