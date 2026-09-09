import 'dart:async';
import '../money/currency.dart';
import 'beneficiary_model.dart';

enum ResolutionStatus { unique, ambiguous, notFound }

class BeneficiaryResolutionResult {
  final ResolutionStatus status;
  final Beneficiary? match;
  final List<Beneficiary> candidates;
  final String query;

  const BeneficiaryResolutionResult._({
    required this.status,
    required this.query,
    this.match,
    this.candidates = const [],
  });

  factory BeneficiaryResolutionResult.unique(Beneficiary match, String query) =>
      BeneficiaryResolutionResult._(
        status: ResolutionStatus.unique,
        match: match,
        query: query,
      );

  factory BeneficiaryResolutionResult.ambiguous(
          List<Beneficiary> candidates, String query) =>
      BeneficiaryResolutionResult._(
        status: ResolutionStatus.ambiguous,
        candidates: candidates,
        query: query,
      );

  factory BeneficiaryResolutionResult.notFound(String query) =>
      BeneficiaryResolutionResult._(
        status: ResolutionStatus.notFound,
        query: query,
      );

  bool get isUnique => status == ResolutionStatus.unique;
  bool get isAmbiguous => status == ResolutionStatus.ambiguous;
  bool get isNotFound => status == ResolutionStatus.notFound;
}

abstract class BeneficiaryRepository {
  Future<List<Beneficiary>> getBeneficiaries();
  Future<BeneficiaryResolutionResult> resolveAlias(String query);
  Future<Beneficiary> addBeneficiary(Beneficiary beneficiary);
  Future<void> updateBeneficiary(Beneficiary beneficiary);
  Future<void> deleteBeneficiary(String id);
}

