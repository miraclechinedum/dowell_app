import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart'; // For Clipboard

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/form_text_field.dart';
import '../../providers/referral_provider.dart';

class SubmitReferralScreen extends ConsumerStatefulWidget {
  const SubmitReferralScreen({super.key});

  @override
  ConsumerState<SubmitReferralScreen> createState() =>
      _SubmitReferralScreenState();
}

class _SubmitReferralScreenState extends ConsumerState<SubmitReferralScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String? _selectedServiceType;
  bool _isLoading = false;
  bool _formHasChanges = false; // Track form changes manually
  String? _referralCode;

  final List<Map<String, dynamic>> _serviceTypes = [
    {
      'id': 'residential',
      'title': 'Residential Pest Control',
      'description': 'Home or apartment pest control services',
      'icon': Icons.home,
    },
    {
      'id': 'commercial',
      'title': 'Commercial Pest Control',
      'description': 'Business or office pest control services',
      'icon': Icons.business,
    },
    {
      'id': 'termite',
      'title': 'Termite Inspection & Treatment',
      'description': 'Termite detection and elimination',
      'icon': Icons.bug_report,
    },
    {
      'id': 'mosquito',
      'title': 'Mosquito Control',
      'description': 'Outdoor mosquito treatment',
      'icon': Icons.water_drop,
    },
    {
      'id': 'rodent',
      'title': 'Rodent Control',
      'description': 'Rat and mouse removal',
      'icon': Icons.pest_control,
    },
    {
      'id': 'bed_bug',
      'title': 'Bed Bug Treatment',
      'description': 'Bed bug inspection and treatment',
      'icon': Icons.bed,
    },
    {
      'id': 'other',
      'title': 'Other Services',
      'description': 'Other pest control needs',
      'icon': Icons.more_horiz,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadReferralCode();

    // Listen to all text controllers for changes
    _nameController.addListener(_updateFormChanges);
    _emailController.addListener(_updateFormChanges);
    _phoneController.addListener(_updateFormChanges);
    _addressController.addListener(_updateFormChanges);
    _notesController.addListener(_updateFormChanges);
  }

  void _updateFormChanges() {
    setState(() {
      _formHasChanges =
          _nameController.text.isNotEmpty ||
          _emailController.text.isNotEmpty ||
          _phoneController.text.isNotEmpty ||
          _addressController.text.isNotEmpty ||
          _notesController.text.isNotEmpty ||
          _selectedServiceType != null;
    });
  }

  Future<void> _loadReferralCode() async {
    try {
      final code = await ref.read(referralProvider.notifier).getReferralCode();
      setState(() {
        _referralCode = code;
      });
    } catch (e) {
      print('Error loading referral code: $e');
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load referral code: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _submitReferral() async {
    if (!_formKey.currentState!.validate()) {
      _showValidationError();
      return;
    }

    if (_selectedServiceType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a service type'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final referralForm = ReferralForm(
        referralName: _nameController.text.trim(),
        referralEmail: _emailController.text.trim(),
        referralPhone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        serviceType: _selectedServiceType!,
        notes: _notesController.text.trim(),
      );

      final result = await ref
          .read(referralProvider.notifier)
          .submitReferral(referralForm);

      // Show success dialog
      await _showSuccessDialog(result['message'] as String);

      // Clear form
      _clearForm();

      // Navigate back
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showValidationError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please fill all required fields correctly'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showSuccessDialog(String message) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            SizedBox(width: 12),
            Text('Success!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            if (_referralCode != null) ...[
              const Text(
                'Share your referral code:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _copyToClipboard(_referralCode!),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _referralCode!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const Icon(Icons.copy, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog

              // Refresh the referral list provider
              ref.read(referralListProvider.notifier).refresh();

              // Clear form and navigate back
              _clearForm();
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: AppColors.error),
            SizedBox(width: 12),
            Text('Submission Failed'),
          ],
        ),
        content: Text(
          'There was an error submitting your referral:\n\n$error\n\nPlease try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _clearForm() {
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _addressController.clear();
    _notesController.clear();
    setState(() {
      _selectedServiceType = null;
      _formHasChanges = false;
    });
    _formKey.currentState?.reset();
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Referral code copied to clipboard!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a phone number';
    }
    // Remove all non-digit characters for validation
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');

    // Check if it has at least 10 digits (US phone number standard)
    if (digitsOnly.length < 10) {
      return 'Please enter a valid phone number with at least 10 digits';
    }

    return null;
  }

  @override
  void dispose() {
    _nameController.removeListener(_updateFormChanges);
    _emailController.removeListener(_updateFormChanges);
    _phoneController.removeListener(_updateFormChanges);
    _addressController.removeListener(_updateFormChanges);
    _notesController.removeListener(_updateFormChanges);

    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit New Referral'),
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Info
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.celebration, color: Colors.amber, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'Earn Bug Bucks',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Submit a referral and earn 100 Bug Bucks immediately. '
                      'Bug Bucks can be redeemed for discounts or cash rewards.',
                      style: TextStyle(color: AppColors.textNeutral),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.amber),
                          ),
                          child: const Text(
                            '+100 Bug Bucks',
                            style: TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (_referralCode != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.primary),
                            ),
                            child: Text(
                              'Code: $_referralCode',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Referral Form
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Referral Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Please provide details about the person you\'re referring',
                      style: TextStyle(color: AppColors.textNeutral),
                    ),

                    const SizedBox(height: 20),

                    // Referral Name
                    FormTextField(
                      label: 'Full Name *',
                      hintText: 'Enter referral\'s full name',
                      controller: _nameController,
                      prefixIcon: const Icon(Icons.person),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter referral name';
                        }
                        if (value.length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Referral Email
                    FormTextField(
                      label: 'Email Address *',
                      hintText: 'referral@example.com',
                      controller: _emailController,
                      prefixIcon: const Icon(Icons.email),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter email address';
                        }
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Referral Phone - Use TextFormField directly for better control
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Phone Number *',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: '(123) 456-7890',
                            prefixIcon: const Icon(Icons.phone),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.buttonBorder,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          validator: _validatePhone,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Address - Use TextFormField directly for maxLines
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Address *',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _addressController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'Street address, city, state, zip code',
                            prefixIcon: const Icon(Icons.location_on),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.buttonBorder,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter address';
                            }
                            if (value.length < 10) {
                              return 'Please enter a complete address';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Service Type Selection
                    const Text(
                      'Service Type *',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select the type of service needed',
                      style: TextStyle(color: AppColors.textNeutral),
                    ),
                    const SizedBox(height: 12),

                    // Service Type Grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.5,
                          ),
                      itemCount: _serviceTypes.length,
                      itemBuilder: (context, index) {
                        final service = _serviceTypes[index];
                        final isSelected =
                            _selectedServiceType == service['id'];

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedServiceType = service['id'] as String;
                              _updateFormChanges();
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withOpacity(0.1)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.buttonBorder,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  service['icon'] as IconData,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textNeutral,
                                  size: 24,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  service['title'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textDark,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // Additional Notes
                    const Text(
                      'Additional Notes (Optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText:
                            'Any additional information that might be helpful...\n'
                            'Example: "Prefers evening appointments" or "Has pets at home"',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.buttonBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Terms & Conditions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.buttonBorder),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Terms & Conditions',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '• By submitting this referral, you confirm you have permission to share this contact information.\n'
                            '• Bug Bucks are awarded immediately upon submission.\n'
                            '• Referrals will be contacted within 24-48 hours.\n'
                            '• You can track referral status in your dashboard.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textNeutral,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Submit Button
                    PrimaryButton(
                      text: _isLoading ? 'Submitting...' : 'Submit Referral',
                      onPressed: _isLoading ? null : _submitReferral,
                      isLoading: _isLoading,
                    ),

                    const SizedBox(height: 16),

                    // Cancel Button - FIXED: Use _formHasChanges instead of isDirty
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                if (_formHasChanges) {
                                  _showDiscardDialog();
                                } else {
                                  Navigator.pop(context);
                                }
                              },
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

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDiscardDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context);
    }
  }
}
