// lib/features/dashboard/screens/athlete/athlete_cashout_screen.dart
//
// Reuses the same cashout flow as EmployeeCashoutScreen but with purple theme.
// Full payout request: Bank Transfer or Mobile Money, reads payoutMinimum from
// app_config/settings, creates payout_requests doc.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/providers/auth_provider.dart';
import 'athlete_payout_history_screen.dart';

const _kPurple = Color(0xFF6A1B9A);

class AthleteCashoutScreen extends ConsumerStatefulWidget {
  const AthleteCashoutScreen({super.key});
  @override
  ConsumerState<AthleteCashoutScreen> createState() =>
      _AthleteCashoutScreenState();
}

class _AthleteCashoutScreenState extends ConsumerState<AthleteCashoutScreen> {
  double? _walletBalance;
  double _payoutMinimum = 50.0;
  bool _loading = true;
  String? _error;

  final _amountCtrl = TextEditingController();
  String _method = 'bank';
  bool _termsAccepted = false;
  bool _submitting = false;

  // Bank fields
  final _holderCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _routingCtrl = TextEditingController();

  // Mobile money fields
  String? _mobileProvider;
  final _phoneCtrl = TextEditingController();

  static const _providers = [
    'M-Pesa',
    'Airtel Money',
    'MTN MoMo',
    'Venmo',
    'Cash App',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _amountCtrl,
      _holderCtrl,
      _bankCtrl,
      _accountCtrl,
      _routingCtrl,
      _phoneCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = ref.read(authProvider).user?.uid ?? '';
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
        FirebaseFirestore.instance
            .collection('app_config')
            .doc('settings')
            .get(),
      ]);
      final userDoc = results[0] as DocumentSnapshot;
      final cfgDoc = results[1] as DocumentSnapshot;
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      final cfgData = cfgDoc.data() as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _walletBalance =
              (userData['walletBalance'] as num?)?.toDouble() ?? 0.0;
          _payoutMinimum =
              (cfgData['payoutMinimum'] as num?)?.toDouble() ?? 50.0;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  String? get _amountError {
    final v = double.tryParse(_amountCtrl.text.trim());
    if (v == null) return null;
    if (v < _payoutMinimum)
      return 'Minimum payout is \$${_payoutMinimum.toStringAsFixed(2)}';
    if (v > (_walletBalance ?? 0)) return 'Exceeds your available balance';
    return null;
  }

  bool get _canSubmit {
    final v = double.tryParse(_amountCtrl.text.trim());
    if (v == null || _amountError != null || !_termsAccepted || _submitting)
      return false;
    if (_method == 'bank') {
      return _holderCtrl.text.isNotEmpty &&
          _bankCtrl.text.isNotEmpty &&
          _accountCtrl.text.isNotEmpty &&
          _routingCtrl.text.isNotEmpty;
    }
    return _mobileProvider != null && _phoneCtrl.text.isNotEmpty;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    try {
      final uid = ref.read(authProvider).user?.uid ?? '';
      final amount = double.parse(_amountCtrl.text.trim());
      final accountDetails = _method == 'bank'
          ? {
              'holderName': _holderCtrl.text.trim(),
              'bankName': _bankCtrl.text.trim(),
              'accountNumber': _accountCtrl.text.trim(),
              'routingNumber': _routingCtrl.text.trim(),
            }
          : {
              'provider': _mobileProvider,
              'phoneNumber': _phoneCtrl.text.trim(),
            };
      await FirebaseFirestore.instance.collection('payout_requests').add({
        'userId': uid,
        'amount': amount,
        'method': _method,
        'accountDetails': accountDetails,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() => _submitting = false);
        _showSuccessDialog(amount);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showSuccessDialog(double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Request Submitted!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Your payout request for \$${amount.toStringAsFixed(2)} has been submitted.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textNeutral, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AthletePayoutHistoryScreen(),
                ),
              );
            },
            child: const Text(
              'View History',
              style: TextStyle(color: _kPurple),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPurple,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AthletePayoutHistoryScreen(),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kPurple))
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textNeutral),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _load,
                    style: ElevatedButton.styleFrom(backgroundColor: _kPurple),
                    child: const Text(
                      'Retry',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          : _buildForm(),
    );
  }

  Widget _buildForm() {
    final balance = _walletBalance ?? 0.0;
    final amountVal = double.tryParse(_amountCtrl.text.trim());
    final amountOk = amountVal != null && _amountError == null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4A0072), _kPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _kPurple.withOpacity(0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Available Balance',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  '\$${balance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1.5,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Min. payout: \$${_payoutMinimum.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),
          _label('Amount'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixText: '\$ ',
                    prefixStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: AppColors.textDark,
                    ),
                    hintText: '0.00',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kPurple, width: 1.5),
                    ),
                    errorText: _amountCtrl.text.isEmpty ? null : _amountError,
                    helperText: amountOk ? 'Amount looks good ✓' : null,
                    helperStyle: const TextStyle(color: AppColors.success),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  _amountCtrl.text = balance.toStringAsFixed(2);
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: _kPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kPurple.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'MAX',
                    style: TextStyle(
                      color: _kPurple,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          _label('Payout Method'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _methodTile(
                  'bank',
                  Icons.account_balance_rounded,
                  'Bank Transfer',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _methodTile(
                  'mobile_money',
                  Icons.phone_android_rounded,
                  'Mobile Money',
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          if (_method == 'bank') ...[
            _label('Account Details'),
            const SizedBox(height: 10),
            _field(_holderCtrl, 'Account Holder Name'),
            const SizedBox(height: 10),
            _field(_bankCtrl, 'Bank Name'),
            const SizedBox(height: 10),
            _field(_accountCtrl, 'Account Number', type: TextInputType.number),
            const SizedBox(height: 10),
            _field(_routingCtrl, 'Routing Number', type: TextInputType.number),
          ] else ...[
            _label('Mobile Money Details'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _mobileProvider,
                  isExpanded: true,
                  hint: const Text(
                    'Select Provider',
                    style: TextStyle(color: AppColors.textLight, fontSize: 14),
                  ),
                  onChanged: (v) => setState(() => _mobileProvider = v),
                  items: _providers
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _field(_phoneCtrl, 'Phone Number', type: TextInputType.phone),
          ],

          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => setState(() => _termsAccepted = !_termsAccepted),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _termsAccepted ? _kPurple : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _termsAccepted
                          ? _kPurple
                          : const Color(0xFFCCCCCC),
                      width: 1.5,
                    ),
                  ),
                  child: _termsAccepted
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 14,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'I confirm that the payout details above are correct and authorize this request.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textNeutral,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPurple,
                disabledBackgroundColor: _kPurple.withOpacity(0.35),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Submit Payout Request',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _methodTile(String val, IconData icon, String label) {
    final selected = _method == val;
    return GestureDetector(
      onTap: () => setState(() => _method = val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? _kPurple.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _kPurple : const Color(0xFFE0E0E0),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? _kPurple : AppColors.textNeutral,
              size: 22,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? _kPurple : AppColors.textNeutral,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: AppColors.textDark,
    ),
  );

  Widget _field(
    TextEditingController ctrl,
    String hint, {
    TextInputType type = TextInputType.text,
  }) => TextField(
    controller: ctrl,
    keyboardType: type,
    inputFormatters: type == TextInputType.number
        ? [FilteringTextInputFormatter.digitsOnly]
        : null,
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kPurple, width: 1.5),
      ),
      contentPadding: const EdgeInsets.all(14),
    ),
  );
}
