import '../money/money.dart';

class OperationPreview {
  final String previewId;
  final String intentId;
  final String summary;
  final Money sourceAmount;
  final Money estimatedFee;
  final Money totalAmount;
  final String recipient;
  final bool requiresOnDeviceSigning;
  final List<String> warnings;

  const OperationPreview({
    required this.previewId,
    required this.intentId,
    required this.summary,
    required this.sourceAmount,
    required this.estimatedFee,
    required this.totalAmount,
    required this.recipient,
    required this.requiresOnDeviceSigning,
    this.warnings = const [],
  });

  factory OperationPreview.fromIntentAndBalance({
    required String intentId,
    required Money amount,
    required String recipient,
    required Money availableBalance,
  }) {
    if (amount.isGreaterThan(availableBalance)) {
      throw ArgumentError(
        'Insufficient funds: Available ${availableBalance.formatFormatted()}, Requested ${amount.formatFormatted()}',
      );
    }

    final fee = Money.fromMinor(10, amount.currency); // Nominal minor unit fee
    final total = amount.add(fee);

    return OperationPreview(
      previewId: 'prev_${DateTime.now().millisecondsSinceEpoch}',
      intentId: intentId,
      summary: 'Transfer ${amount.formatFormatted()} to $recipient',
      sourceAmount: amount,
      estimatedFee: fee,
      totalAmount: total,
      recipient: recipient,
      requiresOnDeviceSigning: true,
      warnings: const [],
    );
  }
}
