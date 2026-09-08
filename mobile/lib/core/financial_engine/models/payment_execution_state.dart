/// FlowPay Financial Execution State Machine
/// Explicit states that track financial operations from intent to final settlement.
enum PaymentExecutionState {
  draft,
  planning,
  quoteReady,
  awaitingApproval,
  approved,
  fundsReserved,
  conversionPending,
  conversionComplete,
  transferPending,
  settlementPending,
  completed,

  // Failure and cancellation states
  quoteExpired,
  insufficientFunds,
  providerUnavailable,
  conversionFailed,
  transferFailed,
  settlementFailed,
  cancelled;

  bool get isTerminal =>
      this == PaymentExecutionState.completed ||
      this == PaymentExecutionState.quoteExpired ||
      this == PaymentExecutionState.insufficientFunds ||
      this == PaymentExecutionState.providerUnavailable ||
      this == PaymentExecutionState.conversionFailed ||
      this == PaymentExecutionState.transferFailed ||
      this == PaymentExecutionState.settlementFailed ||
      this == PaymentExecutionState.cancelled;

  bool get isFailure =>
      this == PaymentExecutionState.quoteExpired ||
      this == PaymentExecutionState.insufficientFunds ||
      this == PaymentExecutionState.providerUnavailable ||
      this == PaymentExecutionState.conversionFailed ||
      this == PaymentExecutionState.transferFailed ||
      this == PaymentExecutionState.settlementFailed;

  bool get isSuccess => this == PaymentExecutionState.completed;

  bool get isAwaitingApproval => this == PaymentExecutionState.awaitingApproval;

  bool get isExecuting =>
      this == PaymentExecutionState.approved ||
      this == PaymentExecutionState.fundsReserved ||
      this == PaymentExecutionState.conversionPending ||
      this == PaymentExecutionState.conversionComplete ||
      this == PaymentExecutionState.transferPending ||
      this == PaymentExecutionState.settlementPending;

  String get humanLabel {
    switch (this) {
      case PaymentExecutionState.draft:
        return 'Drafting';
      case PaymentExecutionState.planning:
        return 'Analyzing Intent';
      case PaymentExecutionState.quoteReady:
        return 'Quote Ready';
      case PaymentExecutionState.awaitingApproval:
        return 'Awaiting Approval';
      case PaymentExecutionState.approved:
        return 'Approved';
      case PaymentExecutionState.fundsReserved:
        return 'Funds Reserved';
      case PaymentExecutionState.conversionPending:
        return 'Converting Currency';
      case PaymentExecutionState.conversionComplete:
        return 'Conversion Complete';
      case PaymentExecutionState.transferPending:
        return 'Transferring Funds';
      case PaymentExecutionState.settlementPending:
        return 'Settling on Rail';
      case PaymentExecutionState.completed:
        return 'Completed';
      case PaymentExecutionState.quoteExpired:
        return 'Quote Expired';
      case PaymentExecutionState.insufficientFunds:
        return 'Insufficient Funds';
      case PaymentExecutionState.providerUnavailable:
        return 'Provider Unavailable';
      case PaymentExecutionState.conversionFailed:
        return 'Conversion Failed';
      case PaymentExecutionState.transferFailed:
        return 'Transfer Failed';
      case PaymentExecutionState.settlementFailed:
        return 'Settlement Failed';
      case PaymentExecutionState.cancelled:
        return 'Cancelled';
    }
  }
}
