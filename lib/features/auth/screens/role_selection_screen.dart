import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import 'package:flutter/services.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmOffWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Select Your Role',
          style: TextStyle(color: AppColors.textDark),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Instruction text
              const Text(
                'How will you use Dowell?',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Choose the role that best describes you',
                style: TextStyle(color: AppColors.textNeutral, fontSize: 16),
              ),

              const SizedBox(height: 40),

              // Role selection cards
              Expanded(
                child: ListView(
                  children: [
                    // Customer Role
                    AppCard(
                      onTap: () => _selectRole('Customer', context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: AppColors.primary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Text(
                                  'Customer',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Submit pest control referrals and earn Bug Bucks rewards',
                            style: TextStyle(
                              color: AppColors.textNeutral,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Perfect for: Homeowners, Business owners, Property managers',
                            style: TextStyle(
                              color: AppColors.textNeutral,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Employee Role
                    AppCard(
                      onTap: () => _selectRole('Employee', context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF2196F3,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.work,
                                  color: const Color(0xFF2196F3),
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Text(
                                  'Employee',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Complete company tasks and earn cash bonuses',
                            style: TextStyle(
                              color: AppColors.textNeutral,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Perfect for: Dowell technicians, Sales representatives, Field staff',
                            style: TextStyle(
                              color: AppColors.textNeutral,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Admin Role
                    AppCard(
                      onTap: () => _selectRole('Admin', context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF9C27B0,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.admin_panel_settings,
                                  color: const Color(0xFF9C27B0),
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Text(
                                  'Administrator',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Manage users, approve referrals, and monitor rewards',
                            style: TextStyle(
                              color: AppColors.textNeutral,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Perfect for: Company managers, Team leads, System administrators',
                            style: TextStyle(
                              color: AppColors.textNeutral,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Note text
              Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: Text(
                  'Note: Your role can be changed later by contacting support',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textNeutral.withOpacity(0.7),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectRole(String role, BuildContext context) {
    // Haptic feedback
    HapticFeedback.lightImpact();

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Role Selection'),
        content: Text('You are selecting "$role" role. Is this correct?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processRoleSelection(role, context);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _processRoleSelection(String role, BuildContext context) {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Simulate API call
    Future.delayed(const Duration(seconds: 1), () {
      Navigator.pop(context); // Remove loading

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully registered as $role!'),
          backgroundColor: AppColors.success,
        ),
      );

      // Navigate to appropriate dashboard based on role
      Future.delayed(const Duration(milliseconds: 500), () {
        // For now, go back to login. In real app, navigate to dashboard
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      });
    });
  }
}
