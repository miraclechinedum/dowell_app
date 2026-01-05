import 'package:flutter/material.dart';
import 'app_card.dart';
import '../constants/app_colors.dart';

class BalanceCard extends StatelessWidget {
  final String title;
  final String amount;
  final String currency;
  final Color? color;

  const BalanceCard({
    super.key, // Fixed: Use super.key
    required this.title,
    required this.amount,
    this.currency = 'Bug Bucks',
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.textNeutral, // Fixed: Use textNeutral
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                amount,
                style: TextStyle(
                  color: color ?? AppColors.primary,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                currency,
                style: TextStyle(
                  color: color ?? AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
