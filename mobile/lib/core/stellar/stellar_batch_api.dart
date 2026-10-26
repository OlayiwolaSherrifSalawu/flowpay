import '../network/api_client.dart';

/// A server-built, unsigned multi-operation Stellar transaction plus its quote.
class BatchProposal {
  final String proposalId;
  final String signPayload;
  final DateTime expiresAt;
  final List<Map<String, dynamic>> legs;
  final Map<String, String> maxTotals;

  const BatchProposal({
    required this.proposalId,
    required this.signPayload,
    required this.expiresAt,
    required this.legs,
    required this.maxTotals,
  });

  factory BatchProposal.fromJson(Map<String, dynamic> j) => BatchProposal(
        proposalId: j['proposalId'].toString(),
        signPayload: j['signPayload'].toString(),
        expiresAt: DateTime.tryParse(j['expiresAt']?.toString() ?? '') ?? DateTime.now(),
        legs: [for (final l in (j['legs'] as List? ?? const [])) Map<String, dynamic>.from(l as Map)],
        maxTotals: {
          for (final e in Map<String, dynamic>.from((j['maxTotals'] as Map?) ?? const {}).entries) e.key: e.value.toString(),
        },
      );
}

class BatchSettlement {
  /// COMPLETED or PENDING. Failures throw [ApiException].
  final String status;
  final String transactionHash;
  final String? explorerUrl;
  const BatchSettlement(this.status, this.transactionHash, this.explorerUrl);
  bool get isPending => status == 'PENDING';
}

/// `/api/payments/batch` — atomic multi-payment transactions on Stellar.
class StellarBatchApi {
  final FlowPayApiClient client;
  const StellarBatchApi(this.client);

  Future<BatchProposal> propose({
    required List<Map<String, dynamic>> legs,
    String? memo,
    String purpose = 'PAYMENT',
    String? reference,
  }) async {
    final res = await client.post('/api/payments/batch/propose', body: {
      'userId': client.userId,
      'legs': legs,
      if (memo != null) 'memo': memo,
      'purpose': purpose,
      if (reference != null) 'reference': reference,
    });
    return BatchProposal.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<BatchSettlement> execute({required String proposalId, required String signedXdr}) async {
    final res = Map<String, dynamic>.from(await client.post('/api/payments/batch/execute', body: {
      'userId': client.userId,
      'proposalId': proposalId,
      'signedXdr': signedXdr,
    }) as Map);
    final status = res['status']?.toString();
    if (status != 'COMPLETED' && status != 'PENDING') {
      throw StateError('Unexpected settlement status: $status');
    }
    return BatchSettlement(status!, res['transactionHash'].toString(), res['explorerUrl']?.toString());
  }
}
