import 'package:flutter/material.dart';
import '../../core/repositories/wallet_repository.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/components.dart';
import '../../core/theme/typography.dart';

class WalletsScreen extends StatefulWidget {
  final AppState appState;

  const WalletsScreen({Key? key, required this.appState}) : super(key: key);

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  List<WalletAccount> wallets = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    final list = await widget.appState.walletRepo.getWallets();
    setState(() {
      wallets = list;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowPayColors.background,
      appBar: AppBar(
        backgroundColor: FlowPayColors.background,
        elevation: 0,
        title: const Text('Smart Wallets', style: FlowPayTypography.headingSm),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: FlowPayColors.primary))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                FlowPayCard(
                  backgroundColor: FlowPayColors.surfaceSubtle,
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: FlowPayColors.accentLight, size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Secure Hardware Isolation', style: FlowPayTypography.headingSm),
                            SizedBox(height: 4),
                            Text(
                              'Private keys never leave your phone. Created and protected on-device via BMONI B-Key SDK.',
                              style: FlowPayTypography.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('Configured Wallets', style: FlowPayTypography.headingSm),
                const SizedBox(height: 12),
                ...wallets.map((w) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FlowPayCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(w.currency.name, style: FlowPayTypography.headingSm),
                              const SizedBox(width: 8),
                              StatusBadge(status: w.status),
                              const Spacer(),
                              Text(w.balance.formatFormatted(), style: FlowPayTypography.financialMedium),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: FlowPayColors.border),
                          const SizedBox(height: 8),
                          Text('Contract Address', style: FlowPayTypography.caption),
                          const SizedBox(height: 4),
                          SelectableText(
                            w.address,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              color: FlowPayColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text('Token: ${w.stablecoinToken}', style: FlowPayTypography.caption),
                              const Spacer(),
                              Text('Chain: Base Sepolia', style: FlowPayTypography.caption),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
    );
  }
}
