import '../../money/currency.dart';
import '../../money/money.dart';
import '../../repositories/card_repository.dart';

class DemoCardRepository implements CardRepository {
  final List<VirtualCardModel> _cards = [
    VirtualCardModel(
      id: 'card_demo_bunch_01',
      cardName: 'Nigeria Operations Card',
      cardColor: '#F4B740', // FlowPay Amber per design.md §4.5
      currency: Currency.ngn,
      status: 'ACTIVE',
      last4: '4289',
      maskedPan: '•••• •••• •••• 4289',
      expirationDate: '08/29',
      cvv: '824',
      cardHolderName: 'Bunch Dillon',
      balance: Money.fromMinor(45000000, Currency.ngn), // ₦450,000.00
      isReserved: false,
    ),
    VirtualCardModel(
      id: 'card_demo_samson_02',
      cardName: 'Mexico LatAm Spend Card',
      cardColor: '#F4B740', // FlowPay Amber per design.md §4.5
      currency: Currency.usd,
      status: 'ACTIVE',
      last4: '8814',
      maskedPan: '•••• •••• •••• 8814',
      expirationDate: '11/28',
      cvv: '491',
      cardHolderName: 'Samson Jabo',
      balance: Money.fromMinor(120000, Currency.usd), // $1,200.00
      isReserved: false,
    ),
  ];

  @override
  Future<List<VirtualCardModel>> getCards({
    String? smartWalletId,
    String? userId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _cards;
  }

  @override
  Future<VirtualCardModel> getCardDetail(
    String cardId, {
    String? smartWalletId,
    String? userId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final card = _cards.firstWhere(
      (c) => c.id == cardId,
      orElse: () => _cards.first,
    );
    return card;
  }

  @override
  Future<Map<String, dynamic>> getCardSensitiveData(
    String cardId, {
    String? identityId,
    String? userId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final card = _cards.firstWhere(
      (c) => c.id == cardId,
      orElse: () => _cards.first,
    );
    return {
      'pan': '539983838383${card.last4}',
      'cvv': card.cvv ?? '824',
      'expirationDate': card.expirationDate,
      'billingAddress': {
        'line1': '14 Admiralty Way, Lekki Phase 1',
        'city': 'Lagos',
        'country': 'NG',
      },
    };
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
    await Future.delayed(const Duration(milliseconds: 200));

    final proposalId = 'prop_card_${DateTime.now().millisecondsSinceEpoch}';
    final dummyHash =
        '0x${DateTime.now().millisecondsSinceEpoch.toRadixString(16).padLeft(64, '0')}';

    final reservedCard = VirtualCardModel(
      id: proposalId,
      cardName: cardName,
      cardColor: cardColor,
      currency: currency,
      status: 'RESERVED',
      isReserved: true,
      proposalId: proposalId,
      proposalStatus: 'PENDING_APPROVALS',
      hashToSign: dummyHash,
      last4: '4289',
      maskedPan: '•••• •••• •••• 4289',
      expirationDate: '08/29',
      cardHolderName: 'Employee',
      balance: Money.fromMinor(0, currency),
    );

    _cards.insert(0, reservedCard);

    return CreateCardProposalResult(
      proposalId: proposalId,
      proposalStatus: 'PENDING_APPROVALS',
      hashToSign: dummyHash,
      signPayloadPending: false,
      feeAmount: currency == Currency.ngn ? '1000' : '2',
      feeCurrency: currency.code,
      reservedCard: reservedCard,
    );
  }

  @override
  Future<String> fetchSignPayload({
    required String proposalId,
    String? userId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return '0x${proposalId.hashCode.toRadixString(16).padLeft(64, '0')}';
  }

  @override
  Future<VirtualCardModel> submitCardSignature({
    required String proposalId,
    required String signature,
    String? userId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final idx = _cards
        .indexWhere((c) => c.id == proposalId || c.proposalId == proposalId);
    if (idx != -1) {
      final old = _cards[idx];
      final activated = old.copyWith(
        id: 'card_${DateTime.now().millisecondsSinceEpoch}',
        status: 'ACTIVE',
        isReserved: false,
        proposalStatus: 'COMPLETED',
        balance: Money.fromMinor(5000000, old.currency),
      );
      _cards[idx] = activated;
      return activated;
    }
    throw StateError('Proposal not found');
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
    await Future.delayed(const Duration(milliseconds: 120));
    return [
      CardTransactionModel(
        id: 'ctx_demo_01',
        cardId: cardId,
        amount: Money.fromMinor(2450, Currency.usd), // $24.50
        merchantName: 'AWS Cloud Services',
        category: 'Software & Cloud',
        status: 'COMPLETED',
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      CardTransactionModel(
        id: 'ctx_demo_02',
        cardId: cardId,
        amount: Money.fromMinor(1500, Currency.usd), // $15.00
        merchantName: 'GitHub Copilot Enterprise',
        category: 'Developer Tools',
        status: 'COMPLETED',
        timestamp: DateTime.now().subtract(const Duration(hours: 28)),
      ),
      CardTransactionModel(
        id: 'ctx_demo_03',
        cardId: cardId,
        amount: Money.fromMinor(4800, Currency.usd), // $48.00
        merchantName: 'Figma Professional Team',
        category: 'Design Tools',
        status: 'COMPLETED',
        timestamp: DateTime.now().subtract(const Duration(hours: 72)),
      ),
    ];
  }

  @override
  Future<VirtualCardModel> setCardStatus(
    String cardId, {
    required bool freeze,
    String? userId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final idx = _cards.indexWhere((c) => c.id == cardId);
    if (idx != -1) {
      final old = _cards[idx];
      final newStatus = freeze ? 'BLOCKED' : 'ACTIVE';
      final updated = old.copyWith(status: newStatus);
      _cards[idx] = updated;
      return updated;
    }
    throw StateError('Card not found');
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
}
