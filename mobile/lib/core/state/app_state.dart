import 'package:flutter/material.dart';
import '../network/api_client.dart';
import '../providers/live/live_activity_repo.dart';
import '../providers/live/live_approval_repo.dart';
import '../providers/live/live_business_audit_repo.dart';
import '../providers/stellar/stellar_employee_repo.dart';
import '../providers/stellar/stellar_mission_repo.dart';
import '../providers/stellar/stellar_payroll_repo.dart';
import '../providers/stellar/stellar_transfer_repo.dart';
import '../providers/stellar/stellar_wallet_repo.dart';
import '../providers/demo/demo_activity_repo.dart';
import '../providers/demo/demo_approval_repo.dart';
import '../providers/demo/demo_business_audit_repo.dart';
import '../providers/demo/demo_employee_repo.dart';
import '../providers/demo/demo_mission_repo.dart';
import '../providers/demo/demo_payroll_repo.dart';
import '../providers/demo/demo_transfer_repo.dart';
import '../providers/demo/demo_wallet_repo.dart';
import '../beneficiaries/beneficiary_repository.dart';
import '../repositories/activity_repository.dart';
import '../repositories/approval_repository.dart';
import '../repositories/business_audit_repository.dart';
import '../repositories/employee_repository.dart';
import '../repositories/mission_repository.dart';
import '../repositories/payroll_repository.dart';
import '../repositories/transfer_repository.dart';
import '../repositories/wallet_repository.dart';
import 'business_provider.dart';
import 'personal_provider.dart';

enum AppRole { personal, business }

enum ProviderMode { demo, live }

class AppState extends ChangeNotifier {
  AppRole _activeRole = AppRole.personal;
  ProviderMode _providerMode;
  ThemeMode _themeMode = ThemeMode.dark;
  int _personalTabIndex = 0;

  final FlowPayApiClient _apiClient = FlowPayApiClient();

  // Demo Repositories (for isolated widget testing)
  final DemoWalletRepository _demoWallet = DemoWalletRepository();
  final DemoActivityRepository _demoActivity = DemoActivityRepository();
  late final DemoTransferRepository _demoTransfer = DemoTransferRepository(
    activityRepo: _demoActivity,
    walletRepo: _demoWallet,
  );
  final DemoEmployeeRepository _demoEmployee = DemoEmployeeRepository();
  final DemoPayrollRepository _demoPayroll = DemoPayrollRepository();
  late final DemoMissionRepository _demoMission = DemoMissionRepository(
    activityRepo: _demoActivity,
    walletRepo: _demoWallet,
  );
  final DemoApprovalRepository _demoApproval = DemoApprovalRepository();
  final DemoBeneficiaryRepository _demoBeneficiary = DemoBeneficiaryRepository();
  late final DemoBusinessAuditRepository _demoAudit =
      DemoBusinessAuditRepository(
    payrollRepo: _demoPayroll,
    walletRepo: _demoWallet,
    activityRepo: _demoActivity,
  );

  // Stellar Live Repositories (connected to FlowPay backend & Supabase DB)
  // Stellar: wallets & transfers settle on the Stellar network.
  late final StellarWalletRepository _liveWallet =
      StellarWalletRepository(apiClient: _apiClient);
  late final StellarTransferRepository _liveTransfer =
      StellarTransferRepository(apiClient: _apiClient);
  late final StellarEmployeeRepository _liveEmployee =
      StellarEmployeeRepository(apiClient: _apiClient);
  late final StellarPayrollRepository _livePayroll =
      StellarPayrollRepository(apiClient: _apiClient);
  late final LiveActivityRepository _liveActivity =
      LiveActivityRepository(apiClient: _apiClient);
  late final StellarMissionRepository _liveMission = StellarMissionRepository(apiClient: _apiClient);
  late final LiveApprovalRepository _liveApproval =
      LiveApprovalRepository(apiClient: _apiClient);
  late final LiveBusinessAuditRepository _liveAudit =
      LiveBusinessAuditRepository(
    payrollRepo: _livePayroll,
    walletRepo: _liveWallet,
    activityRepo: _liveActivity,
  );

  // Business Providers
  late final BusinessProvider _demoBusinessProvider = BusinessProvider(
    employeeRepo: _demoEmployee,
    payrollRepo: _demoPayroll,
    walletRepo: _demoWallet,
    auditRepo: _demoAudit,
  );

  late final BusinessProvider _liveBusinessProvider = BusinessProvider(
    employeeRepo: _liveEmployee,
    payrollRepo: _livePayroll,
    walletRepo: _liveWallet,
    auditRepo: _liveAudit,
  );

  // Personal Providers
  late final PersonalProvider _demoPersonalProvider = PersonalProvider(
    walletRepo: _demoWallet,
    activityRepo: _demoActivity,
    missionRepo: _demoMission,
    approvalRepo: _demoApproval,
    transferRepo: _demoTransfer,
  );

  late final PersonalProvider _livePersonalProvider = PersonalProvider(
    walletRepo: _liveWallet,
    activityRepo: _liveActivity,
    missionRepo: _liveMission,
    approvalRepo: _liveApproval,
    transferRepo: _liveTransfer,
  );

  AppState({ProviderMode providerMode = ProviderMode.demo})
      : _providerMode = providerMode;

  AppRole get activeRole => _activeRole;
  ProviderMode get providerMode => _providerMode;
  ThemeMode get themeMode => _themeMode;
  bool get isDemo => _providerMode == ProviderMode.demo;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  int get personalTabIndex => _personalTabIndex;

  FlowPayApiClient get apiClient => _apiClient;

  void setUserId(String? userId) {
    final target = userId ?? 'usr_flowpay_sandbox_master';
    if (_apiClient.userId != target) {
      _apiClient.setUserId(target);
      _liveActivity.clearLocalActivities();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  // Active Repositories
  WalletRepository get walletRepo => isDemo ? _demoWallet : _liveWallet;
  TransferRepository get transferRepo =>
      isDemo ? _demoTransfer : _liveTransfer;
  EmployeeRepository get employeeRepo =>
      isDemo ? _demoEmployee : _liveEmployee;
  PayrollRepository get payrollRepo => isDemo ? _demoPayroll : _livePayroll;
  ActivityRepository get activityRepo =>
      isDemo ? _demoActivity : _liveActivity;
  MissionRepository get missionRepo => isDemo ? _demoMission : _liveMission;
  ApprovalRepository get approvalRepo =>
      isDemo ? _demoApproval : _liveApproval;
  BusinessAuditRepository get auditRepo => isDemo ? _demoAudit : _liveAudit;
  BeneficiaryRepository get beneficiaryRepo => _demoBeneficiary;

  // Active Providers
  BusinessProvider get businessProvider =>
      isDemo ? _demoBusinessProvider : _liveBusinessProvider;
  PersonalProvider get personalProvider =>
      isDemo ? _demoPersonalProvider : _livePersonalProvider;

  void setRole(AppRole role) {
    if (_activeRole != role) {
      _activeRole = role;
      notifyListeners();
    }
  }

  void setPersonalTabIndex(int index) {
    if (_personalTabIndex != index) {
      _personalTabIndex = index;
      notifyListeners();
    }
  }

  void toggleRole() {
    setRole(
        _activeRole == AppRole.personal ? AppRole.business : AppRole.personal);
  }

  void setProviderMode(ProviderMode mode) {
    if (_providerMode != mode) {
      _providerMode = mode;
      notifyListeners();
    }
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
  }

  void toggleTheme() {
    setThemeMode(
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  void notifyStateChanged() {
    notifyListeners();
  }
}
