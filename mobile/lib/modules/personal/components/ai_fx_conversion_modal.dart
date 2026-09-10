import 'package:flutter/material.dart';
import '../../../core/bmoni_sdk/bmoni_sdk_service.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/repositories/activity_repository.dart';
import '../../../core/state/personal_provider.dart';

class AiFxConversionModal extends StatefulWidget {
  final PersonalProvider personalProvider;
  final Money initialAmount;

  const AiFxConversionModal({
    super.key,
    required this.personalProvider,
    required this.initialAmount,
  });

  @override
  State<AiFxConversionModal> createState() => _AiFxConversionModalState();
}

class _AiFxConversionModalState extends State<AiFxConversionModal> {
  late TextEditingController _amountController;
  final TextEditingController _pinController = TextEditingController();
  bool _isConverting = false;
  final double _exchangeRate = 1550.0;

  @override
  void initState() {
    super.initState();
    _amountController =
        TextEditingController(text: widget.initialAmount.majorUnits.toString());
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double get _usdAmount {
    return double.tryParse(_amountController.text) ?? 1000.0;
  }

  double get _ngnAmount {
    return _usdAmount * _exchangeRate;
  }

  Future<void> _handleConvert() async {
    final pin = _pinController.text.trim();
    if (pin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your 6-digit PIN')),
      );
      return;
    }

    setState(() => _isConverting = true);

    try {
      final pinOk = await BmoniSdkService.matchPin(pin);
      if (!pinOk) {
        throw Exception('Invalid 6-digit Security PIN');
      }

      await Future.delayed(const Duration(milliseconds: 300));

      final activity = ActivityModel(
        id: 'fx_${DateTime.now().millisecondsSinceEpoch}',
        type: ActivityType.conversion,
        title: 'FX: \$${_usdAmount.toStringAsFixed(2)} → NGN',
        description:
            'Converted \$${_usdAmount.toStringAsFixed(2)} to ₦${_ngnAmount.toStringAsFixed(2)}',
        amount: Money.fromMajorString(_usdAmount.toStringAsFixed(2), Currency.usd),
        currency: Currency.usd,
        status: FlowPayAppStatus.completed,
        timestamp: DateTime.now(),
        destination: 'Nigerian Naira Wallet',
        source: 'USD Treasury Wallet',
      );
      widget.personalProvider.addActivity(activity);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Successfully converted \$${_usdAmount.toStringAsFixed(2)} to ₦${_ngnAmount.toStringAsFixed(2)}'),
            backgroundColor: FlowPayColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConverting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conversion failed: $e'),
            backgroundColor: FlowPayColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? FlowPayColors.darkBackground : FlowPayColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: FlowPayColors.darkBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: FlowPayColors.primary.withAlpha(35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.currency_exchange,
                        color: FlowPayColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Instant Currency Exchange',
                        style: FlowPayTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.lightTextPrimary,
                        ),
                      ),
                      const Text(
                        'Low-fee exchange rates',
                        style: TextStyle(
                          fontSize: 12,
                          color: FlowPayColors.darkTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Real-time exchange rate with instant conversion.',
                style: FlowPayTypography.captionStyle(
                  color: FlowPayColors.darkTextSecondary,
                ),
              ),
              const SizedBox(height: 16),

              // Rate banner
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: FlowPayColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: FlowPayColors.hairline),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Spot Exchange Rate',
                        style: TextStyle(
                            fontSize: 12, color: FlowPayColors.darkTextSecondary)),
                    Text(
                      '1 USD = $_exchangeRate NGN',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: FlowPayColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Source Amount Box
              Text('YOU CONVERT',
                  style: FlowPayTypography.caption.copyWith(
                      fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? FlowPayColors.darkSurface : FlowPayColors.lightSurfaceElevated,
                  borderRadius: FlowPaySpacing.borderRadiusMd,
                  border: Border.all(
                    color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    const Text('\$',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.lightTextPrimary,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '1000.00',
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const Text('USD',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: FlowPayColors.primary)),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Target Amount Box
              Text('YOU RECEIVE',
                  style: FlowPayTypography.caption.copyWith(
                      fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? FlowPayColors.darkSurface : FlowPayColors.lightSurfaceElevated,
                  borderRadius: FlowPaySpacing.borderRadiusMd,
                  border: Border.all(
                    color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₦${_ngnAmount.toStringAsFixed(2)}',
                      style: FlowPayTypography.amount(
                        color: FlowPayColors.primary,
                      ).copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Text('NGN',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: FlowPayColors.primary)),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Fee details
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Network Processing Fee',
                      style: TextStyle(fontSize: 12, color: FlowPayColors.darkTextSecondary)),
                  Text(
                    '\$0.05 (99.8% saved)',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: FlowPayColors.primaryLight),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // PIN Input
              const Text('Enter 6-Digit Security PIN to Authorize',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: FlowPayColors.darkTextSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18,
                    letterSpacing: 8,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '••••••',
                  counterText: '',
                  filled: true,
                  fillColor: isDark ? FlowPayColors.darkSurface : Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: FlowPayColors.darkBorder)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: FlowPayColors.primary, width: 1.5)),
                ),
              ),
              const SizedBox(height: 18),

              FlowPayButton(
                text: 'Convert',
                icon: Icons.currency_exchange,
                isFullWidth: true,
                size: FlowPayButtonSize.large,
                isLoading: _isConverting,
                onPressed: _handleConvert,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
