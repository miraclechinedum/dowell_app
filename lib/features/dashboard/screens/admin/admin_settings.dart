import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_card.dart';

class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() =>
      _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic> _settings = {};
  Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await _firestore
          .collection('app_settings')
          .doc('reward_settings')
          .get();

      if (doc.exists) {
        setState(() {
          _settings = doc.data() ?? {};
          _initializeControllers();
        });
      } else {
        // Create default reward settings
        _settings = _getDefaultSettings();
        await _firestore
            .collection('app_settings')
            .doc('reward_settings')
            .set(_settings);
        _initializeControllers();
      }
    } catch (e) {
      print('Error loading settings: $e');
      setState(() {
        _settings = _getDefaultSettings();
        _initializeControllers();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _getDefaultSettings() {
    return {
      'referral_bug_bucks': 100,
      'converted_referral_bonus': 50,
      'employee_task_bug_bucks': 50,
      'employee_cash_bonus': 25.0,
      'updated_at': FieldValue.serverTimestamp(),
      'updated_by': 'system',
    };
  }

  void _initializeControllers() {
    _controllers['referral_bug_bucks'] = TextEditingController(
      text: _settings['referral_bug_bucks']?.toString() ?? '100',
    );
    _controllers['converted_referral_bonus'] = TextEditingController(
      text: _settings['converted_referral_bonus']?.toString() ?? '50',
    );
    _controllers['employee_task_bug_bucks'] = TextEditingController(
      text: _settings['employee_task_bug_bucks']?.toString() ?? '50',
    );
    _controllers['employee_cash_bonus'] = TextEditingController(
      text: _settings['employee_cash_bonus']?.toString() ?? '25.0',
    );
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Validate all inputs
      final referralBugBucks = int.tryParse(
        _controllers['referral_bug_bucks']!.text,
      );
      final convertedBonus = int.tryParse(
        _controllers['converted_referral_bonus']!.text,
      );
      final employeeTaskBugBucks = int.tryParse(
        _controllers['employee_task_bug_bucks']!.text,
      );
      final employeeCashBonus = double.tryParse(
        _controllers['employee_cash_bonus']!.text,
      );

      if (referralBugBucks == null || referralBugBucks < 0) {
        throw 'Referral Bug Bucks must be a positive number';
      }
      if (convertedBonus == null || convertedBonus < 0) {
        throw 'Converted Referral Bonus must be a positive number';
      }
      if (employeeTaskBugBucks == null || employeeTaskBugBucks < 0) {
        throw 'Employee Task Bug Bucks must be a positive number';
      }
      if (employeeCashBonus == null || employeeCashBonus < 0) {
        throw 'Employee Cash Bonus must be a positive number';
      }

      // Update settings
      final updatedSettings = {
        'referral_bug_bucks': referralBugBucks,
        'converted_referral_bonus': convertedBonus,
        'employee_task_bug_bucks': employeeTaskBugBucks,
        'employee_cash_bonus': employeeCashBonus,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': 'admin',
      };

      await _firestore
          .collection('app_settings')
          .doc('reward_settings')
          .set(updatedSettings, SetOptions(merge: true));

      // Update local state
      setState(() {
        _settings = updatedSettings;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reward settings saved successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Reward Settings'),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reward Settings'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Text(
                    'Configure Reward Amounts',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Set the Bug Bucks and cash bonus amounts for different user actions.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textNeutral,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Referral Bug Bucks
                  _buildRewardSetting(
                    title: 'Referral Bug Bucks',
                    subtitle: 'Bug Bucks awarded for each new referral',
                    controller: _controllers['referral_bug_bucks']!,
                    suffix: 'BB',
                    icon: Icons.person_add,
                    iconColor: Colors.orange,
                  ),
                  const SizedBox(height: 14),

                  // Converted Referral Bonus
                  _buildRewardSetting(
                    title: 'Converted Referral Bonus',
                    subtitle:
                        'Additional Bug Bucks when a referral converts to a customer',
                    controller: _controllers['converted_referral_bonus']!,
                    suffix: 'BB',
                    icon: Icons.check_circle,
                    iconColor: AppColors.success,
                  ),
                  const SizedBox(height: 14),

                  // Employee Task Bug Bucks
                  _buildRewardSetting(
                    title: 'Employee Task Bug Bucks',
                    subtitle: 'Bug Bucks for completed employee tasks',
                    controller: _controllers['employee_task_bug_bucks']!,
                    suffix: 'BB',
                    icon: Icons.task,
                    iconColor: Colors.blue,
                  ),
                  const SizedBox(height: 14),

                  // Employee Cash Bonus
                  _buildRewardSetting(
                    title: 'Employee Cash Bonus',
                    subtitle: 'Cash bonus awarded for employee tasks',
                    controller: _controllers['employee_cash_bonus']!,
                    suffix: '\$',
                    icon: Icons.attach_money,
                    iconColor: AppColors.primary,
                    isDecimal: true,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Save Button Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.save, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Reward-setting card — uses [AppCard] + FormTextField-style input so it
  /// reads visually identical to the other admin screens.
  Widget _buildRewardSetting({
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required String suffix,
    required IconData icon,
    required Color iconColor,
    bool isDecimal = false,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textNeutral,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: isDecimal
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.number,
                  inputFormatters: isDecimal
                      ? [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'),
                          ),
                        ]
                      : [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: 'Enter amount',
                    hintStyle: const TextStyle(
                      color: AppColors.textNeutral,
                      fontSize: 15,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.buttonBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.6,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  suffix,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: iconColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
