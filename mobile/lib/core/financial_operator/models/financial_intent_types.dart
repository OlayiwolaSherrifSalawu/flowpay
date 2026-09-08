/// FlowPay Strongly Typed Financial Intents
/// Defines the complete set of financial intents supported by the FlowPay Financial Operator.
enum FinancialIntentType {
  sendMoney,
  receiveMoney,
  convertCurrency,
  allocateMoney,
  createReserve,
  updateReserve,
  createMission,
  updateMission,
  pauseMission,
  resumeMission,
  checkBalance,
  checkSpending,
  checkIncome,
  viewTransactions,
  payBeneficiary,
  payBill,
  askFinancialQuestion,
  unknown;

  String get code {
    switch (this) {
      case FinancialIntentType.sendMoney:
        return 'SEND_MONEY';
      case FinancialIntentType.receiveMoney:
        return 'RECEIVE_MONEY';
      case FinancialIntentType.convertCurrency:
        return 'CONVERT_CURRENCY';
      case FinancialIntentType.allocateMoney:
        return 'ALLOCATE_MONEY';
      case FinancialIntentType.createReserve:
        return 'CREATE_RESERVE';
      case FinancialIntentType.updateReserve:
        return 'UPDATE_RESERVE';
      case FinancialIntentType.createMission:
        return 'CREATE_MISSION';
      case FinancialIntentType.updateMission:
        return 'UPDATE_MISSION';
      case FinancialIntentType.pauseMission:
        return 'PAUSE_MISSION';
      case FinancialIntentType.resumeMission:
        return 'RESUME_MISSION';
      case FinancialIntentType.checkBalance:
        return 'CHECK_BALANCE';
      case FinancialIntentType.checkSpending:
        return 'CHECK_SPENDING';
      case FinancialIntentType.checkIncome:
        return 'CHECK_INCOME';
      case FinancialIntentType.viewTransactions:
        return 'VIEW_TRANSACTIONS';
      case FinancialIntentType.payBeneficiary:
        return 'PAY_BENEFICIARY';
      case FinancialIntentType.payBill:
        return 'PAY_BILL';
      case FinancialIntentType.askFinancialQuestion:
        return 'ASK_FINANCIAL_QUESTION';
      case FinancialIntentType.unknown:
        return 'UNKNOWN';
    }
  }

  String get displayName {
    switch (this) {
      case FinancialIntentType.sendMoney:
        return 'Send Money';
      case FinancialIntentType.receiveMoney:
        return 'Receive Money';
      case FinancialIntentType.convertCurrency:
        return 'Convert Currency';
      case FinancialIntentType.allocateMoney:
        return 'Allocate Money';
      case FinancialIntentType.createReserve:
        return 'Create Reserve';
      case FinancialIntentType.updateReserve:
        return 'Update Reserve';
      case FinancialIntentType.createMission:
        return 'Create Money Mission';
      case FinancialIntentType.updateMission:
        return 'Update Money Mission';
      case FinancialIntentType.pauseMission:
        return 'Pause Money Mission';
      case FinancialIntentType.resumeMission:
        return 'Resume Money Mission';
      case FinancialIntentType.checkBalance:
        return 'Check Balance';
      case FinancialIntentType.checkSpending:
        return 'Check Spending';
      case FinancialIntentType.checkIncome:
        return 'Check Income';
      case FinancialIntentType.viewTransactions:
        return 'View Transactions';
      case FinancialIntentType.payBeneficiary:
        return 'Pay Beneficiary';
      case FinancialIntentType.payBill:
        return 'Pay Bill';
      case FinancialIntentType.askFinancialQuestion:
        return 'Financial Advisory';
      case FinancialIntentType.unknown:
        return 'Unknown Request';
    }
  }

  static FinancialIntentType fromCode(String code) {
    final normalized = code.trim().toUpperCase().replaceAll('-', '_');
    for (final val in FinancialIntentType.values) {
      if (val.code == normalized) return val;
    }
    return FinancialIntentType.unknown;
  }
}
