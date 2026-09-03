import 'package:flutter/material.dart';
import '../../core/bmoni_sdk/bmoni_sdk_service.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/components.dart';
import '../../core/theme/typography.dart';

class PersonalSecurityScreen extends StatefulWidget {
  final AppState appState;

  const PersonalSecurityScreen({Key? key, required this.appState}) : super(key: key);

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
    setState(() {
      _walletAddress = addr;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowPayColors.background,
      appBar: AppBar(
        backgroundColor: FlowPayColors.background,
        elevation: 0,
        title: const Text('Security & Hardware Keys', style: FlowPayTypography.headingSm),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: FlowPayColors.primary))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                FlowPayCard(
                  backgroundColor: FlowPayColors.surfaceElevated,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.verified_user_outlined, color: FlowPayColors.accentLight, size: 28),
                          SizedBox(width: 12),
                          Text('B-Key Hardware Enclave Active', style: FlowPayTypography.headingSm),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Your private key is protected by the phone hardware secure enclave. It never touches FlowPay servers, AI models, or remote storage.',
                        style: FlowPayTypography.bodyMd,
                      ),
                      const SizedBox(height: 16),
                      const StatusBadge(status: 'SECURE ELEMENT ENFORCED'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('Device Signer Details', style: FlowPayTypography.headingSm),
                const SizedBox(height: 12),
                FlowPayCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('On-Device EVM Address', style: FlowPayTypography.caption),
                      const SizedBox(height: 4),
                      SelectableText(
                        _walletAddress ?? 'Not Initialized',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: FlowPayColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: FlowPayColors.border),
                      const SizedBox(height: 12),
                      Row(
                        children: const [
                          Icon(Icons.pin, color: FlowPayColors.textSecondary, size: 20),
                          SizedBox(width: 10),
                          Text('6-Digit Security PIN', style: FlowPayTypography.bodyLg),
                          Spacer(),
                          StatusBadge(status: 'Configured'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
