/// BMONI Embedded Wallets & Cards Toolkit
/// Provides model-aware wallet cards, Riverpod notifiers, pluggable data contracts,
/// and transaction widgets built for BMONI infrastructure.
library bmoni_embedded_wallets_cards;

// Failures
export 'failures/embedded_failure.dart';

// Models
export 'models/either.dart';
export 'models/embedded_wallet.dart';

// Contracts
export 'contracts/embedded_wallet_read_data_source.dart';
export 'contracts/embedded_wallet_storage.dart';
export 'contracts/embedded_wallet_balance_cache.dart';

// Notifiers & Riverpod Providers
export 'notifiers/embedded_wallet_notifiers.dart';

// Widgets
export 'widgets/embedded_wallet_card.dart';
export 'widgets/embedded_wallet_transactions_section.dart';
