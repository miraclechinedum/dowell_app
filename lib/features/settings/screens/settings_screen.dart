import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/app_card.dart';

/// Shared account settings screen used by every role (customer, employee,
/// NIL athlete, admin). Hosts the Apple-compliant (Guideline 5.1.1(v))
/// permanent account deletion flow.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final userEmail = user?.email ?? '';
    final userName = user?.displayName ??
        (userEmail.isNotEmpty ? userEmail.split('@').first : 'User');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _isDeleting,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Account header
                AppCard(
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: AppColors.primary,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              userEmail,
                              style: const TextStyle(
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
                  'Account',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textNeutral,
                  ),
                ),
                const SizedBox(height: 8),

                /// Delete Account (destructive)
                AppCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: _isDeleting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.error,
                            ),
                          )
                        : const Icon(
                            Icons.delete_forever,
                            color: AppColors.error,
                          ),
                    title: const Text(
                      'Delete Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                    subtitle: Text(
                      _isDeleting
                          ? 'Deleting your account…'
                          : 'Permanently delete your account and data',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textNeutral,
                      ),
                    ),
                    trailing: _isDeleting
                        ? null
                        : const Icon(
                            Icons.chevron_right,
                            color: AppColors.textNeutral,
                          ),
                    onTap: _isDeleting ? null : _onDeleteAccountTapped,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Step 1: confirmation dialog with the exact Apple-review wording.
  Future<void> _onDeleteAccountTapped() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Deleting your account will permanently remove your profile, '
          'referrals, rewards, and associated data. This action cannot be '
          'undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete My Account'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteAccount();
    }
  }

  /// Step 2: perform deletion, transparently handling re-authentication.
  Future<void> _deleteAccount() async {
    setState(() => _isDeleting = true);

    try {
      await ref.read(authProvider.notifier).deleteAccount();
      _onDeletionComplete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        final didComplete = await _reauthenticateAndRetry();
        if (didComplete) {
          _onDeletionComplete();
        } else if (mounted) {
          setState(() => _isDeleting = false);
        }
      } else {
        _showError('Failed to delete account. Please try again.');
        if (mounted) setState(() => _isDeleting = false);
      }
    } catch (e) {
      _showError('Failed to delete account. Please try again.');
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  /// Re-authenticates with the user's password, then retries the deletion.
  /// Returns true when the account was fully deleted.
  Future<bool> _reauthenticateAndRetry() async {
    final password = await _promptForPassword();
    if (password == null || password.isEmpty) return false; // cancelled

    try {
      await ref.read(authProvider.notifier).reauthenticateWithPassword(password);
      await ref.read(authProvider.notifier).deleteAccount();
      return true;
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
      return false;
    }
  }

  /// Prompts for the current password to satisfy `requires-recent-login`.
  Future<String?> _promptForPassword() async {
    final passwordController = TextEditingController();
    bool obscure = true;

    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Confirm Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'For your security, please re-enter your password to delete '
                'your account.',
                style: TextStyle(fontSize: 14, color: AppColors.textNeutral),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.buttonBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textNeutral,
                    ),
                    onPressed: () =>
                        setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(passwordController.text),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );

    passwordController.dispose();
    return password;
  }

  /// Signs out, returns to login, and confirms the deletion to the user.
  /// The root [ScaffoldMessenger] survives the navigation so the success
  /// snackbar is shown on the login screen.
  void _onDeletionComplete() {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamedAndRemoveUntil('/login', (route) => false);

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Your account has been deleted successfully.'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
