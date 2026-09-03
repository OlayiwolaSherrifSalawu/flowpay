import '../../money/currency.dart';
import '../../money/money.dart';
import '../../repositories/card_repository.dart';
import '../../repositories/employee_repository.dart';
import '../../repositories/payroll_repository.dart';
import '../../repositories/wallet_repository.dart';

/**
 * Deterministic Demo Data
 * Incorporates official BMONI Sandbox personas & multi-country rails:
 * 1. Bunch Dillon (Nigeria, BVN 99999999999, NGN / CNGN)
 * 2. Samson Jabo (Mexico, BVN/NIN 22222222222, MXN / MEXe)
 * 3. Liam Tremblay (Canada, CAD / CADC)
 */
class DemoData {
  static final List<WalletAccount> wallets = [
    WalletAccount(
      id: 'sw_demo_usdb_01',
      address: '0x8f2d6B48e89405d414a3D65B2Af6d73f1d93E3C1',
      currency: Currency.usd,
      stablecoinToken: 'USDB',
      balance: Money.fromMajorString('24500.00', Currency.usd),
      status: 'active',
    ),
    WalletAccount(
      id: 'sw_demo_cngn_02',
      address: '0x3A9a92C1897d2eB6C6a76C2Ef331908C5b38F242',
      currency: Currency.ngn,
      stablecoinToken: 'CNGN',
      balance: Money.fromMajorString('6820000.00', Currency.ngn),
      status: 'active',
    ),
    WalletAccount(
      id: 'sw_demo_mexe_03',
      address: '0x9B10d4818F2312643a60a7F03C12b07C6418B573',
      currency: Currency.mxn,
      stablecoinToken: 'MEXe',
      balance: Money.fromMajorString('48500.00', Currency.mxn),
      status: 'active',
    ),
    WalletAccount(
      id: 'sw_demo_cadc_04',
      address: '0x1C44F5a92B7e012354c41893D9B0A361e2A89F90',
      currency: Currency.cad,
      stablecoinToken: 'CADC',
      balance: Money.fromMajorString('8250.00', Currency.cad),
      status: 'active',
    ),
  ];

  static final List<EmployeeModel> employees = [
    EmployeeModel(
      id: 'emp_bunch_dillon',
      bmoniUserId: 'usr_bmoni_dillon_ngn',
      firstName: 'Bunch',
      lastName: 'Dillon',
      email: 'bunch.dillon@example.ng',
      phoneNumber: '+2348011112222',
      country: 'NG',
      countryName: 'Nigeria',
      targetCurrency: Currency.ngn,
      status: 'ACTIVE',
      onboardingStatus: 'ONBOARDED',
      walletStatus: 'PROVISIONED',
      cardStatus: 'ACTIVE',
      payrollAmount: Money.fromMajorString('3100000.00', Currency.ngn),
      usdPayrollAmount: Money.fromMajorString('2000.00', Currency.usd),
      walletAddress: '0x3A9a...F242',
      cardId: 'card_demo_ngn_01',
      cardLast4: '8814',
    ),
    EmployeeModel(
      id: 'emp_samson_jabo',
      bmoniUserId: 'usr_bmoni_samson_mxn',
      firstName: 'Samson',
      lastName: 'Jabo',
      email: 'samson.jabo@example.mx',
      phoneNumber: '+525512345678',
      country: 'MX',
      countryName: 'Mexico',
      targetCurrency: Currency.mxn,
      status: 'ACTIVE',
      onboardingStatus: 'ONBOARDED',
      walletStatus: 'PROVISIONED',
      cardStatus: 'ACTIVE',
      payrollAmount: Money.fromMajorString('35000.00', Currency.mxn),
      usdPayrollAmount: Money.fromMajorString('2000.00', Currency.usd),
      walletAddress: '0x9B10...B573',
      cardId: 'card_demo_mxn_02',
      cardLast4: '4289',
    ),
    EmployeeModel(
      id: 'emp_liam_tremblay',
      bmoniUserId: 'usr_bmoni_liam_cad',
      firstName: 'Liam',
      lastName: 'Tremblay',
      email: 'liam.tremblay@example.ca',
      phoneNumber: '+14165550192',
      country: 'CA',
      countryName: 'Canada',
      targetCurrency: Currency.cad,
      status: 'ACTIVE',
      onboardingStatus: 'ONBOARDED',
      walletStatus: 'PROVISIONED',
      cardStatus: 'ACTIVE',
      payrollAmount: Money.fromMajorString('2750.00', Currency.cad),
      usdPayrollAmount: Money.fromMajorString('2000.00', Currency.usd),
      walletAddress: '0x1C44...9F90',
      cardId: 'card_demo_cad_03',
      cardLast4: '9032',
    ),
  ];

