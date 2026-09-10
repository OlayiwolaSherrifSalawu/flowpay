import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../design_system/design_system.dart';
import '../state/app_state.dart';
import 'account_capabilities.dart';
import 'account_mode_picker_modal.dart';
import 'auth_providers.dart';
import '../../modules/auth/signup_screen.dart';
import '../../modules/auth/login_screen.dart';


/// App-Auth Gate: Controls biometric unlock, account mode resolution,
/// and lifecycle background re-lock.
class AppAuthGate extends ConsumerStatefulWidget {
  final Widget personalShell;
  final Widget businessShell;
  final AppState? appState;

  const AppAuthGate({
    super.key,
    required this.personalShell,
    required this.businessShell,
    this.appState,
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

    // 1. User has no active authenticated session -> Absolutely no app entry. Show Login.
    if (!lockState.hasSession) {
      return const LoginScreen();
    }

    // 2. App is Locked -> Show Unlock Screen
    if (lockState.isLocked) {
      return _buildLockScreen(context, lockState);
    }

    // 3. App is Unlocked & Session Active -> Resolve Capabilities & Shell
    final profile = ref.watch(currentUserProfileProvider);
    if (profile != null) {
      widget.appState?.setUserId(profile.userId);
    }

    final capabilitiesAsync = ref.watch(accountCapabilitiesProvider);

    return capabilitiesAsync.when(
      loading: () {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Scaffold(
          backgroundColor:
              isDark ? FlowPayColors.darkBackground : FlowPayColors.paper,
          body: const Center(
            child: CircularProgressIndicator(
              color: FlowPayColors.primary,
            ),
          ),
        );
      },
      error: (err, stack) => _renderActiveShell(),
      data: (capabilities) {
        _checkInitialModePicker(capabilities);
        return _renderActiveShell();
      },
    );
  }


  Widget _renderActiveShell() {
    final activeMode = ref.watch(currentAccountModeProvider);
    return switch (activeMode) {
      AccountMode.personal => widget.personalShell,
      AccountMode.business => widget.businessShell,
    };
  }

  Widget _buildLockScreen(BuildContext context, AppLockState lockState) {
    final isExpired = lockState.isAuthExpired;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? FlowPayColors.darkBackground : FlowPayColors.paper;
    final textPrimary =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final textSecondary =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.textSecondary;
    final surfaceColor = FlowPayColors.surfaceOf(context);
    final borderColor = FlowPayColors.borderOf(context);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // ── Brand Mark ──
              const FlowPayLogo.horizontal(size: 28),
              const SizedBox(height: 24),

              // ── Status Icon Container ──
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isExpired
                      ? FlowPayColors.amber.withValues(alpha: 0.12)
                      : isDark
                          ? FlowPayColors.darkSurfaceElevated
                          : FlowPayColors.mint100,
                  borderRadius: FlowPayRadii.card,
                  border: Border.all(
                    color: isExpired
                        ? FlowPayColors.amber.withValues(alpha: 0.4)
                        : FlowPayColors.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isExpired ? FlowPayColors.amber : FlowPayColors.primary)
                          .withValues(alpha: 0.12),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  isExpired
                      ? Icons.timer_outlined
                      : (lockState.hasFaceId
                          ? Icons.face_unlock_outlined
                          : (lockState.hasFingerprint
                              ? Icons.fingerprint
                              : Icons.shield_outlined)),
                  size: 36,
                  color: isExpired
                      ? FlowPayColors.amber
                      : FlowPayColors.primary,
                ),
              ),
              const SizedBox(height: 18),

              // ── Title & Subtitle ──
              Text(
                isExpired ? 'Session Expired' : 'FlowPay is Locked',
                style: FlowPayTypography.headline().copyWith(color: textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isExpired
                    ? 'Your session has expired. Enter your 6-digit PIN, use ${lockState.biometricLabel}, or log in to renew.'
                    : 'Enter your 6-digit PIN or authenticate via ${lockState.biometricLabel} to access FlowPay.',
                style: TextStyle(
                  fontSize: 13,
                  color: textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),

              // ── Status Pill Badge ──
              if (isExpired)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: FlowPayColors.amber.withValues(alpha: 0.12),
                    borderRadius: FlowPayRadii.chip,
                    border: Border.all(
                        color: FlowPayColors.amber.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 14, color: FlowPayColors.amber),
                      SizedBox(width: 6),
                      Text(
                        'Authentication Expired',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: FlowPayColors.amber,
                        ),
                      ),
                    ],
                  ),
                )
              else if (lockState.hasFaceId || lockState.hasFingerprint)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: FlowPayColors.primary.withValues(alpha: 0.08),
                    borderRadius: FlowPayRadii.chip,
                    border: Border.all(
                        color: FlowPayColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        lockState.hasFaceId ? Icons.face : Icons.fingerprint,
                        size: 14,
                        color: FlowPayColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${lockState.biometricLabel} Ready',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: FlowPayColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 28),

              // ── PIN Entry ──
              _buildPinEntry(isDark, surfaceColor, borderColor),
              const SizedBox(height: 16),

              // ── Auth Error / Status message ──
              if (lockState.lastResult?.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FlowPayColors.error.withValues(alpha: 0.08),
                    borderRadius: FlowPayRadii.input,
                    border: Border.all(
                        color: FlowPayColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: FlowPayColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lockState.lastResult!.errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: FlowPayColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Primary: Biometric Unlock Button ──
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

              const SizedBox(height: 10),

              // ── Secondary: Log In to Existing Account ──
              FlowPayButton(
                text: 'Log In to Existing Account',
                icon: Icons.login_rounded,
                variant: FlowPayButtonVariant.secondary,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
              ),

              const SizedBox(height: 10),

              // ── Secondary: Create New Account ──
              FlowPayButton(
                text: 'Create New Account',
                icon: Icons.person_add_outlined,
                variant: FlowPayButtonVariant.secondary,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SignupScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // ── Log Out / Switch Account ──
              TextButton.icon(
                icon: Icon(Icons.logout, size: 15, color: textSecondary),
                label: Text(
                  'Log Out / Switch Account',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
                onPressed: () {
                  ref.read(appLockStateProvider.notifier).logout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinEntry(
    bool isDark,
    Color surfaceColor,
    Color borderColor,
  ) {
    final textPrimary =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final textSecondary =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.textSecondary;

    return Column(
      children: [
        Text(
          'Enter 6-Digit PIN',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 220,
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: FlowPayRadii.input,
            border: Border.all(
              color: _pinError
                  ? FlowPayColors.error
                  : borderColor,
              width: _pinError ? 1.5 : 1,
            ),
          ),
          child: TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              letterSpacing: 12,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
            decoration: InputDecoration(
              counterText: '',
              border: InputBorder.none,
              hintText: '••••••',
              hintStyle: TextStyle(
                color: textSecondary,
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
                } else {
                  _pinController.clear();
                  if (_pinError) setState(() => _pinError = false);
                }
              } else {
                if (_pinError) setState(() => _pinError = false);
              }
            },
          ),
        ),
        if (_pinError)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Incorrect 6-digit PIN. Try again.',
              style: TextStyle(
                fontSize: 11,
                color: FlowPayColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