class DemoBeneficiaryRepository implements BeneficiaryRepository {
  final List<Beneficiary> _beneficiaries = [
    Beneficiary(
      id: 'ben_mom_01',
      nickname: 'Mom',
      legalName: 'Mary Fashola',
      aliases: const ['Mom', 'Mother', 'Mum', 'Mama'],
      relationship: 'Mother',
      destinationCountry: 'Nigeria',
      countryFlag: '🇳🇬',
      destinationType: 'bank_account',
      currency: Currency.ngn,
      preferredFundingCurrency: Currency.usd,
      accountOrAddress: '0123456789 (GTBank Nigerian bank account)',
      isVerified: true,
      paymentCount: 14,
      lastPaymentDate: DateTime.now().subtract(const Duration(days: 4)),
    ),
    Beneficiary(
      id: 'ben_designer_02',
      nickname: 'Designer',
      legalName: 'David Mensah',
      aliases: const ['Designer', 'David', 'Lead Designer'],
      relationship: 'Lead Designer',
      destinationCountry: 'Ghana',
      countryFlag: '🇬🇭',
      destinationType: 'mobile_money',
      currency: Currency.ghs,
      preferredFundingCurrency: Currency.usd,
      accountOrAddress: '0241234567 (MTN MoMo / Ecobank Ghana)',
      isVerified: true,
      paymentCount: 6,
      lastPaymentDate: DateTime.now().subtract(const Duration(days: 12)),
    ),
    Beneficiary(
      id: 'ben_contractor_03',
      nickname: 'Contractor MX',
      legalName: 'Samson Jabo',
      aliases: const ['Contractor', 'Samson', 'Contractor MX'],
      relationship: 'Engineering Contractor',
      destinationCountry: 'Mexico',
      countryFlag: '🇲🇽',
      destinationType: 'bank_account',
      currency: Currency.mxn,
      preferredFundingCurrency: Currency.usd,
      accountOrAddress: '0x7e81C44F35dB56E522432d6771F52994B6b021ad (CLABE SPEI)',
      isVerified: true,
      paymentCount: 4,
      lastPaymentDate: DateTime.now().subtract(const Duration(days: 18)),
    ),
    Beneficiary(
      id: 'ben_sarah_04',
      nickname: 'Sarah',
      legalName: 'Sarah Jenkins',
      aliases: const ['Sarah', 'Sister'],
      relationship: 'Sister',
      destinationCountry: 'United States',
      countryFlag: '🇺🇸',
      destinationType: 'evm_wallet',
      currency: Currency.usd,
      preferredFundingCurrency: Currency.usd,
      accountOrAddress: 'sarah.j@flowpay.me',
      isVerified: true,
      paymentCount: 8,
      lastPaymentDate: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Beneficiary(
      id: 'ben_brother_05',
      nickname: 'Brother',
      legalName: 'Tunde Fashola',
      aliases: const ['Brother', 'Bro', 'Tunde'],
      relationship: 'Brother',
      destinationCountry: 'Nigeria',
      countryFlag: '🇳🇬',
      destinationType: 'bank_account',
      currency: Currency.ngn,
      preferredFundingCurrency: Currency.usd,
      accountOrAddress: '0234567891 (Access Bank Nigeria)',
      isVerified: true,
      paymentCount: 5,
      lastPaymentDate: DateTime.now().subtract(const Duration(days: 6)),
    ),
  ];

  @override
  Future<List<Beneficiary>> getBeneficiaries() async {
    await Future.delayed(const Duration(milliseconds: 60));
    return List.unmodifiable(_beneficiaries);
  }

  @override
  Future<BeneficiaryResolutionResult> resolveAlias(String query) async {
    await Future.delayed(const Duration(milliseconds: 80));
    final trimmed = query.trim();
    if (RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(trimmed)) {
      final shortAddr =
          '${trimmed.substring(0, 6)}...${trimmed.substring(trimmed.length - 4)}';
      return BeneficiaryResolutionResult.unique(
        Beneficiary(
          id: 'ben_evm_${trimmed.toLowerCase()}',
          nickname: shortAddr,
          legalName: 'EVM Account ($shortAddr)',
          aliases: [trimmed, trimmed.toLowerCase(), shortAddr],
          relationship: 'Smart Wallet Recipient',
          destinationCountry: 'Global',
          countryFlag: '🌐',
          destinationType: 'evm_wallet',
          currency: Currency.usd,
          preferredFundingCurrency: Currency.usd,
          accountOrAddress: trimmed,
          isVerified: true,
        ),
        query,
      );
    }

    var q = trimmed.toLowerCase();
    q = q.replaceFirst(RegExp(r'^(?:my\s+|our\s+)'), '').trim();
    if (q.isEmpty) {
      return BeneficiaryResolutionResult.notFound(query);
    }

    // 1. Exact match on nickname, legalName, or explicit aliases array
    final exact = _beneficiaries.where((b) {
      if (b.nickname.toLowerCase() == q || b.legalName.toLowerCase() == q) {
        return true;
      }
      return b.aliases.any((a) => a.toLowerCase() == q);
    }).toList();

    if (exact.length == 1) {
      return BeneficiaryResolutionResult.unique(exact.first, query);
    } else if (exact.length > 1) {
      return BeneficiaryResolutionResult.ambiguous(exact, query);
    }

    // 2. Contains match on nickname, legalName, aliases, or relationship
    final matches = _beneficiaries.where((b) {
      if (b.nickname.toLowerCase().contains(q) ||
          b.legalName.toLowerCase().contains(q) ||
          b.relationship.toLowerCase().contains(q)) {
        return true;
      }
      return b.aliases.any((a) => a.toLowerCase().contains(q));
    }).toList();

    if (matches.length == 1) {
      return BeneficiaryResolutionResult.unique(matches.first, query);
    } else if (matches.length > 1) {
      return BeneficiaryResolutionResult.ambiguous(matches, query);
    }

    return BeneficiaryResolutionResult.notFound(query);
  }

  @override
  Future<Beneficiary> addBeneficiary(Beneficiary beneficiary) async {
    _beneficiaries.add(beneficiary);
    return beneficiary;
  }

  @override
  Future<void> updateBeneficiary(Beneficiary beneficiary) async {
    final idx = _beneficiaries.indexWhere((b) => b.id == beneficiary.id);
    if (idx != -1) {
      _beneficiaries[idx] = beneficiary;
    }
  }

  @override
  Future<void> deleteBeneficiary(String id) async {
    _beneficiaries.removeWhere((b) => b.id == id);
  }
}
