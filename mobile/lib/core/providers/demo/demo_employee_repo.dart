import '../../money/currency.dart';
import '../../money/money.dart';
import '../../repositories/employee_repository.dart';
import 'demo_data.dart';

class DemoEmployeeRepository implements EmployeeRepository {
  final List<EmployeeModel> _employees = List.from(DemoData.employees);

  @override
  Future<List<EmployeeModel>> getEmployees() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return List.unmodifiable(_employees);
  }

  @override
  Future<EmployeeModel> getEmployeeById(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _employees.firstWhere(
      (e) => e.id == id,
      orElse: () => _employees.first,
    );
  }

  @override
  Future<String> createEmployee({
    required String firstName,
    required String lastName,
    required String email,
    String? phoneNumber,
    required String country,
    String? countryName,
    required Currency targetCurrency,
    required Money payrollAmount,
    Money? usdPayrollAmount,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final newId = 'emp_demo_${DateTime.now().millisecondsSinceEpoch}';
    final randomHex = (1000 + _employees.length).toString();
    final bmoniId = 'usr_bmoni_${newId.substring(4)}';

    final emp = EmployeeModel(
      id: newId,
      bmoniUserId: bmoniId,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phoneNumber: phoneNumber,
      country: country,
      countryName: countryName ??
          (country == 'NG'
              ? 'Nigeria'
              : country == 'MX'
                  ? 'Mexico'
                  : 'Canada'),
      targetCurrency: targetCurrency,
      status:
          EmployeeLifecycleStages.ready, // Sandbox personas ready immediately
      onboardingStatus: EmployeeLifecycleStages.ready,
      walletStatus: 'ACTIVE',
      cardStatus: 'ACTIVE',
      payrollAmount: payrollAmount,
      usdPayrollAmount:
          usdPayrollAmount ?? Money.fromMajorString('2000.00', Currency.usd),
      walletAddress: '0x$randomHex...${DateTime.now().millisecond}A',
      cardId: 'card_demo_${newId.substring(0, 8)}',
      cardLast4: (4000 + _employees.length * 111).toString(),
    );
    _employees.add(emp);
    return 'https://bmoni.com/invite/flowpay_$newId';
  }

  @override
  Future<String> inviteEmployee({
    required String firstName,
    required String lastName,
    required String email,
    required String country,
    String? countryName,
    required Currency targetCurrency,
    Money? payrollAmount,
    Money? usdPayrollAmount,
  }) {
    return createEmployee(
      firstName: firstName,
      lastName: lastName,
      email: email,
      country: country,
      countryName: countryName,
      targetCurrency: targetCurrency,
      payrollAmount:
          payrollAmount ?? Money.fromMajorString('2000.00', targetCurrency),
      usdPayrollAmount: usdPayrollAmount,
    );
  }

  // --- Multi-Stage Onboarding Implementations ---

  @override
  Future<Map<String, dynamic>> requestOwnerChallenge(
      String employeeId, String userOwnerAddress) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final emp = await getEmployeeById(employeeId);
    final currency = emp.country.toUpperCase() == 'NG' ? 'CNGN' : 'MEXe';
    return {
      'challengeId': 'ch_demo_${DateTime.now().millisecondsSinceEpoch}',
      'message':
          'FlowPay Onboarding Verification: I prove ownership of $userOwnerAddress for $currency smart wallet at ${DateTime.now().toIso8601String()}',
      'currency': currency,
      'expiresAt':
          DateTime.now().add(const Duration(minutes: 10)).toIso8601String(),
    };
  }

  @override
  Future<Map<String, dynamic>> provisionSmartWallet(
    String employeeId, {
    required String userOwnerAddress,
    required String ownerProofChallengeId,
    required String ownerProofSignature,
  }) async {
    await Future.delayed(const Duration(milliseconds: 350));
    final index = _employees.indexWhere((e) => e.id == employeeId);
    final emp = index >= 0 ? _employees[index] : _employees.first;
    final currency = emp.country.toUpperCase() == 'NG' ? 'CNGN' : 'MEXe';
    final walletId = 'wlt_demo_${DateTime.now().millisecondsSinceEpoch}';

    final updated = EmployeeModel(
      id: emp.id,
      bmoniUserId: emp.bmoniUserId,
      firstName: emp.firstName,
      lastName: emp.lastName,
      email: emp.email,
      phoneNumber: emp.phoneNumber,
      country: emp.country,
      countryName: emp.countryName,
      targetCurrency: emp.targetCurrency,
      status: 'KYC_PENDING',
      failedStage: null,
      onboardingStatus: 'KYC_PENDING',
      walletStatus: 'ACTIVE',
      cardStatus: emp.cardStatus,
      payrollAmount: emp.payrollAmount,
      usdPayrollAmount: emp.usdPayrollAmount,
      walletAddress: userOwnerAddress,
      cardId: emp.cardId,
      cardLast4: emp.cardLast4,
    );

    if (index >= 0) {
      _employees[index] = updated;
    }

    return {
      'smartWalletId': walletId,
      'walletAddress': userOwnerAddress,
      'currency': currency,
      'status': 'ACTIVE',
    };
  }

  @override
  Future<Map<String, dynamic>> getKycOptions(String employeeId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return {
      'countries': ['NGA', 'MEX'],
      'employmentStatuses': ['employed', 'self_employed', 'contractor'],
      'sourceOfFunds': ['salary', 'business', 'savings'],
    };
  }

  @override
  Future<Map<String, dynamic>> submitCountryKyc(
      String employeeId, Map<String, dynamic> kycPayload) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {
      'success': true,
      'readyForActivation': true,
    };
  }

  @override
  Future<Map<String, dynamic>> checkKycReadiness(String employeeId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return {'ready': true};
  }

  @override
  Future<Map<String, dynamic>> activateKyc(String employeeId) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final index = _employees.indexWhere((e) => e.id == employeeId);
    if (index >= 0) {
      final emp = _employees[index];
      _employees[index] = EmployeeModel(
        id: emp.id,
        bmoniUserId: emp.bmoniUserId,
        firstName: emp.firstName,
        lastName: emp.lastName,
        email: emp.email,
        phoneNumber: emp.phoneNumber,
        country: emp.country,
        countryName: emp.countryName,
        targetCurrency: emp.targetCurrency,
        status: 'ONBOARDING',
        failedStage: null,
        onboardingStatus: 'ONBOARDING',
        walletStatus: emp.walletStatus,
        cardStatus: emp.cardStatus,
        payrollAmount: emp.payrollAmount,
        usdPayrollAmount: emp.usdPayrollAmount,
        walletAddress: emp.walletAddress,
        cardId: emp.cardId,
        cardLast4: emp.cardLast4,
      );
    }
    return {'success': true, 'status': 'ACTIVATED'};
  }

  @override
  Future<Map<String, dynamic>> getMexicoAgreements(String employeeId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return {
      'url': 'https://etherfuse.bmoni.com/auth/launch',
      'method': 'POST',
      'fields': {
        'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'target': '/agreements',
      },
      'html': '<form><button>Sign Etherfuse Terms</button></form>',
      'expiresAt':
          DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
    };
  }

  @override
  Future<Map<String, dynamic>> activateRail(String employeeId,
      {Map<String, dynamic>? options}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _employees.indexWhere((e) => e.id == employeeId);
    if (index >= 0) {
      final emp = _employees[index];
      _employees[index] = EmployeeModel(
        id: emp.id,
        bmoniUserId: emp.bmoniUserId,
        firstName: emp.firstName,
        lastName: emp.lastName,
        email: emp.email,
        phoneNumber: emp.phoneNumber,
        country: emp.country,
        countryName: emp.countryName,
        targetCurrency: emp.targetCurrency,
        status: 'ONBOARDING',
        failedStage: null,
        onboardingStatus: 'ONBOARDING',
        walletStatus: emp.walletStatus,
        cardStatus: emp.cardStatus,
        payrollAmount: emp.payrollAmount,
        usdPayrollAmount: emp.usdPayrollAmount,
        walletAddress: emp.walletAddress,
        cardId: emp.cardId,
        cardLast4: emp.cardLast4,
      );
    }
    return {
      'success': true,
      'status': 'PROCESSING',
      'message': 'Rail activation submitted. Processing onboarding.',
    };
  }

  @override
  Future<EmployeeOnboardingStatusModel> getOnboardingStatus(
      String employeeId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final emp = await getEmployeeById(employeeId);
    final isNG = emp.country.toUpperCase() == 'NG';
    final stablecoin = isNG ? 'CNGN' : 'MEXe';

    OnboardingStageState overall = OnboardingStageState.notStarted;
    int currentStage = 2;
    OnboardingStageState stage2State = OnboardingStageState.notStarted;
    OnboardingStageState stage3State = OnboardingStageState.notStarted;
    OnboardingStageState stage4State = OnboardingStageState.notStarted;

    if (emp.walletAddress != null && emp.walletAddress!.isNotEmpty) {
      stage2State = OnboardingStageState.ready;
    } else if (emp.status == 'WALLET_PENDING') {
      stage2State = OnboardingStageState.inProgress;
    }

    if (stage2State == OnboardingStageState.ready) {
      if (emp.status == 'READY') {
        stage3State = OnboardingStageState.ready;
        stage4State = OnboardingStageState.ready;
        overall = OnboardingStageState.ready;
        currentStage = 4;
      } else if (emp.status == 'ONBOARDING') {
        stage3State = OnboardingStageState.ready;
        stage4State = OnboardingStageState.inProgress;
        overall = OnboardingStageState.inProgress;
        currentStage = 4;
      } else if (emp.status == 'KYC_PENDING') {
        stage3State = OnboardingStageState.inProgress;
        overall = OnboardingStageState.inProgress;
        currentStage = 3;
      }
    } else {
      currentStage = 2;
      overall = stage2State == OnboardingStageState.inProgress
          ? OnboardingStageState.inProgress
          : OnboardingStageState.notStarted;
    }

    if (emp.status == 'FAILED') {
      overall = OnboardingStageState.failed;
    }

    return EmployeeOnboardingStatusModel(
      employeeId: emp.id,
      bmoniUserId: emp.bmoniUserId ?? emp.id,
      country: emp.country,
      targetCurrency: emp.targetCurrency.code,
      stablecoinToken: stablecoin,
      overallState: overall,
      currentStage: currentStage,
      failedStage:
          emp.failedStage != null ? int.tryParse(emp.failedStage!) : null,
      failureReason: emp.failedStage != null
          ? 'Onboarding issue encountered during processing'
          : null,
      stage2Wallet: StageDetailModel(
        stageNumber: 2,
        title: 'Smart Wallet Provisioning ($stablecoin)',
        state: stage2State,
        details: {'walletAddress': emp.walletAddress, 'stablecoin': stablecoin},
      ),
      stage3Kyc: StageDetailModel(
        stageNumber: 3,
        title:
            'Identity & KYC Compliance (${isNG ? 'Nigeria — No Selfie' : 'Mexico — Selfie + CURP/RFC'})',
        state: stage3State,
        details: {'biometricRequired': !isNG},
      ),
      stage4Rail: StageDetailModel(
        stageNumber: 4,
        title:
            'Rail Activation (${isNG ? 'NGN Virtual Account' : 'Etherfuse CLABE'})',
        state: stage4State,
        details: {'agreementsRequired': !isNG},
      ),
    );
  }

  @override
  Future<EmployeeOnboardingStatusModel> retryOnboarding(
      String employeeId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _employees.indexWhere((e) => e.id == employeeId);
    if (index >= 0) {
      final emp = _employees[index];
      _employees[index] = EmployeeModel(
        id: emp.id,
        bmoniUserId: emp.bmoniUserId,
        firstName: emp.firstName,
        lastName: emp.lastName,
        email: emp.email,
        phoneNumber: emp.phoneNumber,
        country: emp.country,
        countryName: emp.countryName,
        targetCurrency: emp.targetCurrency,
        status: emp.walletAddress != null ? 'KYC_PENDING' : 'WALLET_PENDING',
        failedStage: null,
        onboardingStatus:
            emp.walletAddress != null ? 'KYC_PENDING' : 'WALLET_PENDING',
        walletStatus: emp.walletStatus,
        cardStatus: emp.cardStatus,
        payrollAmount: emp.payrollAmount,
        usdPayrollAmount: emp.usdPayrollAmount,
        walletAddress: emp.walletAddress,
        cardId: emp.cardId,
        cardLast4: emp.cardLast4,
      );
    }
    return getOnboardingStatus(employeeId);
  }

  @override
  Future<EmployeeOnboardingStatusModel> retryStage(
          String employeeId, int stage) =>
      retryOnboarding(employeeId);

  @override
  Future<EmployeeOnboardingStatusModel> simulateWebhookCompleted(
      String employeeId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _employees.indexWhere((e) => e.id == employeeId);
    if (index >= 0) {
      final emp = _employees[index];
      _employees[index] = EmployeeModel(
        id: emp.id,
        bmoniUserId: emp.bmoniUserId,
        firstName: emp.firstName,
        lastName: emp.lastName,
        email: emp.email,
        phoneNumber: emp.phoneNumber,
        country: emp.country,
        countryName: emp.countryName,
        targetCurrency: emp.targetCurrency,
        status: EmployeeLifecycleStages.ready,
        failedStage: null,
        onboardingStatus: EmployeeLifecycleStages.ready,
        walletStatus: 'ACTIVE',
        cardStatus: 'ACTIVE',
        payrollAmount: emp.payrollAmount,
        usdPayrollAmount: emp.usdPayrollAmount,
        walletAddress: emp.walletAddress ??
            '0x7e8125a09c2cdc7bedc12253e49e4946c6fff0273034eb485750035d21ad31',
        cardId: emp.cardId ?? 'card_demo_${emp.id}',
        cardLast4: emp.cardLast4 ?? '4289',
      );
    }
    return getOnboardingStatus(employeeId);
  }
}
