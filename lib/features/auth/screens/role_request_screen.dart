import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/providers/auth_provider.dart';

class RoleRequestScreen extends ConsumerStatefulWidget {
  const RoleRequestScreen({super.key});

  @override
  ConsumerState<RoleRequestScreen> createState() => _RoleRequestScreenState();
}

class _RoleRequestScreenState extends ConsumerState<RoleRequestScreen> {
  String? _selectedRole;
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _availableRoles = [
    {
      'id': 'employee',
      'title': 'Employee',
      'description': 'Submit tasks and earn cash bonuses',
      'icon': Icons.work,
      'color': Colors.blue,
      'requiresVerification': true,
    },
    {
      'id': 'nil_athlete',
      'title': 'NIL Athlete',
      'description': 'Manage sponsorships and referrals',
      'icon': Icons.sports,
      'color': Colors.green,
      'requiresVerification': true,
    },
    {
      'id': 'admin',
      'title': 'Administrator',
      'description': 'Manage users and system settings',
      'icon': Icons.admin_panel_settings,
      'color': Colors.purple,
      'requiresVerification': true,
    },
  ];

  Future<void> _submitRoleRequest() async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a role'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await ref
          .read(authProvider.notifier)
          .requestRoleUpgrade(
            requestedRole: _selectedRole!,
            userId: user.uid,
            reason: _reasonController.text.isNotEmpty
                ? _reasonController.text
                : null,
          );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_selectedRole == 'employee'
                ? 'Employee'
                : _selectedRole == 'nil_athlete'
                ? 'NIL Athlete'
                : 'Administrator'} access requested. An admin will review your request.',
          ),
          backgroundColor: AppColors.success,
        ),
      );

      // Navigate back to dashboard
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting request: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Role Upgrade'), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Request Role Upgrade',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You are currently registered as a Customer. Request access to additional features.',
                style: TextStyle(fontSize: 16, color: AppColors.textNeutral),
              ),
              const SizedBox(height: 32),

              // Current Role Info
              AppCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Role: Customer',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You can refer friends and earn Bug Bucks',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textNeutral,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                'Select Role to Request:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),

              // Role Options
              ..._availableRoles.map((role) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    onTap: () {
                      setState(() {
                        _selectedRole = role['id'] as String;
                      });
                    },
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (role['color'] as Color).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            role['icon'] as IconData,
                            color: role['color'] as Color,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                role['title'] as String,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: role['color'] as Color,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                role['description'] as String,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textNeutral,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.amber),
                                ),
                                child: const Text(
                                  'Requires Admin Approval',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Radio<String>(
                          value: role['id'] as String,
                          groupValue: _selectedRole,
                          onChanged: (value) {
                            setState(() {
                              _selectedRole = value;
                            });
                          },
                          activeColor: role['color'] as Color,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),

              const SizedBox(height: 24),

              // Reason for Request
              const Text(
                'Reason for Request (Optional):',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Explain why you need this role access...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.buttonBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  text: 'Submit Request',
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          _submitRoleRequest();
                        },
                  isLoading: _isSubmitting,
                ),
              ),

              const SizedBox(height: 16),

              // Cancel Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: AppColors.buttonBorder),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
