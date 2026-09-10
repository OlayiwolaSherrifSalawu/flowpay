/// FlowPay Centralized UI Copy
///
/// Single source of truth for all user-facing strings in the FlowPay app.
///
/// Rules:
/// - No "B-Key", "BMONI", "secp256k1", "EVM", "rails", "multi-rail"
/// - No "custody", "settlement", "deterministic", "invariant pipeline"
/// - No "execution provider", "funding route", "smart contract"
/// - Plain English, action-oriented, consumer-friendly
abstract class AppCopy {
  // ── App-wide ──────────────────────────────────────────────────────────────

  static const String appName = 'FlowPay';
  static const String lockedMessage = 'FlowPay is locked';

  // ── Security / PIN ────────────────────────────────────────────────────────

  static const String requiresPin = 'Requires your PIN';
  static const String enterPinToConfirm = 'Enter your 6-digit PIN to confirm';
  static const String confirmItIsYou = "Confirm it's you with your PIN";
  static const String pinProtectsPayments = 'Your PIN protects all payments';
  static const String pinNeverStored = "Your PIN confirms every payment. It's never stored.";
  static const String pinReentry = 'Re-enter your PIN to confirm';
  static const String settingUpWallet = 'Setting up your secure wallet...';
  static const String loadingSecuritySettings = 'Loading security settings...';

  // ── Secure Wallet ─────────────────────────────────────────────────────────

  static const String secureWallet = 'Secure wallet';
  static const String securedOnDevice = 'Your account is secured on this device';
  static const String securedOnThisDevice = 'Your money is secured on this device';
  static const String deviceProtection = 'Protected with device security. Tap to learn more.';
  static const String accountAddress = 'Your account address';
  static const String copyAddress = 'Copy address';
  static const String addressCopied = 'Address copied';
  static const String manageSecureWallet = 'Manage your secure wallet';
  static const String walletReady = 'Set up and ready';
  static const String walletNotSetUp = 'Not set up yet';
  static const String bankGradeEncryption = 'Bank-grade encryption';

  // ── Payments / Transfers ──────────────────────────────────────────────────

  static const String sendMoney = 'Send money';
  static const String confirmPayment = 'Confirm payment';
  static const String paymentSent = 'Payment sent';
  static const String paymentApproved = 'Payment approved';
  static const String paymentFailed = 'Payment failed';
  static const String preparingPayment = 'Preparing your payment';
  static const String checkingBalance = 'Checking your balance';
  static const String understandingRequest = 'Understanding your request';
  static const String reviewTransfer = 'Review Transfer';
  static const String readyToSend = 'Ready to Send';
  static const String nothingMovesUntilApproval = 'Nothing moves until you approve.';
  static const String requiresPinToSend = 'Requires your PIN to send';
  static const String noFee = 'No fee';
  static const String recipient = 'Recipient';
  static const String amount = 'Amount';
  static const String exchangeRate = 'Exchange rate';
  static const String currencyExchange = 'Currency exchange';
  static const String howYoullPay = "How you'll pay";
  static const String afterThisPayment = 'AFTER THIS PAYMENT';

  // ── Activity ──────────────────────────────────────────────────────────────

  static const String loadingActivity = 'Loading your activity...';
  static const String noActivityYet = 'No activity yet';
  static const String noActivityDescription = 'Your payments and money movements will appear here.';
  static const String walletActivity = 'Wallet activity';
  static const String paymentReference = 'Payment reference';

  // ── Money Missions / Rules ────────────────────────────────────────────────

  static const String setupRule = 'Set up rule';
  static const String ruleSaved = 'Rule saved!';
  static const String ruleDeleted = 'Rule deleted';
  static const String approveRule = 'Approve this rule';
  static const String approveRuleDescription = "You're setting up:";
  static const String settingUp = 'Setting up...';
  static const String checkingYourPlan = 'Checking your plan...';
  static const String gotIt = 'Got it';
  static const String planCreated = 'Plan created';
  static const String everythingChecksOut = 'Everything checks out';
  static const String activateRule = 'Activate rule';
  static const String approvedWithPin = 'Approved with your PIN';
  static const String requiresPinToActivate = 'Requires your PIN to activate';
  static const String ruleTriggeredSuccessfully = '✓ Rule triggered successfully!';
  static const String ruleWillRunAutomatically =
      'FlowPay will automatically run this rule whenever the conditions are met.';
  static const String moneyIsProtected = 'Your money is protected';
  static const String testThisRule = 'Test this rule';
  static const String noActiveMissions = 'No Active Rules Yet';
  static const String typeRuleAbove = 'Describe a rule above to get started.';
  static const String suggestedRules = 'SUGGESTED RULES';
  static const String yourRule = 'YOUR RULE';
  static const String reviewedByAI = 'Reviewed by FlowPay AI';

  // ── AI ────────────────────────────────────────────────────────────────────

  static const String askAI = 'Ask AI';
  static const String aiOperatorTitle = 'FlowPay AI';
  static const String aiSubtitle = 'Understands your request • Never moves money without your PIN';
  static const String paymentDone = 'Payment done';
  static const String approveAndExecute = 'Approve & Send';
  static const String sendDirective = 'Send';

  // ── Security Screen ───────────────────────────────────────────────────────

