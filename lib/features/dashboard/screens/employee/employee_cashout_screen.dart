import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/primary_button.dart';

class EmployeeCashoutScreen extends ConsumerStatefulWidget {
  const EmployeeCashoutScreen({super.key});

  @override
  _EmployeeCashoutScreenState createState() => _EmployeeCashoutScreenState();
}

class _EmployeeCashoutScreenState extends ConsumerState<EmployeeCashoutScreen> {
  double _availableBalance = 1250.00; // TODO: Fetch from Firebase
  double _requestedAmount = 0.0;

  final TextEditingController _amountController = TextEditingController();
  String _selectedPaymentMethod = 'Direct Deposit';
  final List<String> _paymentMethods = [
    'Direct Deposit',
    'PayPal',
    'Venmo',
    'Check',
  ];

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_updateRequestedAmount);
  }

  void _updateRequestedAmount() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    setState(() {
      _requestedAmount = amount;
    });
  }

  Future<void> _requestCashout() async {
    if (_requestedAmount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    if (_requestedAmount > _availableBalance) {
      _showError('Amount exceeds available balance');
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Cashout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to request cashout?'),
            const SizedBox(height: 8),
            Text('Amount: \$$_requestedAmount'),
            Text('Payment Method: $_selectedPaymentMethod'),
            const SizedBox(height: 8),
            const Text(
              'Processing time: 3-5 business days',
              style: TextStyle(fontSize: 12, color: AppColors.textNeutral),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _processCashout();
    }
  }

  Future<void> _processCashout() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // TODO: Implement cashout request to Firebase
      await Future.delayed(const Duration(seconds: 2)); // Simulate API call

      Navigator.pop(context); // Remove loading

      // Show success dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success),
              SizedBox(width: 8),
              Text('Success!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cashout request submitted for \$$_requestedAmount'),
              const SizedBox(height: 8),
              const Text(
                'Your request will be processed within 3-5 business days.',
                style: TextStyle(fontSize: 14, color: AppColors.textNeutral),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close success dialog
                Navigator.pop(context); // Go back to dashboard
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );

      // Update local balance
      setState(() {
        _availableBalance -= _requestedAmount;
        _amountController.clear();
        _requestedAmount = 0.0;
      });
    } catch (e) {
      Navigator.pop(context); // Remove loading
      _showError('Failed to submit cashout request: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double newBalance = _availableBalance - _requestedAmount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Out Bonuses'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balance Summary
              AppCard(
                child: Column(
                  children: [
                    const Text(
                      'Available Balance',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textNeutral,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$$_availableBalance',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ready for withdrawal',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textNeutral,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Cashout Form
              const Text(
                'Request Cashout',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 16),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Amount Input
                    const Text(
                      'Amount to Cash Out *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        prefixText: '\$',
                        hintText: 'Enter amount',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.all_inclusive),
                          onPressed: () {
                            _amountController.text = _availableBalance
                                .toString();
                            _updateRequestedAmount();
                          },
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: 16),

                    // Payment Method
                    const Text(
                      'Payment Method *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedPaymentMethod,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: _paymentMethods.map((method) {
                        return DropdownMenuItem(
                          value: method,
                          child: Text(method),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPaymentMethod = value!;
                        });
                      },
                    ),

                    const SizedBox(height: 24),

                    // Quick Amount Buttons
                    const Text(
                      'Quick Select',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textNeutral,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _amountController.text = '100';
                              _updateRequestedAmount();
                            },
                            child: const Text('\$100'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _amountController.text = '250';
                              _updateRequestedAmount();
                            },
                            child: const Text('\$250'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _amountController.text = '500';
                              _updateRequestedAmount();
                            },
                            child: const Text('\$500'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Summary
              const Text(
                'Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),

              AppCard(
                child: Column(
                  children: [
                    _buildSummaryRow('Requested Amount', '\$$_requestedAmount'),
                    const Divider(height: 24),
                    _buildSummaryRow(
                      'Processing Fee',
                      '\$0.00', // TODO: Add if there's a fee
                    ),
                    const Divider(height: 24),
                    _buildSummaryRow('Payment Method', _selectedPaymentMethod),
                    const Divider(height: 24),
                    _buildSummaryRow(
                      'New Balance',
                      '\$$newBalance',
                      isTotal: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Submit Button
              PrimaryButton(
                text: 'Submit Cashout Request',
                onPressed: _requestCashout,
              ),

              const SizedBox(height: 16),

              // Cancel Button
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  side: BorderSide(color: AppColors.border),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textDark),
                ),
              ),

              const SizedBox(height: 24),

              // Information Section
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Important Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoItem('Processing Time:', '3-5 business days'),
                    _buildInfoItem('Minimum Amount:', '\$50.00'),
                    _buildInfoItem(
                      'Payment Methods:',
                      'Direct Deposit, PayPal, Venmo, or Check',
                    ),
                    _buildInfoItem(
                      'Taxes:',
                      'You are responsible for any applicable taxes',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: isTotal ? AppColors.primary : AppColors.textDark,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 18 : 16,
            fontWeight: FontWeight.w700,
            color: isTotal ? AppColors.primary : AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textDark,
            ),
          ),
          Text(
            description,
            style: const TextStyle(fontSize: 14, color: AppColors.textNeutral),
          ),
        ],
      ),
    );
  }
}
