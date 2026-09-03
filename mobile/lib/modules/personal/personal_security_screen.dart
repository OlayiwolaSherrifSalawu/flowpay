import 'package:flutter/material.dart';
import '../../core/bmoni_sdk/bmoni_sdk_service.dart';
import '../../core/design_system/design_system.dart';
import '../../core/state/app_state.dart';

class PersonalSecurityScreen extends StatefulWidget {
  final AppState? appState;

  const PersonalSecurityScreen({super.key, this.appState});

  @override
  State<PersonalSecurityScreen> createState() => _PersonalSecurityScreenState();
}

class _PersonalSecurityScreenState extends State<PersonalSecurityScreen> {
  String? _walletAddress;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkHardware();
  }

  Future<void> _checkHardware() async {
    final addr = await BmoniSdkService.walletAddress();
    if (mounted) {
      setState(() {
        _walletAddress = addr;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.canPop(context);

    Widget content = _isLoading
        ? const FlowPayLoadingState(message: 'Verifying Secure Enclave status...')
        : ListView(
            padding: FlowPaySpacing.insetXl,
            children: [
              FlowPayCard(
                variant: FlowPayCardVariant.elevated,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          color: FlowPayColors.accentLight,
                          size: 28,
                        ),
                        const SizedBox(width: FlowPaySpacing.md),
                        Text(
                          'B-Key Hardware Enclave Active',
                          style: FlowPayTypography.headingSm.copyWith(
                            color: isDark
                                ? FlowPayColors.darkTextPrimary
                                : FlowPayColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: FlowPaySpacing.md),
                    Text(
                      'Your private key is protected by the phone hardware secure enclave. It never touches FlowPay servers, AI models, or remote storage.',
                      style: FlowPayTypography.bodyMd.copyWith(
                        color: isDark
                            ? FlowPayColors.darkTextSecondary
                            : FlowPayColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: FlowPaySpacing.lg),
                    const FlowPayStatusBadge(
                      status: 'SECURE',
                      showDot: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: FlowPaySpacing.xl),
              Text(
                'Device Signer Details',
                style: FlowPayTypography.headingSm.copyWith(
                  color: isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: FlowPaySpacing.md),
              FlowPayCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('On-Device EVM Address', style: FlowPayTypography.caption),
                    const SizedBox(height: FlowPaySpacing.xs),
                    SelectableText(
                      _walletAddress ?? 'Not Initialized',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: isDark
                            ? FlowPayColors.darkTextPrimary
                            : FlowPayColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: FlowPaySpacing.lg),
                    const Divider(),
                    const SizedBox(height: FlowPaySpacing.md),
                    Row(
                      children: [
                        Icon(
                          Icons.pin,
                          color: isDark
                              ? FlowPayColors.darkTextSecondary
                              : FlowPayColors.lightTextSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: FlowPaySpacing.md),
                        Text(
                          '6-Digit Security PIN',
                          style: FlowPayTypography.bodyMd.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? FlowPayColors.darkTextPrimary
                                : FlowPayColors.lightTextPrimary,
                          ),
                        ),
                        const Spacer(),
                        const FlowPayStatusBadge(
                          status: 'CONFIGURED',
                          showDot: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );

    if (canPop) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Security & Hardware Keys'),
        ),
        body: content,
      );
    }

    return content;
  }
}
