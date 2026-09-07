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
      relationship: 'Mother',
      destinationCountry: 'Nigeria',
      countryFlag: '🇳🇬',
      currency: Currency.ngn,
      accountOrAddress: '0123456789 (GTBank)',
      isVerified: true,
      paymentCount: 14,
      lastPaymentDate: DateTime.now().subtract(const Duration(days: 4)),
    ),
    Beneficiary(
      id: 'ben_designer_02',
      nickname: 'Designer',
      legalName: 'Bunch Dillon',
      relationship: 'Lead Designer',
      destinationCountry: 'Nigeria',
      countryFlag: '🇳🇬',
      currency: Currency.ngn,
      accountOrAddress: '0x3A9a92C1897d2eB6C6a76C2Ef331908C5b38F242',
      isVerified: true,
      paymentCount: 6,
      lastPaymentDate: DateTime.now().subtract(const Duration(days: 12)),
    ),
    Beneficiary(
      id: 'ben_contractor_03',
      nickname: 'Contractor MX',
      legalName: 'Samson Jabo',
      relationship: 'Engineering Contractor',
      destinationCountry: 'Mexico',
      countryFlag: '🇲🇽',
      currency: Currency.mxn,
      accountOrAddress: '0x7e81C44F35dB56E522432d6771F52994B6b021ad',
      isVerified: true,
      paymentCount: 4,
      lastPaymentDate: DateTime.now().subtract(const Duration(days: 18)),
    ),
    Beneficiary(
      id: 'ben_sarah_04',
      nickname: 'Sarah',
      legalName: 'Sarah Jenkins',
      relationship: 'Sister',
      destinationCountry: 'United States',
      countryFlag: '🇺🇸',
      currency: Currency.usd,
      accountOrAddress: 'sarah.j@flowpay.me',
      isVerified: true,
      paymentCount: 8,
      lastPaymentDate: DateTime.now().subtract(const Duration(days: 2)),
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
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return BeneficiaryResolutionResult.notFound(query);
    }

    // 1. Exact match on nickname or legalName
    final exact = _beneficiaries.where((b) =>
        b.nickname.toLowerCase() == q ||
        b.legalName.toLowerCase() == q).toList();
    if (exact.length == 1) {
      return BeneficiaryResolutionResult.unique(exact.first, query);
    }

    // 2. Contains match
    final matches = _beneficiaries.where((b) =>
        b.nickname.toLowerCase().contains(q) ||
        b.legalName.toLowerCase().contains(q) ||
        b.relationship.toLowerCase().contains(q)).toList();

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
