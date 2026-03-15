// lib/features/dashboard/screens/athlete/athlete_payout_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/providers/auth_provider.dart';

const _kPurple = Color(0xFF6A1B9A);

class AthletePayoutHistoryScreen extends ConsumerWidget {
  const AthletePayoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.read(authProvider).user?.uid ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Payout History',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('payout_requests')
            .where('userId', isEqualTo: uid)
            .get(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _kPurple),
            );
          }
          final docs = (snap.data?.docs ?? [])
            ..sort((a, b) {
              final at =
                  (a['requestedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              final bt =
                  (b['requestedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              return bt.compareTo(at);
            });
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No payout requests yet.',
                style: TextStyle(color: AppColors.textNeutral),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final status = d['status'] as String? ?? 'pending';
              final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;
              final ts = d['requestedAt'] as Timestamp?;
              final date = ts != null
                  ? DateFormat('MMM d, yyyy').format(ts.toDate())
                  : '—';
              final Color statusColor;
              switch (status) {
                case 'processed':
                  statusColor = AppColors.success;
                  break;
                case 'failed':
                  statusColor = AppColors.error;
                  break;
                default:
                  statusColor = Colors.orange;
              }
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: _kPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.payments_rounded,
                        color: _kPurple,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '\$${amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            date,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textNeutral,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status[0].toUpperCase() + status.substring(1),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
