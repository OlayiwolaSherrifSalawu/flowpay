import '../../design_system/states.dart';
import '../../money/currency.dart';
import '../../money/money.dart';
import '../../repositories/activity_repository.dart';

class DemoActivityRepository implements ActivityRepository {
  final List<ActivityModel> _activities = [
    // 1. Pending Approvals
    ActivityModel(
      id: 'act_demo_01',
      title: 'Transfer to Designer in Ghana',
      description:
          'Transfer of \$500.00 USD awaiting on-device B-Key PIN approval',
      amount: Money.fromMajorString('500.00', Currency.usd),
      currency: Currency.usd,
      type: ActivityType.transfer,
      category: ActivityCategory.transfer,
      counterparty: 'Kofi Mensah (Ghana)',
      status: FlowPayAppStatus.awaitingApproval,
      timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
      reference: 'FP-TXN-884210',
      source: 'Personal Smart Wallet (USDB)',
      destination: 'Kofi Mensah (0x892B...3c12)',
      fee: Money.fromMajorString('0.50', Currency.usd),
      exchangeRate: 'N/A (Direct Currency)',
      bmoniReference: 'prop_bmoni_0428',
      metadata: {
        'recipient': 'kofi.mensah@example.gh',
        'rail': 'USDB',
        'proposalId': 'prop_bmoni_0428'
      },
    ),
    ActivityModel(
      id: 'act_demo_02',
      title: 'Tax Reserve 20% Auto-Sweep',
      description: 'AI-interpreted mission rule awaiting user confirmation',
      amount: Money.fromMajorString('320.00', Currency.usd),
      currency: Currency.usd,
      type: ActivityType.mission,
      category: ActivityCategory.mission,
      counterparty: 'Tax Reserve Vault (USDB)',
      status: FlowPayAppStatus.awaitingApproval,
      timestamp: DateTime.now().subtract(const Duration(minutes: 35)),
      reference: 'FP-MSN-991204',
      source: 'Personal Smart Wallet (USDB)',
      destination: 'Tax Reserve Smart Vault',
      fee: Money.fromMajorString('0.00', Currency.usd),
      exchangeRate: 'N/A',
      bmoniReference: 'prop_mission_9912',
      metadata: {'rule': '20% Tax Reserve Auto-Sweep'},
    ),

    // 2. Mission Executions
    ActivityModel(
      id: 'act_demo_03',
      title: 'Emergency Fund Auto-Sweep',
      description: 'Mission executed: \$240.00 swept to high-yield NGN savings',
      amount: Money.fromMajorString('240.00', Currency.usd),
      currency: Currency.usd,
      type: ActivityType.mission,
      category: ActivityCategory.mission,
      counterparty: 'High-Yield NGN Savings Vault',
      status: FlowPayAppStatus.completed,
      timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 15)),
      reference: 'FP-SWEEP-9812',
      source: 'Personal USDB Wallet',
      destination: 'CNGN High-Yield Vault (0x55F...77A)',
      fee: Money.fromMajorString('0.10', Currency.usd),
      exchangeRate: '1 USD = 1,550.00 NGN',
      bmoniReference: '0x88fbc921...33d1',
      metadata: {'rule': '20% Emergency Fund Auto-Sweep', 'rail': 'CNGN'},
    ),

    // 3. Transfers
    ActivityModel(
      id: 'act_demo_04',
      title: 'Transfer to Bunch Dillon',
      description: 'Sent \$150.00 USD (settled via B-Key on-device signing)',
      amount: Money.fromMajorString('150.00', Currency.usd),
      currency: Currency.usd,
      type: ActivityType.transfer,
      category: ActivityCategory.transfer,
      counterparty: 'Bunch Dillon (Nigeria)',
      status: FlowPayAppStatus.completed,
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
      reference: 'FP-TXN-0428',
      source: 'Personal Smart Wallet (USDB)',
      destination: 'Bunch Dillon (0x71C...9a19)',
      fee: Money.fromMajorString('0.50', Currency.usd),
      exchangeRate: 'N/A (Direct Currency)',
      bmoniReference: '0x3a92b77...deterministic',
      metadata: {'recipient': 'bunch.dillon@example.ng', 'rail': 'USDB'},
    ),
    ActivityModel(
      id: 'act_demo_05',
      title: 'Transfer to Samson Jabo',
      description: 'Disbursement of \$1,200.00 USD equivalent in Mexican Pesos',
      amount: Money.fromMajorString('1200.00', Currency.usd),
      currency: Currency.usd,
      type: ActivityType.transfer,
      category: ActivityCategory.transfer,
      counterparty: 'Samson Jabo (Mexico)',
      status: FlowPayAppStatus.processing,
      timestamp: DateTime.now().subtract(const Duration(hours: 6)),
      reference: 'FP-TXN-1192',
      source: 'Personal Smart Wallet (USDB)',
      destination: 'Samson Jabo SPEI CLABE',
      fee: Money.fromMajorString('1.20', Currency.usd),
      exchangeRate: '1 USD = 17.50 MXN',
      bmoniReference: 'prop_bmoni_1192',
      metadata: {'recipient': 'samson.jabo@example.mx', 'rail': 'MEXe'},
    ),
    ActivityModel(
      id: 'act_demo_06',
      title: 'Transfer to Liam Tremblay',
      description: 'Cross-border payment of \$450.00 CAD initiated',
      amount: Money.fromMajorString('450.00', Currency.cad),
      currency: Currency.cad,
      type: ActivityType.transfer,
      category: ActivityCategory.transfer,
      counterparty: 'Liam Tremblay (Canada)',
      status: FlowPayAppStatus.pending,
      timestamp: DateTime.now().subtract(const Duration(hours: 9)),
      reference: 'FP-TXN-6610',
      source: 'CADC Smart Wallet',
      destination: 'Liam Tremblay Interac Rail',
      fee: Money.fromMajorString('0.75', Currency.cad),
      exchangeRate: 'N/A (Direct CADC)',
      bmoniReference: 'prop_cad_6610',
      metadata: {'recipient': 'liam.tremblay@example.ca', 'rail': 'CADC'},
    ),

    // 4. Conversions (FX)
    ActivityModel(
      id: 'act_demo_07',
      title: 'Instant FX: USD → NGN',
      description: 'Converted \$500.00 USD to ₦775,000 NGN @ 1,550.00',
      amount: Money.fromMajorString('500.00', Currency.usd),
      currency: Currency.usd,
      type: ActivityType.conversion,
      category: ActivityCategory.fx,
      counterparty: 'BMONI cNGN Liquidity Pool',
      status: FlowPayAppStatus.completed,
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      reference: 'FP-FX-3319',
      source: 'Personal USDB Wallet',
      destination: 'Personal CNGN Wallet',
      fee: Money.fromMajorString('0.05', Currency.usd),
      exchangeRate: '1 USD = 1,550.00 NGN',
      bmoniReference: '0x49ca...9102',
      metadata: {'source': 'USDB', 'target': 'CNGN', 'rate': '1550.00'},
    ),

    // 5. Card Transactions
    ActivityModel(
      id: 'act_demo_08',
      title: 'Virtual Card: AWS Cloud Services',
      description:
          'Card •••• 5510 authorized \$24.50 recurring cloud subscription',
      amount: Money.fromMajorString('24.50', Currency.usd),
      currency: Currency.usd,
      type: ActivityType.card,
      category: ActivityCategory.card,
      counterparty: 'AWS EMEA S.a.r.l.',
      status: FlowPayAppStatus.completed,
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 8)),
      reference: 'FP-CRD-8812',
      source: 'FlowPay Virtual Card (•••• 5510)',
      destination: 'AWS EMEA Merchant',
      fee: Money.fromMajorString('0.00', Currency.usd),
      exchangeRate: 'N/A',
      bmoniReference: 'auth_card_8812',
      metadata: {'merchant': 'AWS EMEA', 'cardLast4': '5510'},
    ),
    ActivityModel(
      id: 'act_demo_09',
      title: 'Virtual Card: Hotel Pre-Authorization',
      description: 'Booking reservation hold cancelled and released',
      amount: Money.fromMajorString('180.00', Currency.usd),
      currency: Currency.usd,
      type: ActivityType.card,
      category: ActivityCategory.card,
      counterparty: 'Hilton Worldwide',
      status: FlowPayAppStatus.cancelled,
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      reference: 'FP-CRD-0041',
      source: 'FlowPay Virtual Card (•••• 5510)',
      destination: 'Hilton Worldwide Hold',
      fee: Money.fromMajorString('0.00', Currency.usd),
      exchangeRate: 'N/A',
      bmoniReference: 'void_crd_0041',
      metadata: {
        'merchant': 'Hilton Worldwide',
        'reason': 'Customer Cancellation'
      },
    ),

    // 6. Wallet Operations
    ActivityModel(
      id: 'act_demo_10',
      title: 'Smart Wallet Provisioning',
      description:
          'B-Key on-device keypair initialized and registered with BMONI',
      amount: Money.fromMajorString('0.00', Currency.usd),
      currency: Currency.usd,
      type: ActivityType.wallet,
      category: ActivityCategory.system,
      counterparty: 'BMONI Embedded Rails',
      status: FlowPayAppStatus.completed,
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      reference: 'FP-WLT-0001',
      source: 'On-Device Secure Enclave (B-Key)',
      destination: 'BMONI Testnet Account Abstraction',
      fee: Money.fromMajorString('0.00', Currency.usd),
      exchangeRate: 'N/A',
      bmoniReference: '0x71C84517C3741Cd1f85D2F2c3e14B9245A009a19',
      metadata: {'enclave': 'Hardware Keystore / Secure Enclave'},
    ),

    // 7. Failures
    ActivityModel(
      id: 'act_demo_11',
      title: 'Contractor Card Cap Exceeded',
      description:
          'Transaction declined: Attempted \$650.00 spend exceeded \$500 monthly cap',
      amount: Money.fromMajorString('650.00', Currency.usd),
      currency: Currency.usd,
      type: ActivityType.card,
      category: ActivityCategory.card,
      counterparty: 'Apple Store Regent Street',
      status: FlowPayAppStatus.failed,
      timestamp: DateTime.now().subtract(const Duration(days: 3, hours: 4)),
      reference: 'FP-CRD-DECL-901',
      source: 'FlowPay Contractor Card (•••• 9012)',
      destination: 'Apple Store POS',
      fee: Money.fromMajorString('0.00', Currency.usd),
      exchangeRate: 'N/A',
      bmoniReference: 'decl_crd_9012_limit',
      metadata: {
        'reason': 'Monthly spend cap (\$500.00) exceeded',
        'merchant': 'Apple Store'
      },
    ),
    ActivityModel(
      id: 'act_demo_12',
      title: 'Transfer to Vendor Failed',
      description:
          'Transfer failed: Target routing account temporarily unreachable',
      amount: Money.fromMajorString('250.00', Currency.usd),
      currency: Currency.usd,
      type: ActivityType.transfer,
      category: ActivityCategory.transfer,
      counterparty: 'Apex Global Logistics',
      status: FlowPayAppStatus.failed,
      timestamp: DateTime.now().subtract(const Duration(days: 4)),
      reference: 'FP-TXN-FAIL-302',
      source: 'Personal USDB Wallet',
      destination: 'Apex Global Account',
      fee: Money.fromMajorString('0.00', Currency.usd),
      exchangeRate: 'N/A',
      bmoniReference: 'err_rail_unreachable',
      metadata: {
        'reason': 'Target rail network timeout',
        'recipient': 'Apex Global'
      },
    ),
  ];

  @override
  Future<List<ActivityModel>> getRecentActivities({
    int limit = 50,
    ActivityCategory? category,
    ActivityType? type,
  }) async {
    var list = _activities;
    if (type != null) {
      list = list.where((a) => a.type == type).toList();
    } else if (category != null) {
      list = list.where((a) => a.category == category).toList();
    }
    return list.take(limit).toList();
  }

  @override
  Future<ActivityModel> recordActivity(ActivityModel activity) async {
    final idx = _activities.indexWhere(
      (a) =>
          a.id == activity.id ||
          (a.reference.isNotEmpty && a.reference == activity.reference),
    );
    if (idx != -1) {
      _activities[idx] = activity;
    } else {
      _activities.insert(0, activity);
    }
    return activity;
  }
}
