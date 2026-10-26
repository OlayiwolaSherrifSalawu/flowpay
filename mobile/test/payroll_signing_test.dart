import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' hide Currency;
import 'package:flowpay_mobile/core/money/currency.dart';
import 'package:flowpay_mobile/core/money/money.dart';
import 'package:flowpay_mobile/core/repositories/card_repository.dart';
import 'package:flowpay_mobile/core/repositories/employee_repository.dart';
import 'package:flowpay_mobile/core/repositories/payroll_repository.dart';
import 'package:flowpay_mobile/core/repositories/wallet_repository.dart';
import 'package:flowpay_mobile/core/state/business_provider.dart';
import 'package:flowpay_mobile/core/stellar/stellar_key_vault.dart';
import 'package:flowpay_mobile/core/stellar/stellar_network.dart';
import 'helpers/test_wallet.dart';

class MockPayrollRepository implements PayrollRepository {
  PayrollRunModel? previewToReturn;
  Map<String, String>? lastSigned;

  @override
  Future<PayrollRunModel> getPayrollPreview() async => previewToReturn!;

  @override
  Future<PayrollRunModel> executePayrollRun({required String runId, required Map<String, String> signedBatches}) async {
    lastSigned = signedBatches;
    return previewToReturn!.copyWith(status: 'COMPLETED');
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
  Future<List<VirtualCardModel>> getCards({String? smartWalletId, String? userId}) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// An unsigned payment from [source], like the backend's payroll batch.
String unsignedBatch(String source, int seq) => TransactionBuilder(Account(source, BigInt.from(seq)))
    .addOperation(PaymentOperationBuilder(KeyPair.random().accountId, Asset.NATIVE, '1').build())
    .build()
    .toEnvelopeXdrBase64();

PayrollRunModel run({List<PayrollBatchModel> batches = const [], bool sufficient = true, bool isDemo = false}) => PayrollRunModel(
      runId: 'payroll_test',
      title: 'Test payroll',
      totalUsd: Money.fromMinor(100000, Currency.usd),
      totalFeeUsd: Money.zero(Currency.usd),
      totalSavedFeeUsd: Money.zero(Currency.usd),
      employerBalanceUsd: Money.fromMinor(500000, Currency.usd),
      isBalanceSufficient: sufficient,
      employeeCount: 1,
      countries: const ['NG'],
      currencies: const ['NGN'],
      items: [
        PayrollItemModel(
          employeeId: 'emp_1',
          employeeName: 'Ngozi T',
          country: 'NG',
          targetCurrency: Currency.ngn,
          destinationStablecoin: 'NGN',
          targetAmount: Money.fromMinor(155000000, Currency.ngn),
          usdAmount: Money.fromMinor(100300, Currency.usd),
          exchangeRate: 1545.4,
          status: 'PENDING',
        ),
      ],
      status: 'PREVIEW',
      executedAt: DateTime(2026, 10, 26),
      isDemo: isDemo,
      batches: batches,
      networkFeeXlm: '0.0000100',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String employer;

  setUp(() async {
    employer = await provisionTestWallet();
  });

  group('Payroll batch signing', () {
    test('signs every batch transaction with the employer key, verifiably', () async {
      final preview = run(batches: [
        PayrollBatchModel(proposalId: 'p1', signPayload: unsignedBatch(employer, 10), status: 'PENDING_SIGNATURE'),
        PayrollBatchModel(proposalId: 'p2', signPayload: unsignedBatch(employer, 11), status: 'PENDING_SIGNATURE'),
      ]);
      final signed = await BusinessProvider.signPayrollBatches(preview, testWalletPin);
      expect(signed.keys, ['p1', 'p2']);
      for (final xdr in signed.values) {
        final tx = AbstractTransaction.fromEnvelopeXdrString(xdr) as Transaction;
        final hash = tx.hash(Network(StellarNetwork.current.passphrase));
        expect(KeyPair.fromAccountId(employer).verify(hash, tx.signatures.single.signature.signature), isTrue);
      }
    });

    test('refuses when the balance is short, nobody is payable, or the PIN is wrong', () async {
      await expectLater(BusinessProvider.signPayrollBatches(run(sufficient: false), testWalletPin), throwsA(isA<StateError>()));
      await expectLater(BusinessProvider.signPayrollBatches(run(), testWalletPin), throwsA(isA<StateError>()));
      final preview = run(batches: [PayrollBatchModel(proposalId: 'p1', signPayload: unsignedBatch(employer, 10), status: 'PENDING_SIGNATURE')]);
      await expectLater(
        BusinessProvider.signPayrollBatches(preview, '000000'),
        throwsA(isA<StellarVaultException>().having((e) => e.code, 'code', StellarVaultErrorCode.pinMismatch)),
      );
    });

    test('demo runs only verify the PIN; nothing is sent as a transaction', () async {
      expect(await BusinessProvider.signPayrollBatches(run(isDemo: true), testWalletPin), isEmpty);
    });

    test('runPayroll() submits exactly the signed batches from the preview', () async {
      final repo = MockPayrollRepository()
        ..previewToReturn = run(batches: [PayrollBatchModel(proposalId: 'p1', signPayload: unsignedBatch(employer, 10), status: 'PENDING_SIGNATURE')]);
      final provider = BusinessProvider(
        employeeRepo: FakeEmployeeRepository(),
        payrollRepo: repo,
        walletRepo: FakeWalletRepository(),
        cardRepo: FakeCardRepository(),
      );
      await provider.loadDashboard();
      final result = await provider.runPayroll(pin: testWalletPin);
      expect(result.status, 'COMPLETED');
      expect(repo.lastSigned!.keys, ['p1']);
    });
  });
}
