import '../../money/currency.dart';
import '../../money/money.dart';
import '../../network/api_client.dart';
import '../../repositories/card_repository.dart';

class BmoniCardRepository implements CardRepository {
  final FlowPayApiClient apiClient;

  BmoniCardRepository({required this.apiClient});

  @override
  Future<List<VirtualCardModel>> getCards({
    String? smartWalletId,
    String? userId,
  }) async {
    final queryParams = <String, String>{};
    if (smartWalletId != null) queryParams['smartWalletId'] = smartWalletId;
    if (userId != null) queryParams['userId'] = userId;

    final queryString = queryParams.isNotEmpty
        ? '?${Uri(queryParameters: queryParams).query}'
        : '';
    final res = await apiClient.get('/api/cards$queryString');

    if (res is List) {
      return res.map((c) => _mapCardJson(c)).toList();
    }
    return [];
  }

  @override
  Future<VirtualCardModel> getCardDetail(
    String cardId, {
    String? smartWalletId,
    String? userId,
  }) async {
    final queryParams = <String, String>{};
    if (smartWalletId != null) queryParams['smartWalletId'] = smartWalletId;
    if (userId != null) queryParams['userId'] = userId;

    final queryString = queryParams.isNotEmpty
        ? '?${Uri(queryParameters: queryParams).query}'
        : '';
    final res = await apiClient.get('/api/cards/$cardId$queryString');
    return _mapCardJson(res);
  }

  @override
  Future<Map<String, dynamic>> getCardSensitiveData(
    String cardId, {
    String? identityId,
    String? userId,
  }) async {
    final queryParams = <String, String>{};
    if (identityId != null) queryParams['identityId'] = identityId;
    if (userId != null) queryParams['userId'] = userId;

    final queryString = queryParams.isNotEmpty
        ? '?${Uri(queryParameters: queryParams).query}'
        : '';
    final res = await apiClient.get('/api/cards/$cardId/sensitive$queryString');
    if (res is Map<String, dynamic>) {
      return res;
    }
    return <String, dynamic>{};
  }

  @override
  Future<CreateCardProposalResult> createCardProposal({
    required String cardName,
    String cardColor = '#F4B740',
    required Currency currency,
    required String smartWalletId,
    String? nin,
    String? userId,
  }) async {
    final res = await apiClient.post('/api/cards', body: {
      'userId': userId,
      'cardName': cardName,
      'cardColor': cardColor,
      'currency': currency.code,
      'smartWalletId': smartWalletId,
      if (nin != null && nin.isNotEmpty) 'nin': nin,
    });

    final proposalId = res['proposalId']?.toString() ??
        'prop_${DateTime.now().millisecondsSinceEpoch}';
    final proposalStatus =
        res['proposalStatus']?.toString() ?? 'PENDING_APPROVALS';
    final signPayload = res['signPayload'];
    final signPayloadPending = res['signPayloadPending'] == true;

    String? hashToSign;
    if (signPayload is Map) {
      hashToSign = signPayload['hashToSign']?.toString() ??
          signPayload['safeTxHash']?.toString() ??
          signPayload['userOpHash']?.toString();
    } else if (signPayload is String) {
      hashToSign = signPayload;
    }

    final cardJson = res['card'] is Map<String, dynamic>
        ? res['card'] as Map<String, dynamic>
        : <String, dynamic>{};
    final reservedCard = VirtualCardModel(
      id: cardJson['id']?.toString() ?? proposalId,
      cardName: cardJson['cardName']?.toString() ?? cardName,
      cardColor: cardJson['cardColor']?.toString() ?? cardColor,
      currency: currency,
      status: cardJson['status']?.toString() ?? 'RESERVED',
      isReserved: true,
      proposalId: proposalId,
      proposalStatus: proposalStatus,
      hashToSign: hashToSign,
      last4: cardJson['last4']?.toString() ?? '4289',
      maskedPan: cardJson['maskedPan']?.toString() ?? '•••• •••• •••• 4289',
      expirationDate: cardJson['expirationDate']?.toString() ?? '08/29',
    );

    return CreateCardProposalResult(
      proposalId: proposalId,
      proposalStatus: proposalStatus,
      hashToSign: hashToSign,
      signPayloadPending: signPayloadPending,
      feeAmount: res['feeAmount']?.toString(),
      feeCurrency: res['feeCurrency']?.toString(),
      reservedCard: reservedCard,
    );
  }

  @override
  Future<String> fetchSignPayload({
    required String proposalId,
    String? userId,
  }) async {
    final query = userId != null ? '?userId=$userId' : '';
    final res = await apiClient
        .get('/api/cards/proposals/$proposalId/sign-payload$query');
    if (res is Map && res['hashToSign'] != null) {
      return res['hashToSign'].toString();
    }
    throw StateError('Sign payload not ready or invalid response');
  }