  static const String accountIsSecured = 'Your account is secured';
  static const String fundsProtectedOnDevice = 'Your funds are protected on this device';
  static const String securityBodyText =
      'Your security is generated and protected inside your phone. It never touches FlowPay servers, cloud storage, or AI.';
  static const String walletSectionTitle = 'Secure wallet';
  static const String walletSectionSubtitle = 'Your wallet is stored safely on this device.';
  static const String pinBiometricsSectionTitle = 'PIN & biometrics';
  static const String pinBiometricsSectionSubtitle = 'How your payments are confirmed';
  static const String approvalSettingsSectionTitle = 'Approval settings';
  static const String howMoneyIsProtected = 'How your money is protected';
  static const String howFlowPayKeepsSafe = 'How FlowPay keeps your money safe';
  static const String onlyYouCanApprove =
      'FlowPay AI only makes suggestions. Only you can approve payments — nothing moves until you confirm with your PIN.';
  static const String paymentConfirmationLabel = 'Payment confirmation';
  static const String pinRequired = 'Requires your PIN';
  static const String securityPinLabel = 'Security PIN';
  static const String faceIdFingerprintLabel = 'Face ID & Fingerprint';
  static const String faceIdLocksApp = 'Locks your app when you close it';
  static const String pinConfirmsPayments = 'Your 6-digit PIN confirms every payment on this device.';
  static const String onlyYouCanApproveSimple =
      'FlowPay keeps your money secure on your device. Only you can approve transactions.';
  static const String testPin = 'Test PIN';

  // Approval rules section labels
  static const String sendingMoney = 'Sending money';
  static const String currencyExchanges = 'Currency exchanges';
  static const String automaticRules = 'Automatic rules';
  static const String cardActions = 'Card actions';
  static const String whenPinRequired = 'When your PIN is required';

  // 4-step security breakdown
  static const String step1Title = 'Understanding your request';
  static const String step1Body = 'FlowPay turns your words into a clear payment plan.';
  static const String step2Title = 'Checking your plan';
  static const String step2Body = 'FlowPay checks that your plan makes sense before anything moves.';
  static const String step3Title = 'You review everything';
  static const String step3Body = 'You see exactly where your money goes before you approve.';
  static const String step4Title = 'You confirm with your PIN';
  static const String step4Body = 'Your 6-digit PIN confirms every payment on this device.';

  // ── Wallets ───────────────────────────────────────────────────────────────

  static const String yourWallets = 'Your wallets';
  static const String totalBalance = 'Total balance';
  static const String addTestFunds = 'Add test funds';
  static const String loadingWallets = 'Loading wallets...';
  static const String multiCurrencyDescription = 'Send & receive in multiple currencies';

  // ── Business ─────────────────────────────────────────────────────────────

  static const String payrollActive = 'Payroll active';
  static const String confirmPayroll = 'Confirm payroll';
  static const String enterPinToConfirmPayroll = 'Enter your 6-digit PIN to confirm and send payroll.';
  static const String authorizingPayroll = 'Authorizing payments...';
  static const String verifyingAccounts = 'Verifying employee accounts...';
  static const String sendingPayments = 'Sending payments...';
  static const String allPaymentsSent = 'All employee payments sent successfully!';
  static const String payrollFailed = 'Payroll failed';
  static const String paymentProgress = 'Payment Progress';
  static const String totalPayout = 'TOTAL PAYOUT';
  static const String employeeBreakdown = 'EMPLOYEE BREAKDOWN';
  static const String paymentChannel = 'Payment channel';
  static const String retryPayment = 'Retry Payment';
  static const String notSetUpForPayment = 'Not set up for payment yet';
  static const String transferFeeLabel = 'Transfer fee';

  // Business Activity
  static const String activityTitle = 'Activity';
  static const String searchActivity = 'Search activity...';
  static const String noActivityFound = 'No activity found';
  static const String eventsLabel = 'Events';
  static const String countriesLabel = 'Countries';
  static const String securedLabel = 'Secured';

  // Employee Onboarding
  static const String authorizeWalletSetup = 'Authorize wallet setup';
  static const String confirmWalletSetup = 'Confirm wallet setup with your PIN.';
  static const String walletSetUpSuccessfully = 'Wallet set up successfully.';
  static const String identityVerified = 'Identity verified';
  static const String identityVerificationPassed = 'Identity Verification Passed';
  static const String submitIdentityDetails = 'Submit Identity Details';
  static const String setupInProgress = 'Setup in progress — we\'ll notify you when ready.';
  static const String onboardingComplete = 'Onboarding complete! This employee is ready for payroll.';
  static const String enablePayments = 'Enable Payments';
  static const String paymentAgreements = 'Payment Agreements';
  static const String paymentAgreementsSigned = 'Payment agreements signed successfully.';
  static const String faceVerification = 'Face verification';
  static const String walletDetails = 'Wallet Details';

  // ── Error Messages ────────────────────────────────────────────────────────

  static const String somethingWentWrong = 'Something went wrong';
  static const String tryAgain = 'Try again';
  static const String checkConnectionAndRetry = 'Please check your connection and try again.';
  static const String sessionExpired = 'Your session has expired. Please sign in again.';
  static const String serviceUnavailable = 'Our service is temporarily unavailable. Please try again shortly.';
  static const String pleaseWaitAndRetry = 'Please wait a moment and try again.';
  static const String unableToLoadWallet = 'Unable to Load Wallet';
  static const String noPermission = "You don't have permission to view this account.";
  static const String cannotRunPayroll = "Cannot run payroll: some employees aren't set up for payment yet.";
}

