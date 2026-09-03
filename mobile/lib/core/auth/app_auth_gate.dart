import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/colors.dart';
import '../theme/components.dart';
import '../theme/radii.dart';
import '../theme/typography.dart';
import 'account_capabilities.dart';
import 'account_mode_picker_modal.dart';
import 'app_lock_service.dart';
import 'auth_providers.dart';

/// App-Auth Gate: Controls biometric unlock, account mode resolution,
/// and lifecycle background re-lock.
class AppAuthGate extends ConsumerStatefulWidget {
  final Widget personalShell;
  final Widget businessShell;

  const AppAuthGate({
    super.key,
    required this.personalShell,
    required this.businessShell,
  });

  @override
  ConsumerState<AppAuthGate> createState() => _AppAuthGateState();
}

class _AppAuthGateState extends ConsumerState<AppAuthGate>
    with WidgetsBindingObserver {
  DateTime? _pausedTimestamp;
  final TextEditingController _pinController = TextEditingController();
  bool _pinError = false;
  bool _hasCheckedInitialPicker = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pinController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedTimestamp = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedTimestamp != null) {
        final elapsed = DateTime.now().difference(_pausedTimestamp!);
        // Re-lock if the app was backgrounded for more than 45 seconds
        if (elapsed.inSeconds >= 45) {
          ref.read(appLockStateProvider.notifier).lockApp();
        }
      }
      _pausedTimestamp = null;
    }
  }

  Future<void> _checkInitialModePicker(AccountCapabilities capabilities) async {
    if (_hasCheckedInitialPicker) return;
    _hasCheckedInitialPicker = true;

    final storage = ref.read(secureStorageServiceProvider);
    final storedMode = await storage.getAccountMode();

    // If returning user has both modes and no prior selection, show the picker
    if (storedMode == null && capabilities.hasBothModes && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final currentMode = ref.read(currentAccountModeProvider);
        final chosen = await AccountModePickerModal.show(
          context,
          initialMode: currentMode,
          capabilities: capabilities,
        );
        if (chosen != null && mounted) {
          await ref.read(appLockStateProvider.notifier).setAccountMode(chosen);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(appLockStateProvider);

    // 1. App is Locked -> Show Unlock Screen
    if (lockState.isLocked) {
      return _buildLockScreen(context, lockState);
    }

    // 2. App is Unlocked -> Resolve Capabilities & Shell
    final capabilitiesAsync = ref.watch(accountCapabilitiesProvider);

    return capabilitiesAsync.when(
      loading: () => const Scaffold(
        backgroundColor: FlowPayColors.canvas,
        body: Center(
          child: CircularProgressIndicator(
            color: FlowPayColors.ink,
          ),
        ),
      ),
      error: (err, stack) => _renderActiveShell(),
      data: (capabilities) {
        _checkInitialModePicker(capabilities);
        return _renderActiveShell();
      },
    );
  }

  Widget _renderActiveShell() {
    final activeMode = ref.watch(currentAccountModeProvider);
    switch (activeMode) {
      case AccountMode.personal:
        return widget.personalShell;
      case AccountMode.business:
        return widget.businessShell;
    }
  }

  Widget _buildLockScreen(BuildContext context, AppLockState lockState) {
    return Scaffold(
      backgroundColor: FlowPayColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              const Spacer(),

              // Brand Icon & Badge
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: FlowPayColors.ink,
                  borderRadius: BorderRadius.circular(FlowPayRadii.card),
                ),
                child: Icon(
                  lockState.hasFaceId
                      ? Icons.face_unlock_outlined
                      : (lockState.hasFingerprint
                          ? Icons.fingerprint
                          : Icons.shield_outlined),
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // Title & Subtitle
              const Text(
                'FlowPay is Locked',
                style: FlowPayTypography.headline,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Authenticate via ${lockState.biometricLabel} to access your multi-currency accounts and payroll engine.',
                style: const TextStyle(
                  fontSize: 14,
                  color: FlowPayColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Biometric hardware badge
              if (lockState.hasFaceId || lockState.hasFingerprint)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: FlowPayColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(FlowPayRadii.chip),
                    border: Border.all(color: FlowPayColors.hairline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        lockState.hasFaceId ? Icons.face : Icons.fingerprint,
                        size: 14,
                        color: FlowPayColors.ink,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${lockState.biometricLabel} Ready',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: FlowPayColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Fallback In-App PIN Entry
              if (lockState.showFallbackPin) ...[
                _buildPinEntry(),
                const SizedBox(height: 20),
              ],

              // Error or Status message
              if (lockState.lastResult?.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FlowPayColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(FlowPayRadii.input),
                    border: Border.all(color: FlowPayColors.hairline),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 18,
                        color: FlowPayColors.ink,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lockState.lastResult!.errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: FlowPayColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              const Spacer(),

              // Primary Unlock Button (Face ID / Fingerprint / Passcode)
              FlowPayButton(
                text: lockState.isAuthenticating
                    ? 'Verifying...'
                    : 'Unlock with ${lockState.biometricLabel}',
                icon: lockState.hasFaceId ? Icons.face : Icons.fingerprint,
                onPressed: lockState.isAuthenticating
                    ? null
                    : () {
                        ref.read(appLockStateProvider.notifier).authenticate();
                      },
              ),

              const SizedBox(height: 12),

              // Manual PIN Fallback Toggle Button
              if (!lockState.showFallbackPin)
                TextButton.icon(
                  icon: const Icon(Icons.pin_outlined, size: 16, color: FlowPayColors.ink),
                  label: const Text(
                    'Use 6-Digit In-App PIN',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: FlowPayColors.ink,
                    ),
                  ),
                  onPressed: () {
                    // Show in-app PIN entry
                    ref.read(appLockStateProvider.notifier).state =
                        lockState.copyWith(showFallbackPin: true);
                  },
                ),

              // Demo Unlock Bypass / Fallback Toggle
              GestureDetector(
                onTap: () {
                  // Direct bypass for demo & review convenience
                  ref.read(appLockStateProvider.notifier).verifyFallbackPin('123456');
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bolt, size: 14, color: FlowPayColors.amber),
                      SizedBox(width: 4),
                      Text(
                        'Demo Quick Unlock (Passcode: 123456)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: FlowPayColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinEntry() {
    return Column(
      children: [
        const Text(
          'Enter 6-Digit App Lock PIN',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: FlowPayColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: 220,
          decoration: BoxDecoration(
            color: FlowPayColors.surface,
            borderRadius: BorderRadius.circular(FlowPayRadii.input),
            border: Border.all(
              color: _pinError ? FlowPayColors.stateError : FlowPayColors.hairline,
            ),
          ),
          child: TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              letterSpacing: 12,
              fontWeight: FontWeight.w700,
              color: FlowPayColors.ink,
            ),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              hintText: '••••••',
              hintStyle: TextStyle(
                color: FlowPayColors.textTertiary,
                letterSpacing: 8,
              ),
            ),
            onChanged: (val) async {
              if (val.length == 6) {
                final success = await ref
                    .read(appLockStateProvider.notifier)
                    .verifyFallbackPin(val);
                if (!success) {
                  setState(() => _pinError = true);
                }
              } else {
                if (_pinError) setState(() => _pinError = false);
              }
            },
          ),
        ),
      ],
    );
  }
}