  @override
  Future<VirtualCardModel> submitCardSignature({
    required String proposalId,
    required String signature,
    String? userId,
  }) async {
    final res =
        await apiClient.post('/api/cards/proposals/$proposalId/sign', body: {
      'userId': userId,
      'signature': signature,
    });
    final cardJson = res['card'] ?? res;
    return _mapCardJson(cardJson);
  }

  @override
  Future<VirtualCardModel> createCard({
    required String cardName,
    required String cardColor,
    required Currency currency,
    required String smartWalletId,
    String? nin,
  }) async {
    final proposal = await createCardProposal(
      cardName: cardName,
      cardColor: cardColor,
      currency: currency,
      smartWalletId: smartWalletId,
      nin: nin,
    );
    return proposal.reservedCard;
  }

  @override
  Future<List<CardTransactionModel>> getCardTransactions(
    String cardId, {
    int? size,
    String? status,
  }) async {
    final params = <String, String>{};
    if (size != null) params['size'] = size.toString();
    if (status != null) params['status'] = status;

    final query =
        params.isNotEmpty ? '?${Uri(queryParameters: params).query}' : '';
    final res = await apiClient.get('/api/cards/$cardId/transactions$query');

    if (res is List) {
      return res.map((t) {
        final cur = Currency.fromCode(t['currency'] ?? 'USD');
        // Parse strictly as major-unit numeric amount (e.g. 25.5 = $25.50)
        final majorNum = (t['amount'] as num?)?.toDouble() ??
            ((t['amountMinor'] as num?)?.toDouble() ?? 0.0) / 100.0;
        final minorUnits = (majorNum * 100).round();

        return CardTransactionModel(
          id: t['id'] ?? '',
          cardId: cardId,
          amount: Money.fromMinor(minorUnits, cur),
          merchantName: t['merchantName'] ?? 'Merchant',
          category: t['category'] ?? 'General',
          status: t['status'] ?? 'COMPLETED',
          timestamp: DateTime.tryParse(t['timestamp'] ?? '') ?? DateTime.now(),
        );
      }).toList();
    }
    return [];
  }

  @override
  Future<VirtualCardModel> setCardStatus(
    String cardId, {
    required bool freeze,
    String? userId,
  }) async {
    final statusString = freeze ? 'BLOCKED' : 'ACTIVE';
    final res = await apiClient.put('/api/cards/$cardId/status', body: {
      if (userId != null) 'userId': userId,
      'status': statusString,
    });
    return _mapCardJson(res);
  }

  @override
  Future<VirtualCardModel> toggleCardStatus(
    String cardId,
    String currentStatus,
  ) async {
    final isCurrentlyFrozen = currentStatus.toUpperCase() == 'BLOCKED' ||
        currentStatus.toUpperCase() == 'FROZEN';
    return setCardStatus(cardId, freeze: !isCurrentlyFrozen);
  }

  VirtualCardModel _mapCardJson(dynamic c) {
    if (c is! Map<String, dynamic>) {
      return const VirtualCardModel(
        id: 'card_fallback',
        cardName: 'FlowPay Card',
        cardColor: '#F4B740',
        currency: Currency.usd,
        status: 'ACTIVE',
        last4: '4289',
        maskedPan: '•••• •••• •••• 4289',
        expirationDate: '08/29',
      );
    }

    final cur = Currency.fromCode(c['currency'] ?? 'USD');
    final isReserved = c['isReserved'] == true || c['status'] == 'RESERVED';

    // Parse card ledger balance minor-unit string
    Money? cardBalance;
    if (c['balanceMinor'] != null) {
      final minorVal = int.tryParse(c['balanceMinor'].toString()) ?? 0;
      cardBalance = Money.fromMinor(minorVal, cur);
    }

    return VirtualCardModel(
      id: c['id']?.toString() ?? '',
      cardName: c['cardName']?.toString() ?? 'Payroll Spend Card',
      cardColor: c['cardColor']?.toString() ?? '#F4B740',
      currency: cur,
      status: c['status']?.toString() ?? (isReserved ? 'RESERVED' : 'ACTIVE'),
      isReserved: isReserved,
      proposalId: c['proposalId']?.toString(),
      proposalStatus: c['proposalStatus']?.toString(),
      last4: c['last4']?.toString() ?? '4289',
      maskedPan: c['maskedPan']?.toString() ?? '•••• •••• •••• 4289',
      expirationDate: c['expirationDate']?.toString() ?? '08/29',
      cvv: c['cvv']?.toString(),
      cardHolderName: c['cardHolderName']?.toString(),
      balance: cardBalance,
    );
  }
}
