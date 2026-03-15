// lib/features/dashboard/screens/employee/employee_cashout_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/providers/auth_provider.dart';
import 'employee_payout_history_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Payout method
// ─────────────────────────────────────────────────────────────────────────────
enum _PayoutMethod { bank, mobileMoney }

class EmployeeCashoutScreen extends ConsumerStatefulWidget {
  const EmployeeCashoutScreen({super.key});

  @override
  ConsumerState<EmployeeCashoutScreen> createState() =>
      _EmployeeCashoutScreenState();
}

class _EmployeeCashoutScreenState extends ConsumerState<EmployeeCashoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();

  // Bank fields
  final _accountHolderCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _routingNumberCtrl = TextEditingController();

  // Mobile money fields
  final _mobileProviderCtrl = TextEditingController();
  final _mobilePhoneCtrl = TextEditingController();

  _PayoutMethod _method = _PayoutMethod.bank;
  bool _termsChecked = false;
  bool _loading = true;
  bool _submitting = false;

  double _balance = 0.0;
  double _minimumPayout = 20.0; // default; overridden from app_config

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _accountHolderCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _routingNumberCtrl.dispose();
    _mobileProviderCtrl.dispose();
    _mobilePhoneCtrl.dispose();
    super.dispose();
  }

  // ── Load balance + minimum payout from Firestore ───────────────────────────
  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final uid = ref.read(authProvider).user?.uid;
      if (uid == null) throw Exception('Not authenticated');

      final results = await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
        FirebaseFirestore.instance
            .collection('app_config')
            .doc('settings')
            .get(),
      ]);

      final userDoc = results[0] as DocumentSnapshot;
      final configDoc = results[1] as DocumentSnapshot;

      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      final configData = configDoc.exists
          ? configDoc.data() as Map<String, dynamic>
          : <String, dynamic>{};

      if (mounted) {
        setState(() {
          _balance = (userData['walletBalance'] as num?)?.toDouble() ?? 0.0;
          _minimumPayout =
              (configData['payoutMinimum'] as num?)?.toDouble() ?? 20.0;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _showSnack('Failed to load data: $e', AppColors.error);
    }
  }

  // ── Submit payout request ──────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_termsChecked) {
      _showSnack('Please confirm the amount is correct', Colors.orange);
      return;
    }

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount < _minimumPayout) {
      _showSnack(
        'Minimum payout is \$${_minimumPayout.toStringAsFixed(2)}',
        AppColors.error,
      );
      return;
    }
    if (amount > _balance) {
      _showSnack('Amount exceeds available balance', AppColors.error);
      return;
    }

    setState(() => _submitting = true);

    try {
      final uid = ref.read(authProvider).user?.uid;
      if (uid == null) throw Exception('Not authenticated');

      // Build account details map based on method
      final Map<String, dynamic> accountDetails;
      if (_method == _PayoutMethod.bank) {
        accountDetails = {
          'accountHolderName': _accountHolderCtrl.text.trim(),
          'bankName': _bankNameCtrl.text.trim(),
          'accountNumber': _accountNumberCtrl.text.trim(),
          'routingNumber': _routingNumberCtrl.text.trim(),
        };
      } else {
        accountDetails = {
          'provider': _mobileProviderCtrl.text.trim(),
          'phoneNumber': _mobilePhoneCtrl.text.trim(),
        };
      }

      // Create PayoutRequest document matching the model
      await FirebaseFirestore.instance.collection('payout_requests').add({
        'userId': uid,
        'amount': amount,
        'method': _method == _PayoutMethod.bank ? 'bank' : 'mobile_money',
        'accountDetails': accountDetails,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
        'processedAt': null,
      });

      if (mounted) _showSuccessDialog(amount);
    } catch (e) {
      if (mounted) {
        _showSnack('Submission failed: $e', AppColors.error);
        setState(() => _submitting = false);
      }
    }
  }

  void _showSuccessDialog(double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Request Submitted!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your payout request for \$${amount.toStringAsFixed(2)} has been submitted. '
              'You\'ll be notified once it\'s processed by the admin.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textNeutral,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EmployeePayoutHistoryScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'View Payout History',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Back to Dashboard',
                  style: TextStyle(
                    color: AppColors.textNeutral,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final enteredAmount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final isAmountValid =
        enteredAmount >= _minimumPayout && enteredAmount <= _balance;
    final canSubmit = isAmountValid && _termsChecked && !_submitting;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Request Payout',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Payout History',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EmployeePayoutHistoryScreen(),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Balance card ──────────────────────────────────────
                    _buildBalanceCard(),

                    const SizedBox(height: 20),

                    // ── Amount input ──────────────────────────────────────
                    _sectionHeader(
                      icon: Icons.attach_money_rounded,
                      color: AppColors.primary,
                      title: 'Withdrawal Amount',
                    ),
                    const SizedBox(height: 12),
                    _buildAmountField(),

                    const SizedBox(height: 24),

                    // ── Payout method ─────────────────────────────────────
                    _sectionHeader(
                      icon: Icons.payments_rounded,
                      color: const Color(0xFF1565C0),
                      title: 'Payout Method',
                    ),
                    const SizedBox(height: 12),
                    _buildMethodSelector(),

                    const SizedBox(height: 16),

                    // Method form
                    if (_method == _PayoutMethod.bank)
                      _buildBankForm()
                    else
                      _buildMobileMoneyForm(),

                    const SizedBox(height: 24),

                    // ── Terms checkbox ────────────────────────────────────
                    _buildTermsCheckbox(),
                  ],
                ),
              ),
            ),
      // ── Sticky submit button ───────────────────────────────────────────────
      bottomNavigationBar: _loading
          ? null
          : Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                MediaQuery.of(context).padding.bottom + 12,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: canSubmit ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: const Color(0xFFB2DFDB),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _submitting
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Submitting...',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Submit Request',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
    );
  }

  // ── Balance card ───────────────────────────────────────────────────────────
  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(0.85), AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Available Balance',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '\$${_balance.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white70,
                  size: 13,
                ),
                const SizedBox(width: 5),
                Text(
                  'Minimum payout: \$${_minimumPayout.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Amount input ───────────────────────────────────────────────────────────
  Widget _buildAmountField() {
    final entered = double.tryParse(_amountCtrl.text.trim()) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
          onChanged: (_) => setState(() {}),
          validator: (v) {
            final val = double.tryParse(v ?? '');
            if (val == null || val <= 0) return 'Enter a valid amount';
            if (val < _minimumPayout) {
              return 'Minimum is \$${_minimumPayout.toStringAsFixed(2)}';
            }
            if (val > _balance) return 'Exceeds available balance';
            return null;
          },
          decoration: InputDecoration(
            prefixText: '\$ ',
            prefixStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
            suffix: GestureDetector(
              onTap: () {
                _amountCtrl.text = _balance.toStringAsFixed(2);
                setState(() {});
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'MAX',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
          ),
        ),
        // Live hint beneath the field
        if (_amountCtrl.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                entered >= _minimumPayout && entered <= _balance
                    ? Icons.check_circle_outline_rounded
                    : Icons.error_outline_rounded,
                size: 13,
                color: entered >= _minimumPayout && entered <= _balance
                    ? AppColors.success
                    : AppColors.error,
              ),
              const SizedBox(width: 5),
              Text(
                entered >= _minimumPayout && entered <= _balance
                    ? 'Amount looks good'
                    : entered > _balance
                    ? 'Exceeds your balance of \$${_balance.toStringAsFixed(2)}'
                    : 'Below minimum of \$${_minimumPayout.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  color: entered >= _minimumPayout && entered <= _balance
                      ? AppColors.success
                      : AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Method selector ────────────────────────────────────────────────────────
  Widget _buildMethodSelector() {
    return Row(
      children: [
        Expanded(
          child: _MethodTile(
            icon: Icons.account_balance_rounded,
            label: 'Bank Transfer',
            color: const Color(0xFF1565C0),
            selected: _method == _PayoutMethod.bank,
            onTap: () => setState(() => _method = _PayoutMethod.bank),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MethodTile(
            icon: Icons.smartphone_rounded,
            label: 'Mobile Money',
            color: const Color(0xFF6A1B9A),
            selected: _method == _PayoutMethod.mobileMoney,
            onTap: () => setState(() => _method = _PayoutMethod.mobileMoney),
          ),
        ),
      ],
    );
  }

  // ── Bank form ──────────────────────────────────────────────────────────────
  Widget _buildBankForm() {
    return _formCard(
      icon: Icons.account_balance_rounded,
      color: const Color(0xFF1565C0),
      title: 'Bank Transfer Details',
      children: [
        _fieldLabel('Account Holder Name', required: true),
        const SizedBox(height: 8),
        _buildField(
          controller: _accountHolderCtrl,
          hint: 'e.g. John Smith',
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 14),
        _fieldLabel('Bank Name', required: true),
        const SizedBox(height: 8),
        _buildField(
          controller: _bankNameCtrl,
          hint: 'e.g. Chase, Bank of America',
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 14),
        _fieldLabel('Account Number', required: true),
        const SizedBox(height: 8),
        _buildField(
          controller: _accountNumberCtrl,
          hint: 'e.g. 000123456789',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 14),
        _fieldLabel('Routing Number', required: true),
        const SizedBox(height: 8),
        _buildField(
          controller: _routingNumberCtrl,
          hint: 'e.g. 021000021',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
      ],
    );
  }

  // ── Mobile money form ──────────────────────────────────────────────────────
  Widget _buildMobileMoneyForm() {
    return _formCard(
      icon: Icons.smartphone_rounded,
      color: const Color(0xFF6A1B9A),
      title: 'Mobile Money Details',
      children: [
        _fieldLabel('Provider', required: true),
        const SizedBox(height: 8),
        // Provider dropdown
        DropdownButtonFormField<String>(
          value: _mobileProviderCtrl.text.isEmpty
              ? null
              : _mobileProviderCtrl.text,
          decoration: _fieldDecoration('Select provider'),
          items: const [
            DropdownMenuItem(value: 'M-Pesa', child: Text('M-Pesa')),
            DropdownMenuItem(
              value: 'Airtel Money',
              child: Text('Airtel Money'),
            ),
            DropdownMenuItem(value: 'MTN MoMo', child: Text('MTN MoMo')),
            DropdownMenuItem(value: 'Venmo', child: Text('Venmo')),
            DropdownMenuItem(value: 'Cash App', child: Text('Cash App')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _mobileProviderCtrl.text = v);
          },
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Please select a provider' : null,
          style: const TextStyle(fontSize: 14, color: AppColors.textDark),
        ),
        const SizedBox(height: 14),
        _fieldLabel('Phone Number', required: true),
        const SizedBox(height: 8),
        _buildField(
          controller: _mobilePhoneCtrl,
          hint: 'e.g. +254 700 000 000',
          keyboardType: TextInputType.phone,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
      ],
    );
  }

  // ── Terms checkbox ─────────────────────────────────────────────────────────
  Widget _buildTermsCheckbox() {
    return GestureDetector(
      onTap: () => setState(() => _termsChecked = !_termsChecked),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _termsChecked
              ? AppColors.primary.withOpacity(0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _termsChecked
                ? AppColors.primary.withOpacity(0.3)
                : const Color(0xFFE5E5E5),
            width: _termsChecked ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: _termsChecked ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _termsChecked
                      ? AppColors.primary
                      : const Color(0xFFCCCCCC),
                  width: 2,
                ),
              ),
              child: _termsChecked
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 14,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'I confirm that the withdrawal amount and account details above are correct. '
                'Incorrect details may result in delayed or failed payouts.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textDark,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _formCard({
    required IconData icon,
    required Color color,
    required String title,
    required List<Widget> children,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, color: Color(0xFFF0F0F0)),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );

  Widget _sectionHeader({
    required IconData icon,
    required Color color,
    required String title,
  }) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 10),
      Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
    ],
  );

  Widget _fieldLabel(String text, {bool required = false}) => Row(
    children: [
      Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      ),
      if (required) ...[
        const SizedBox(width: 4),
        const Text('*', style: TextStyle(color: AppColors.error, fontSize: 13)),
      ],
    ],
  );

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
    filled: true,
    fillColor: const Color(0xFFF8F9FA),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
  );

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    validator: validator,
    style: const TextStyle(fontSize: 14, color: AppColors.textDark),
    decoration: _fieldDecoration(hint),
  );

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Method tile
// ─────────────────────────────────────────────────────────────────────────────
class _MethodTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _MethodTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : const Color(0xFFE5E5E5),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? color : AppColors.textNeutral,
              size: 26,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : AppColors.textNeutral,
              ),
            ),
            if (selected) ...[
              const SizedBox(height: 4),
              Icon(Icons.check_circle_rounded, color: color, size: 14),
            ],
          ],
        ),
      ),
    );
  }
}
