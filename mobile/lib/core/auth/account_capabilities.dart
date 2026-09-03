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