  static final List<VirtualCardModel> cards = [
    VirtualCardModel(
      id: 'card_demo_usd_01',
      cardName: 'FlowPay Executive Card',
      cardColor: '#6366F1',
      currency: Currency.usd,
      status: 'active',
      last4: '5510',
      maskedPan: '•••• •••• •••• 5510',
      expirationDate: '08/29',
      monthlySpendLimit: Money.fromMajorString('5000.00', Currency.usd),
    ),
    VirtualCardModel(
      id: 'card_demo_ngn_01',
      cardName: 'Lagos Operations Card',
      cardColor: '#10B981',
      currency: Currency.ngn,
      status: 'active',
      last4: '8814',
      maskedPan: '•••• •••• •••• 8814',
      expirationDate: '11/28',
      monthlySpendLimit: Money.fromMajorString('1500000.00', Currency.ngn),
    ),
    VirtualCardModel(
      id: 'card_demo_mxn_02',
      cardName: 'Mexico City Card',
      cardColor: '#EC4899',
      currency: Currency.mxn,
      status: 'active',
      last4: '4289',
      maskedPan: '•••• •••• •••• 4289',
      expirationDate: '05/29',
      monthlySpendLimit: Money.fromMajorString('30000.00', Currency.mxn),
    ),
    VirtualCardModel(
      id: 'card_demo_cad_03',
      cardName: 'Toronto Engineering Card',
      cardColor: '#EF4444',
      currency: Currency.cad,
      status: 'active',
      last4: '9032',
      maskedPan: '•••• •••• •••• 9032',
      expirationDate: '02/30',
      monthlySpendLimit: Money.fromMajorString('4000.00', Currency.cad),
    ),
  ];

  static final List<CardTransactionModel> transactions = [
    CardTransactionModel(
      id: 'ctx_demo_01',
      cardId: 'card_demo_usd_01',
      amount: Money.fromMajorString('24.50', Currency.usd),
      merchantName: 'AWS Cloud Services',
      category: 'Software & Cloud',
      status: 'settled',
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    CardTransactionModel(
      id: 'ctx_demo_02',
      cardId: 'card_demo_usd_01',
      amount: Money.fromMajorString('15.00', Currency.usd),
      merchantName: 'GitHub Copilot Enterprise',
      category: 'Developer Tools',
      status: 'settled',
      timestamp: DateTime.now().subtract(const Duration(hours: 28)),
    ),
    CardTransactionModel(
      id: 'ctx_demo_03',
      cardId: 'card_demo_ngn_01',
      amount: Money.fromMajorString('45000.00', Currency.ngn),
      merchantName: 'Coworking Space Victoria Island',
      category: 'Office Space',
      status: 'settled',
      timestamp: DateTime.now().subtract(const Duration(hours: 50)),
    ),
    CardTransactionModel(
      id: 'ctx_demo_04',
      cardId: 'card_demo_cad_03',
      amount: Money.fromMajorString('85.20', Currency.cad),
      merchantName: 'Shopify Plus Team Subscription',
      category: 'Software',
      status: 'settled',
      timestamp: DateTime.now().subtract(const Duration(hours: 12)),
    ),
  ];

  static PayrollRunModel getPayrollPreview() {
    final item1 = PayrollItemModel(
      employeeId: 'emp_bunch_dillon',
      employeeName: 'Bunch Dillon',
      country: 'NG',
      targetCurrency: Currency.ngn,
      targetAmount: Money.fromMajorString('3100000.00', Currency.ngn), // ₦3,100,000
      usdAmount: Money.fromMajorString('2000.00', Currency.usd),        // $2,000
      exchangeRate: 1550.0,
      status: 'PENDING',
    );

    final item2 = PayrollItemModel(
      employeeId: 'emp_samson_jabo',
      employeeName: 'Samson Jabo',
      country: 'MX',
      targetCurrency: Currency.mxn,
      targetAmount: Money.fromMajorString('35000.00', Currency.mxn),   // $35,000 MXN
      usdAmount: Money.fromMajorString('2000.00', Currency.usd),        // $2,000
      exchangeRate: 17.5,
      status: 'PENDING',
    );

    final item3 = PayrollItemModel(
      employeeId: 'emp_liam_tremblay',
      employeeName: 'Liam Tremblay',
      country: 'CA',
      targetCurrency: Currency.cad,
      targetAmount: Money.fromMajorString('2750.00', Currency.cad),    // CA$2,750 CAD
      usdAmount: Money.fromMajorString('2000.00', Currency.usd),        // $2,000
      exchangeRate: 1.375,
      status: 'PENDING',
    );

    return PayrollRunModel(
      runId: 'demo_run_preview',
      title: 'Global Engineering & Design Payroll',
      totalUsd: Money.fromMajorString('6000.00', Currency.usd),
      totalFeeUsd: Money.fromMajorString('15.00', Currency.usd), // $15 vs $510 wire fee
      employeeCount: 3,
      countries: ['NG', 'MX', 'CA'],
      currencies: ['NGN', 'MXN', 'CAD'],
      items: [item1, item2, item3],
      status: 'PREVIEW',
      executedAt: DateTime.now(),
      isDemo: true,
    );
  }
}

