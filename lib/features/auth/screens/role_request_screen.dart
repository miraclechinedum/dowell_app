// lib/features/auth/screens/role_request_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/user_model.dart'; // ADD THIS IMPORT for UserRole
import '../../../core/widgets/primary_button.dart';

class RoleRequestScreen extends ConsumerStatefulWidget {
  const RoleRequestScreen({super.key});

  @override
  ConsumerState<RoleRequestScreen> createState() => _RoleRequestScreenState();
}

class _RoleRequestScreenState extends ConsumerState<RoleRequestScreen> {
  UserRole? _selectedRole;
  final _reasonController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppColors.warmOffWhite,
      appBar: AppBar(
        title: const Text('Role Verification Required'),
        backgroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // Icon
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified_user,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Title
            const Text(
              'Verification Required',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // Description
            const Text(
              'Your account requires verification before you can access all features. '
              'Please select the role you wish to be verified for and provide a brief reason.',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textNeutral,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Role Selection
            const Text(
              'Select Role',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.buttonBorder),
              ),
              child: Column(
                children: [
                  _buildRoleOption(UserRole.employee, 'Employee', Icons.work),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildRoleOption(
                    UserRole.nilAthlete,
                    'NIL Athlete',
                    Icons.sports,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Reason
            const Text(
              'Reason for Request (Optional)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _reasonController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Tell us why you need this role...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.buttonBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.buttonBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),

            const Spacer(),

            // Submit Button
            PrimaryButton(
              text: 'Submit Request',
              onPressed: _selectedRole != null && !_isLoading
                  ? () => _submitRequest()
                  : null,
            ),

            const SizedBox(height: 16),

            // Logout option
            Center(
              child: TextButton(
                onPressed: () => ref.read(authProvider.notifier).logout(),
                child: const Text(
                  'Sign out and try again later',
                  style: TextStyle(
                    color: AppColors.textNeutral,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleOption(UserRole role, String title, IconData icon) {
    final isSelected = _selectedRole == role;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedRole = role;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textNeutral,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppColors.primary : AppColors.textDark,
                ),
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (_selectedRole == null) return;

    setState(() => _isLoading = true);

    try {
      final authProviderNotifier = ref.read(authProvider.notifier);

      // Get the current user ID
      final authState = ref.read(authProvider);
      final userId = authState.user?.id;

      if (userId == null) {
        throw Exception('User not found');
      }

      final result = await authProviderNotifier.requestRoleUpgrade(
        requestedRole: _selectedRole!,
        reason: _reasonController.text.isEmpty ? null : _reasonController.text,
      );

      if (result.isSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Role request submitted successfully!'),
            backgroundColor: AppColors.success,
          ),
        );

        // Navigate to verification pending screen or back to login
        Navigator.pushReplacementNamed(context, '/');
      } else if (result.isWarning && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Warning'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
