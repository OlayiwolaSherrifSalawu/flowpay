import 'package:flutter/material.dart';
import '../network/api_client.dart';
import '../providers/bmoni/bmoni_card_repo.dart';
import '../providers/bmoni/bmoni_employee_repo.dart';
import '../providers/bmoni/bmoni_payroll_repo.dart';
import '../providers/bmoni/bmoni_transfer_repo.dart';
import '../providers/bmoni/bmoni_wallet_repo.dart';
import '../providers/demo/demo_card_repo.dart';
import '../providers/demo/demo_employee_repo.dart';
import '../providers/demo/demo_payroll_repo.dart';
import '../providers/demo/demo_transfer_repo.dart';
import '../providers/demo/demo_wallet_repo.dart';
import '../repositories/card_repository.dart';
import '../repositories/employee_repository.dart';
import '../repositories/payroll_repository.dart';
import '../repositories/transfer_repository.dart';
import '../repositories/wallet_repository.dart';

enum AppRole { personal, business }
enum ProviderMode { demo, bmoniSandbox }

class AppState extends ChangeNotifier {
  AppRole _activeRole = AppRole.personal;
  ProviderMode _providerMode = ProviderMode.demo;

  final FlowPayApiClient _apiClient = FlowPayApiClient();

  // Demo Repositories
  final DemoWalletRepository _demoWallet = DemoWalletRepository();
  final DemoTransferRepository _demoTransfer = DemoTransferRepository();
  final DemoCardRepository _demoCard = DemoCardRepository();
  final DemoEmployeeRepository _demoEmployee = DemoEmployeeRepository();
  final DemoPayrollRepository _demoPayroll = DemoPayrollRepository();

  // BMONI Live Repositories
  late final BmoniWalletRepository _bmoniWallet = BmoniWalletRepository(apiClient: _apiClient);
  late final BmoniTransferRepository _bmoniTransfer = BmoniTransferRepository(apiClient: _apiClient);
  late final BmoniCardRepository _bmoniCard = BmoniCardRepository(apiClient: _apiClient);
  late final BmoniEmployeeRepository _bmoniEmployee = BmoniEmployeeRepository(apiClient: _apiClient);
  late final BmoniPayrollRepository _bmoniPayroll = BmoniPayrollRepository(apiClient: _apiClient);

  AppRole get activeRole => _activeRole;
  ProviderMode get providerMode => _providerMode;
  bool get isDemo => _providerMode == ProviderMode.demo;

  // Active Repositories conforming to shared interfaces
  WalletRepository get walletRepo => isDemo ? _demoWallet : _bmoniWallet;
  TransferRepository get transferRepo => isDemo ? _demoTransfer : _bmoniTransfer;
  CardRepository get cardRepo => isDemo ? _demoCard : _bmoniCard;
  EmployeeRepository get employeeRepo => isDemo ? _demoEmployee : _bmoniEmployee;
  PayrollRepository get payrollRepo => isDemo ? _demoPayroll : _bmoniPayroll;

  void setRole(AppRole role) {
    if (_activeRole != role) {
      _activeRole = role;
      notifyListeners();
    }
  }

  void setProviderMode(ProviderMode mode) {
    if (_providerMode != mode) {
      _providerMode = mode;
      notifyListeners();
    }
  }
}
