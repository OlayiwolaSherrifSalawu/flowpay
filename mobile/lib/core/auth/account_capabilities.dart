import 'dart:convert';

/// Which mode the user is currently viewing.
/// Persisted so a relaunch doesn't force the picker again unnecessarily.
enum AccountMode {
  personal,
  business,
}

extension AccountModeExtension on AccountMode {
  String get displayName {
    switch (this) {
      case AccountMode.personal:
        return 'Personal';
      case AccountMode.business:
        return 'Business';
    }
  }

  String get description {
    switch (this) {
      case AccountMode.personal:
        return 'Multi-currency smart wallets, virtual spend cards, and money missions.';
      case AccountMode.business:
        return 'Multi-country payroll, team spend limits, and one-bill settlement.';
    }
  }
}

/// What this device's logged-in user is allowed to see.
/// Derived from FlowPay backend (which employer/company records reference this bmoniUserId,
/// plus whether a personal smart wallet exists).
class AccountCapabilities {
  final bool hasPersonalWallet;
  final bool hasBusinessAccess; // true if bmoniUserId is linked as employer/admin to a company
  final String? companyName;
  final String? companyRole;
  final String? bmoniUserId;
  final DateTime? cachedAt;

  const AccountCapabilities({
    required this.hasPersonalWallet,
    required this.hasBusinessAccess,
    this.companyName,
    this.companyRole,
    this.bmoniUserId,
    this.cachedAt,
  });

  /// Default capabilities for fresh demo session
  factory AccountCapabilities.demo() => AccountCapabilities(
        hasPersonalWallet: true,
        hasBusinessAccess: true,
        companyName: 'FlowPay Technologies Ltd',
        companyRole: 'ADMIN',
        bmoniUserId: 'usr_flowpay_sandbox_master',
        cachedAt: DateTime.now(),
      );

  /// Personal-only account capabilities
  factory AccountCapabilities.personalOnly({
    required String bmoniUserId,
  }) =>
      AccountCapabilities(
        hasPersonalWallet: true,
        hasBusinessAccess: false,
        companyName: null,
        companyRole: null,
        bmoniUserId: bmoniUserId,
        cachedAt: DateTime.now(),
      );

  /// Business-only account capabilities
  factory AccountCapabilities.businessOnly({
    required String bmoniUserId,
    required String companyName,
    String companyRole = 'ADMIN',
  }) =>
      AccountCapabilities(
        hasPersonalWallet: false,
        hasBusinessAccess: true,
        companyName: companyName,
        companyRole: companyRole,
        bmoniUserId: bmoniUserId,
        cachedAt: DateTime.now(),
      );

  bool get hasBothModes => hasPersonalWallet && hasBusinessAccess;

  Map<String, dynamic> toJson() => {
        'hasPersonalWallet': hasPersonalWallet,
        'hasBusinessAccess': hasBusinessAccess,
        if (companyName != null) 'companyName': companyName,
        if (companyRole != null) 'companyRole': companyRole,
        if (bmoniUserId != null) 'bmoniUserId': bmoniUserId,
        if (cachedAt != null) 'cachedAt': cachedAt!.toIso8601String(),
      };

  factory AccountCapabilities.fromJson(Map<String, dynamic> json) {
    return AccountCapabilities(
      hasPersonalWallet: json['hasPersonalWallet'] as bool? ?? false,
      hasBusinessAccess: json['hasBusinessAccess'] as bool? ?? false,
      companyName: json['companyName'] as String? ??
          (json['company'] is Map ? json['company']['name'] as String? : null),
      companyRole: json['companyRole'] as String? ??
          (json['company'] is Map ? json['company']['role'] as String? : null),
      bmoniUserId: json['bmoniUserId'] as String?,
      cachedAt: json['cachedAt'] != null
          ? DateTime.tryParse(json['cachedAt'] as String)
          : null,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory AccountCapabilities.fromJsonString(String source) =>
      AccountCapabilities.fromJson(jsonDecode(source) as Map<String, dynamic>);
}

/// Registration Account Type
enum AccountType {
  personal,
  business,
}

/// KYC Verification Status
enum KycStatus {
  unverified,
  pending,
  verified,
}

/// FlowPay User Profile
class UserProfile {
  final String userId;
  final String fullName;
  final String email;
  final AccountType accountType;
  final String country;
  final String phone;
  final KycStatus kycStatus;
  final String? nationalId;
  final String? nationalIdType;
  final String? companyName;
  final String? companyRole;
  final String? companyRegNumber;
  final DateTime createdAt;

  const UserProfile({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.accountType,
    required this.country,
    required this.phone,
    this.kycStatus = KycStatus.unverified,
    this.nationalId,
    this.nationalIdType,
    this.companyName,
    this.companyRole,
    this.companyRegNumber,
    required this.createdAt,
  });

  bool get isVerified => kycStatus == KycStatus.verified;
  bool get isBusiness => accountType == AccountType.business;
  bool get isPersonal => accountType == AccountType.personal;

  UserProfile copyWith({
    String? userId,
    String? fullName,
    String? email,
    AccountType? accountType,
    String? country,
    String? phone,
    KycStatus? kycStatus,
    String? nationalId,
    String? nationalIdType,
    String? companyName,
    String? companyRole,
    String? companyRegNumber,
    DateTime? createdAt,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      accountType: accountType ?? this.accountType,
      country: country ?? this.country,
      phone: phone ?? this.phone,
      kycStatus: kycStatus ?? this.kycStatus,
      nationalId: nationalId ?? this.nationalId,
      nationalIdType: nationalIdType ?? this.nationalIdType,
      companyName: companyName ?? this.companyName,
      companyRole: companyRole ?? this.companyRole,
      companyRegNumber: companyRegNumber ?? this.companyRegNumber,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'fullName': fullName,
        'email': email,
        'accountType': accountType.name,
        'country': country,
        'phone': phone,
        'kycStatus': kycStatus.name,
        if (nationalId != null) 'nationalId': nationalId,
        if (nationalIdType != null) 'nationalIdType': nationalIdType,
        if (companyName != null) 'companyName': companyName,
        if (companyRole != null) 'companyRole': companyRole,
        if (companyRegNumber != null) 'companyRegNumber': companyRegNumber,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['userId'] as String? ?? 'usr_flowpay_${DateTime.now().millisecondsSinceEpoch}',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      accountType: (json['accountType'] == 'business') ? AccountType.business : AccountType.personal,
      country: json['country'] as String? ?? 'NG',
      phone: json['phone'] as String? ?? '',
      kycStatus: switch (json['kycStatus']) {
        'verified' => KycStatus.verified,
        'pending' => KycStatus.pending,
        _ => KycStatus.unverified,
      },
      nationalId: json['nationalId'] as String?,
      nationalIdType: json['nationalIdType'] as String?,
      companyName: json['companyName'] as String?,
      companyRole: json['companyRole'] as String?,
      companyRegNumber: json['companyRegNumber'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory UserProfile.fromJsonString(String source) =>
      UserProfile.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
