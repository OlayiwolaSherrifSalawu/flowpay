import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/core/bmoni_sdk/bmoni_sdk_service.dart';
import 'package:flowpay_mobile/core/money/currency.dart';
import 'package:flowpay_mobile/core/money/money.dart';
import 'package:flowpay_mobile/core/repositories/payroll_repository.dart';
import 'package:flowpay_mobile/core/repositories/employee_repository.dart';
import 'package:flowpay_mobile/core/repositories/wallet_repository.dart';
import 'package:flowpay_mobile/core/repositories/card_repository.dart';
import 'package:flowpay_mobile/core/state/business_provider.dart';

class MockPayrollRepository implements PayrollRepository {
  PayrollRunModel? previewToReturn;
  String? lastSignature;

  @override
  Future<PayrollRunModel> getPayrollPreview() async {
    return previewToReturn!;
  }

  @override
  Future<PayrollRunModel> executePayrollRun({
    required String runId,
    required String signature,
  }) async {
    lastSignature = signature;
    return PayrollRunModel(
      runId: runId,
      title: 'Executed Run',
      totalUsd: Money.fromMinor(400000, Currency.usd),
      totalFeeUsd: Money.fromMinor(1000, Currency.usd),
      totalSavedFeeUsd: Money.fromMinor(33000, Currency.usd),
      employerBalanceUsd: Money.fromMinor(2450000, Currency.usd),
      employeeCount: 2,
      countries: const ['NG', 'MX'],
      currencies: const ['NGN', 'MXN'],
      status: 'COMPLETED',
      executedAt: DateTime.now(),
      isDemo: false,
      items: [],
    );
  }

  @override
  Future<PayrollItemModel> retryFailedProposal({
    required String proposalId,
    required String employeeId,
    required String pin,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<PayrollRunModel>> getPastRuns() async => [];
}

class FakeEmployeeRepository implements EmployeeRepository {
  @override
  Future<List<EmployeeModel>> getEmployees() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeWalletRepository implements WalletRepository {
  @override
  Future<List<WalletAccount>> getWallets() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCardRepository implements CardRepository {
  @override
  Future<List<VirtualCardModel>> getCards() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await BmoniSdkService.initialize();
    await BmoniSdkService.setPin('123456');
  });

  group('Payroll Proposal Hashing & On-Device Signing Verification', () {
    const runId = 'run_september_2026_test';

    final item1 = PayrollItemModel(
      employeeId: 'emp_bunch_dillon',
      employeeName: 'Bunch Dillon',
      country: 'NG',
      targetCurrency: Currency.ngn,
      destinationStablecoin: 'CNGN',
      targetAmount: Money.fromMinor(310000000, Currency.ngn),
      usdAmount: Money.fromMinor(200000, Currency.usd),
      exchangeRate: 1550.0,
      status: 'PENDING',
    );

    final item2 = PayrollItemModel(
      employeeId: 'emp_samson_jabo',
      employeeName: 'Samson Jabo',
      country: 'MX',
      targetCurrency: Currency.mxn,
      destinationStablecoin: 'MEXe',
      targetAmount: Money.fromMinor(3500000, Currency.mxn),
      usdAmount: Money.fromMinor(200000, Currency.usd),
      exchangeRate: 17.5,
      status: 'PENDING',
    );

    test('Computes distinct 32-byte hashes for different employees and amounts', () {
      final hash1 = BusinessProvider.computeProposalHash(runId: runId, item: item1);
      final hash2 = BusinessProvider.computeProposalHash(runId: runId, item: item2);

      // 1. Both hashes must be valid 32-byte hex strings ('0x' + 64 hex chars = 66 chars)
      expect(hash1.startsWith('0x'), isTrue);
      expect(hash1.length, equals(66));
      expect(hash2.startsWith('0x'), isTrue);
      expect(hash2.length, equals(66));

      // 2. Hashes must be strictly non-identical
      expect(hash1, isNot(equals(hash2)));
    });

    test('Proposal hash changes when underlying proposal data changes', () {
      final initialHash = BusinessProvider.computeProposalHash(runId: runId, item: item1);

      // Modify amount
      final itemWithNewAmount = PayrollItemModel(
        employeeId: item1.employeeId,
        employeeName: item1.employeeName,
        country: item1.country,
        targetCurrency: item1.targetCurrency,
        destinationStablecoin: item1.destinationStablecoin,
        targetAmount: Money.fromMinor(400000000, Currency.ngn), // changed from 310000000
        usdAmount: Money.fromMinor(258000, Currency.usd),
        exchangeRate: item1.exchangeRate,
        status: item1.status,
      );
      final newAmountHash = BusinessProvider.computeProposalHash(runId: runId, item: itemWithNewAmount);
      expect(newAmountHash, isNot(equals(initialHash)),
          reason: 'Changing amount must produce a completely different hash');

      // Modify runId / nonce
      final newRunHash = BusinessProvider.computeProposalHash(runId: 'run_october_2026_diff', item: item1);
      expect(newRunHash, isNot(equals(initialHash)),
          reason: 'Changing runId/nonce must produce a completely different hash');

      // Modify currency / stablecoin
      final itemWithNewStablecoin = PayrollItemModel(
        employeeId: item1.employeeId,
        employeeName: item1.employeeName,
        country: item1.country,
        targetCurrency: item1.targetCurrency,
        destinationStablecoin: 'USDB',
        targetAmount: item1.targetAmount,
        usdAmount: item1.usdAmount,
        exchangeRate: item1.exchangeRate,
        status: item1.status,
      );
      final newStablecoinHash = BusinessProvider.computeProposalHash(runId: runId, item: itemWithNewStablecoin);
      expect(newStablecoinHash, isNot(equals(initialHash)),
          reason: 'Changing currency/stablecoin must produce a completely different hash');
    });

    test('Generates distinct cryptographic signatures for each proposal', () async {
      final hash1 = BusinessProvider.computeProposalHash(runId: runId, item: item1);
      final hash2 = BusinessProvider.computeProposalHash(runId: runId, item: item2);

      final sig1 = await BmoniSdkService.signTransactionHash(hash1, pin: '123456');
      final sig2 = await BmoniSdkService.signTransactionHash(hash2, pin: '123456');

      expect(sig1, isNot(equals(sig2)),
          reason: 'Signatures for distinct proposals must never be identical');
    });

    test('runPayroll() executes successfully for distinct proposals in batch', () async {
      final mockRepo = MockPayrollRepository();

      final validRun = PayrollRunModel(
        runId: runId,
        title: 'Valid Multi-Country Payroll',
        totalUsd: Money.fromMinor(400000, Currency.usd),
        totalFeeUsd: Money.fromMinor(1000, Currency.usd),
        totalSavedFeeUsd: Money.fromMinor(33000, Currency.usd),
        employerBalanceUsd: Money.fromMinor(2450000, Currency.usd),
        employeeCount: 2,
        countries: const ['NG', 'MX'],
        currencies: const ['NGN', 'MXN'],
        status: 'PREVIEW',
        executedAt: DateTime.now(),
        isDemo: false,
        items: [item1, item2],
      );

      mockRepo.previewToReturn = validRun;

      final provider = BusinessProvider(
        employeeRepo: FakeEmployeeRepository(),
        payrollRepo: mockRepo,
        walletRepo: FakeWalletRepository(),
        cardRepo: FakeCardRepository(),
      );

      await provider.loadDashboard();
      expect(provider.pendingPayroll, isNotNull);

      final result = await provider.runPayroll(pin: '123456');
      expect(result.status, equals('COMPLETED'));
      expect(mockRepo.lastSignature, isNotNull);
      expect(mockRepo.lastSignature!.startsWith('0x'), isTrue);
    });

    test('runPayroll() fails loudly with StateError on duplicate proposal hash collision', () async {
      final mockRepo = MockPayrollRepository();

      final duplicateRun = PayrollRunModel(
        runId: runId,
        title: 'Duplicate Run',
        totalUsd: Money.fromMinor(400000, Currency.usd),
        totalFeeUsd: Money.fromMinor(1000, Currency.usd),
        totalSavedFeeUsd: Money.fromMinor(33000, Currency.usd),
        employerBalanceUsd: Money.fromMinor(2450000, Currency.usd),
        employeeCount: 2,
        countries: const ['NG'],
        currencies: const ['NGN'],
        status: 'PREVIEW',
        executedAt: DateTime.now(),
        isDemo: false,
        items: [item1, item1], // identical items -> identical hash in same run
      );

      mockRepo.previewToReturn = duplicateRun;

      final provider = BusinessProvider(
        employeeRepo: FakeEmployeeRepository(),
        payrollRepo: mockRepo,
        walletRepo: FakeWalletRepository(),
        cardRepo: FakeCardRepository(),
      );

      await provider.loadDashboard();

      expect(
        () async => await provider.runPayroll(pin: '123456'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Duplicate proposal hash detected in batch'),
        )),
      );
    });
  });
}
