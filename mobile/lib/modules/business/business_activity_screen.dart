import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';
import '../../core/models/paginated_result.dart';
import '../../core/models/shared_transaction.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/state/app_state.dart';
import 'components/transaction_detail_sheet.dart';

/// Corporate Audit Log Screen
/// FlowPay Business Design System (Dribbble Fintech & Emerald Branding):
/// - Theme-adaptive Paper / Obsidian canvas
/// - Cryptographic ledger telemetry pill bar (Audited Events, Active Rails, Consensus Anchor)
/// - Pillowed search bar & interactive category filter chips
/// - Elevated 24dp audit event cards with squircle category icons & copyable reference hashes
/// - Tap opens TransactionDetailSheet with full sanitized audit data
class BusinessActivityScreen extends StatefulWidget {
  final AppState appState;

  const BusinessActivityScreen({super.key, required this.appState});

  @override
  State<BusinessActivityScreen> createState() => _BusinessActivityScreenState();
}

class _BusinessActivityScreenState extends State<BusinessActivityScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  int _currentPage = 1;
  static const int _pageSize = 10;
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _businessActivities = [
    {
      'id': 'aud_001',
      'title': 'Payroll Sent',
      'desc': r'Disbursed \$38,500 USD to 18 remote engineers across Nigeria and Mexico',
      'time': 'Today, 10:45 AM',
      'category': 'Payroll',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('38500.00', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-001',
      'rail': 'International ACH',
      'icon': Icons.payments_rounded,
      'iconColor': FlowPayColors.primary,
    },
    {
      'id': 'aud_002',
      'title': 'Employee Onboarding KYC Verified',
      'desc': 'Samson Jabo was verified for Mexico payments via BMONI identity',
      'time': 'Today, 9:20 AM',
      'category': 'Onboarding',
      'status': FlowPayAppStatus.success,
      'amount': Money.fromMajorString('0.00', Currency.mxn),
      'country': 'MX',
      'ref': 'REF-2024-002',
      'rail': 'BMONI IDV',
      'icon': Icons.how_to_reg_rounded,
      'iconColor': FlowPayColors.accent,
    },
    {
      'id': 'aud_003',
      'title': 'Virtual Card Issued',
      'desc': 'Issued virtual NGN spend card for Bunch Dillon (Lead Eng)',
      'time': 'Yesterday, 4:15 PM',
      'category': 'Cards',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('0.00', Currency.ngn),
      'country': 'NG',
      'ref': 'REF-2024-003',
      'rail': 'Virtual Mastercard',
      'icon': Icons.credit_card_rounded,
      'iconColor': FlowPayColors.amber,
    },
    {
      'id': 'aud_004',
      'title': 'AWS Infrastructure Subscription',
      'desc': 'Card •••• 8814 billed for production Kubernetes clusters',
      'time': 'Yesterday, 1:00 PM',
      'category': 'Cards',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('1240.50', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-004',
      'rail': 'Virtual Mastercard',
      'icon': Icons.cloud_done_rounded,
      'iconColor': FlowPayColors.primary,
    },
    {
      'id': 'aud_005',
      'title': 'Treasury Auto-Sweep Executed',
      'desc': r'Automated FX sweep: $10,000 USDB converted to ₦15,500,000 CNGN',
      'time': 'Yesterday, 8:00 AM',
      'category': 'Treasury',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('10000.00', Currency.usd),
      'country': 'NG',
      'ref': 'REF-2024-005',
      'rail': 'Polygon / USDB',
      'icon': Icons.currency_exchange_rounded,
      'iconColor': FlowPayColors.accent,
    },
    {
      'id': 'aud_006',
      'title': 'Quarterly Tax Compliance Report',
      'desc': 'Automated 1099-NEC tax ledger exported for remote contractors',
      'time': '2 days ago',
      'category': 'Compliance',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('0.00', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-006',
      'rail': 'Audited Ledger',
      'icon': Icons.verified_user_rounded,
      'iconColor': FlowPayColors.info,
    },
    {
      'id': 'aud_007',
      'title': 'Contractor Wire Payout (Nigeria)',
      'desc': 'Sent ₦2,750,000 to Chioma Eze via NIP Instant Rail',
      'time': '2 days ago',
      'category': 'Payroll',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('1774.19', Currency.usd),
      'country': 'NG',
      'ref': 'REF-2024-007',
      'rail': 'NIP Instant',
      'icon': Icons.account_balance_rounded,
      'iconColor': FlowPayColors.primary,
    },
    {
      'id': 'aud_008',
      'title': 'GitHub Enterprise Renewal',
      'desc': 'Annual dev organization license processed on Card •••• 4289',
      'time': '3 days ago',
      'category': 'Cards',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('2520.00', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-008',
      'rail': 'Virtual Mastercard',
      'icon': Icons.credit_card_rounded,
      'iconColor': FlowPayColors.amber,
    },
    {
      'id': 'aud_009',
      'title': 'Contractor Wire Payout (Mexico)',
      'desc': r'Disbursed $42,000 MXN to Carlos Mendoza via SPEI real-time rail',
      'time': '3 days ago',
      'category': 'Payroll',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('2470.58', Currency.usd),
      'country': 'MX',
      'ref': 'REF-2024-009',
      'rail': 'SPEI Real-Time',
      'icon': Icons.payments_rounded,
      'iconColor': FlowPayColors.primary,
    },
    {
      'id': 'aud_010',
      'title': 'Card Authorization Declined',
      'desc': r'Card •••• 8814: Travel booking declined (over monthly $500 travel cap)',
      'time': '4 days ago',
      'category': 'Cards',
      'status': FlowPayAppStatus.failed,
      'amount': Money.fromMajorString('620.00', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-010',
      'rail': 'Virtual Mastercard',
      'icon': Icons.error_outline_rounded,
      'iconColor': FlowPayColors.error,
    },
    {
      'id': 'aud_011',
      'title': 'Employee Onboarding Verified',
      'desc': 'Amina Bello (Lagos) completed BVN biometric verification',
      'time': '4 days ago',
      'category': 'Onboarding',
      'status': FlowPayAppStatus.success,
      'amount': Money.fromMajorString('0.00', Currency.ngn),
      'country': 'NG',
      'ref': 'REF-2024-011',
      'rail': 'BMONI IDV',
      'icon': Icons.how_to_reg_rounded,
      'iconColor': FlowPayColors.accent,
    },
    {
      'id': 'aud_012',
      'title': 'Figma Organization Seats',
      'desc': 'Card •••• 4289 billed for 5 UI/UX design workspace licenses',
      'time': '5 days ago',
      'category': 'Cards',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('225.00', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-012',
      'rail': 'Virtual Mastercard',
      'icon': Icons.credit_card_rounded,
      'iconColor': FlowPayColors.amber,
    },
    {
      'id': 'aud_013',
      'title': 'Treasury Top-Up via Circle Wire',
      'desc': r'Corporate deposit of $50,000 USDB confirmed on Polygon ledger',
      'time': '5 days ago',
      'category': 'Treasury',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('50000.00', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-013',
      'rail': 'Polygon / USDB',
      'icon': Icons.account_balance_wallet_rounded,
      'iconColor': FlowPayColors.primary,
    },
    {
      'id': 'aud_014',
      'title': 'OpenAI Enterprise API Usage',
      'desc': 'Monthly developer billing for FlowPay Copilot model endpoints',
      'time': '6 days ago',
      'category': 'Cards',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('890.40', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-014',
      'rail': 'Virtual Mastercard',
      'icon': Icons.smart_toy_rounded,
      'iconColor': FlowPayColors.accent,
    },
    {
      'id': 'aud_015',
      'title': 'KYC Sanctions & AML Screening',
      'desc': 'Batch compliance audit passed for 47 active global employees',
      'time': '1 week ago',
      'category': 'Compliance',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('0.00', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-015',
      'rail': 'Audited Ledger',
      'icon': Icons.verified_user_rounded,
      'iconColor': FlowPayColors.info,
    },
    {
      'id': 'aud_016',
      'title': 'Slack Business+ Subscription',
      'desc': 'Card •••• 8814 billed for global remote team communication',
      'time': '1 week ago',
      'category': 'Cards',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('375.00', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-016',
      'rail': 'Virtual Mastercard',
      'icon': Icons.credit_card_rounded,
      'iconColor': FlowPayColors.amber,
    },
    {
      'id': 'aud_017',
      'title': 'Bonus Disbursement (Nigeria)',
      'desc': 'Disbursed quarterly performance bonus of ₦850,000 to Babatunde Raji',
      'time': '1 week ago',
      'category': 'Payroll',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('548.38', Currency.usd),
      'country': 'NG',
      'ref': 'REF-2024-017',
      'rail': 'NIP Instant',
      'icon': Icons.payments_rounded,
      'iconColor': FlowPayColors.primary,
    },
    {
      'id': 'aud_018',
      'title': 'Canadian Payroll Pilot Initialized',
      'desc': r'Disbursed $4,500 CAD to Liam Tremblay via Interac e-Transfer',
      'time': '1 week ago',
      'category': 'Payroll',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('3333.33', Currency.usd),
      'country': 'CA',
      'ref': 'REF-2024-018',
      'rail': 'Interac Rail',
      'icon': Icons.payments_rounded,
      'iconColor': FlowPayColors.primary,
    },
    {
      'id': 'aud_019',
      'title': 'Google Workspace Enterprise',
      'desc': 'Card •••• 4289 billed for corporate domains & cloud storage',
      'time': '8 days ago',
      'category': 'Cards',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('420.00', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-019',
      'rail': 'Virtual Mastercard',
      'icon': Icons.credit_card_rounded,
      'iconColor': FlowPayColors.amber,
    },
    {
      'id': 'aud_020',
      'title': 'Employee Onboarding Verified',
      'desc': 'Diego Fernandez (Guadalajara) completed CURP national ID check',
      'time': '8 days ago',
      'category': 'Onboarding',
      'status': FlowPayAppStatus.success,
      'amount': Money.fromMajorString('0.00', Currency.mxn),
      'country': 'MX',
      'ref': 'REF-2024-020',
      'rail': 'BMONI IDV',
      'icon': Icons.how_to_reg_rounded,
      'iconColor': FlowPayColors.accent,
    },
    {
      'id': 'aud_021',
      'title': 'Treasury Auto-Sweep Executed',
      'desc': r'Automated FX sweep: $8,000 USDB converted to $136,000 MXN @ 17.00',
      'time': '9 days ago',
      'category': 'Treasury',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('8000.00', Currency.usd),
      'country': 'MX',
      'ref': 'REF-2024-021',
      'rail': 'Polygon / USDB',
      'icon': Icons.currency_exchange_rounded,
      'iconColor': FlowPayColors.accent,
    },
    {
      'id': 'aud_022',
      'title': 'Datadog Observability Suite',
      'desc': 'Card •••• 8814 billed for production APM & telemetry logging',
      'time': '9 days ago',
      'category': 'Cards',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('480.00', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-022',
      'rail': 'Virtual Mastercard',
      'icon': Icons.cloud_done_rounded,
      'iconColor': FlowPayColors.primary,
    },
    {
      'id': 'aud_023',
      'title': 'Emergency Contractor Advance',
      'desc': 'Advance salary of ₦400,000 approved and sent to Kelechi Nnamdi',
      'time': '10 days ago',
      'category': 'Payroll',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('258.06', Currency.usd),
      'country': 'NG',
      'ref': 'REF-2024-023',
      'rail': 'NIP Instant',
      'icon': Icons.payments_rounded,
      'iconColor': FlowPayColors.primary,
    },
    {
      'id': 'aud_024',
      'title': 'Card Limit Updated',
      'desc': r'Increased monthly spend ceiling for Bunch Dillon from $1,500 to $3,000',
      'time': '10 days ago',
      'category': 'Cards',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('0.00', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-024',
      'rail': 'BMONI Card Core',
      'icon': Icons.tune_rounded,
      'iconColor': FlowPayColors.info,
    },
    {
      'id': 'aud_025',
      'title': 'SOC2 Security Audit Log Hash Anchor',
      'desc': 'Merkle root of corporate audit transactions committed to ledger',
      'time': '11 days ago',
      'category': 'Compliance',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('0.00', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-025',
      'rail': 'Audited Ledger',
      'icon': Icons.verified_user_rounded,
      'iconColor': FlowPayColors.info,
    },
    {
      'id': 'aud_026',
      'title': 'Mid-Month Payroll Run (Mexico)',
      'desc': r'Disbursed $185,000 MXN across 8 contractors in Mexico City',
      'time': '12 days ago',
      'category': 'Payroll',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('10882.35', Currency.usd),
      'country': 'MX',
      'ref': 'REF-2024-026',
      'rail': 'SPEI Real-Time',
      'icon': Icons.payments_rounded,
      'iconColor': FlowPayColors.primary,
    },
    {
      'id': 'aud_027',
      'title': 'Vercel Pro Enterprise Hosting',
      'desc': 'Card •••• 4289 billed for frontend edge deployment bandwidth',
      'time': '12 days ago',
      'category': 'Cards',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('160.00', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-027',
      'rail': 'Virtual Mastercard',
      'icon': Icons.credit_card_rounded,
      'iconColor': FlowPayColors.amber,
    },
    {
      'id': 'aud_028',
      'title': 'Employee Onboarding Verified',
      'desc': 'Ngozi Okonjo (Abuja) passed identity verification and bank confirmation',
      'time': '13 days ago',
      'category': 'Onboarding',
      'status': FlowPayAppStatus.success,
      'amount': Money.fromMajorString('0.00', Currency.ngn),
      'country': 'NG',
      'ref': 'REF-2024-028',
      'rail': 'BMONI IDV',
      'icon': Icons.how_to_reg_rounded,
      'iconColor': FlowPayColors.accent,
    },
    {
      'id': 'aud_029',
      'title': 'Zoom Video Communications',
      'desc': 'Card •••• 8814 billed for executive corporate webinar licenses',
      'time': '13 days ago',
      'category': 'Cards',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('180.00', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-029',
      'rail': 'Virtual Mastercard',
      'icon': Icons.credit_card_rounded,
      'iconColor': FlowPayColors.amber,
    },
    {
      'id': 'aud_030',
      'title': 'Contractor Wire Payout Failed (Retry Queued)',
      'desc': 'Beneficiary bank network rejected NIP packet; re-routed via alternative bank switch',
      'time': '2 weeks ago',
      'category': 'Payroll',
      'status': FlowPayAppStatus.failed,
      'amount': Money.fromMajorString('1200.00', Currency.usd),
      'country': 'NG',
      'ref': 'REF-2024-030',
      'rail': 'NIP Instant',
      'icon': Icons.error_outline_rounded,
      'iconColor': FlowPayColors.error,
    },
    {
      'id': 'aud_031',
      'title': 'Treasury Auto-Sweep Executed',
      'desc': r'Automated FX sweep: $15,000 USDB converted to ₦23,250,000 CNGN',
      'time': '2 weeks ago',
      'category': 'Treasury',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('15000.00', Currency.usd),
      'country': 'NG',
      'ref': 'REF-2024-031',
      'rail': 'Polygon / USDB',
      'icon': Icons.currency_exchange_rounded,
      'iconColor': FlowPayColors.accent,
    },
    {
      'id': 'aud_032',
      'title': 'Linear Software Subscription',
      'desc': 'Card •••• 4289 billed for engineering issue tracking & sprint planning',
      'time': '2 weeks ago',
      'category': 'Cards',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('120.00', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-032',
      'rail': 'Virtual Mastercard',
      'icon': Icons.credit_card_rounded,
      'iconColor': FlowPayColors.amber,
    },
    {
      'id': 'aud_033',
      'title': 'Bi-Weekly Global Payroll Executed',
      'desc': r'Disbursed $36,200 USD to 17 remote engineers in Nigeria & Mexico',
      'time': '2 weeks ago',
      'category': 'Payroll',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('36200.00', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-033',
      'rail': 'International ACH',
      'icon': Icons.payments_rounded,
      'iconColor': FlowPayColors.primary,
    },
    {
      'id': 'aud_034',
      'title': 'Employee Onboarding Verified',
      'desc': 'Sofia Ramirez (Monterrey) verified for SPEI direct disbursements',
      'time': '2 weeks ago',
      'category': 'Onboarding',
      'status': FlowPayAppStatus.success,
      'amount': Money.fromMajorString('0.00', Currency.mxn),
      'country': 'MX',
      'ref': 'REF-2024-034',
      'rail': 'BMONI IDV',
      'icon': Icons.how_to_reg_rounded,
      'iconColor': FlowPayColors.accent,
    },
    {
      'id': 'aud_035',
      'title': 'Notion Team Workspace',
      'desc': 'Card •••• 8814 billed for corporate wiki & engineering documentation',
      'time': '2 weeks ago',
      'category': 'Cards',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('150.00', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-035',
      'rail': 'Virtual Mastercard',
      'icon': Icons.credit_card_rounded,
      'iconColor': FlowPayColors.amber,
    },
    {
      'id': 'aud_036',
      'title': 'Entity Incorporation Tax Filing (Delaware)',
      'desc': 'Franchise tax compliance submitted through registered corporate agent',
      'time': '3 weeks ago',
      'category': 'Compliance',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('450.00', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-036',
      'rail': 'Audited Ledger',
      'icon': Icons.verified_user_rounded,
      'iconColor': FlowPayColors.info,
    },
    {
      'id': 'aud_037',
      'title': 'Contractor Hardware Stipend',
      'desc': 'Sent ₦950,000 setup reimbursement to Ifeanyi Okoro',
      'time': '3 weeks ago',
      'category': 'Payroll',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('612.90', Currency.usd),
      'country': 'NG',
      'ref': 'REF-2024-037',
      'rail': 'NIP Instant',
      'icon': Icons.payments_rounded,
      'iconColor': FlowPayColors.primary,
    },
    {
      'id': 'aud_038',
      'title': 'Supabase Enterprise Database',
      'desc': 'Card •••• 4289 billed for managed PostgreSQL replica instances',
      'time': '3 weeks ago',
      'category': 'Cards',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('299.00', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-038',
      'rail': 'Virtual Mastercard',
      'icon': Icons.cloud_done_rounded,
      'iconColor': FlowPayColors.primary,
    },
    {
      'id': 'aud_039',
      'title': 'Treasury Top-Up via ACH Wire',
      'desc': r'Corporate operating account wire deposit of $40,000 USD confirmed',
      'time': '3 weeks ago',
      'category': 'Treasury',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('40000.00', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-039',
      'rail': 'Polygon / USDB',
      'icon': Icons.account_balance_wallet_rounded,
      'iconColor': FlowPayColors.primary,
    },
    {
      'id': 'aud_040',
      'title': 'Employee Onboarding Verified',
      'desc': 'Emeka Obi (Enugu) completed Tier-2 identification requirements',
      'time': '3 weeks ago',
      'category': 'Onboarding',
      'status': FlowPayAppStatus.success,
      'amount': Money.fromMajorString('0.00', Currency.ngn),
      'country': 'NG',
      'ref': 'REF-2024-040',
      'rail': 'BMONI IDV',
      'icon': Icons.how_to_reg_rounded,
      'iconColor': FlowPayColors.accent,
    },
    {
      'id': 'aud_041',
      'title': 'Docker Hub Team Plan',
      'desc': 'Card •••• 8814 billed for private container registry images',
      'time': '4 weeks ago',
      'category': 'Cards',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('85.00', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-041',
      'rail': 'Virtual Mastercard',
      'icon': Icons.credit_card_rounded,
      'iconColor': FlowPayColors.amber,
    },
    {
      'id': 'aud_042',
      'title': 'Monthly End-of-Month Payroll Run',
      'desc': r'Disbursed $42,800 USD across 20 contractors and staff',
      'time': '4 weeks ago',
      'category': 'Payroll',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('42800.00', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-042',
      'rail': 'International ACH',
      'icon': Icons.payments_rounded,
      'iconColor': FlowPayColors.primary,
    },
    {
      'id': 'aud_043',
      'title': 'Card Spending Rule Enforced',
      'desc': r'Blocked $1,200 transaction on Card •••• 4289 (Gambling MCC prohibited)',
      'time': '4 weeks ago',
      'category': 'Cards',
      'status': FlowPayAppStatus.failed,
      'amount': Money.fromMajorString('1200.00', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-043',
      'rail': 'Virtual Mastercard',
      'icon': Icons.error_outline_rounded,
      'iconColor': FlowPayColors.error,
    },
    {
      'id': 'aud_044',
      'title': 'Treasury Auto-Sweep Executed',
      'desc': r'Automated FX sweep: $12,500 USDB converted to $212,500 MXN @ 17.00',
      'time': '4 weeks ago',
      'category': 'Treasury',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('12500.00', Currency.usd),
      'country': 'MX',
      'ref': 'REF-2024-044',
      'rail': 'Polygon / USDB',
      'icon': Icons.currency_exchange_rounded,
      'iconColor': FlowPayColors.accent,
    },
    {
      'id': 'aud_045',
      'title': 'Employee Onboarding Verified',
      'desc': 'Valentina Morales (Cancún) verified for remote consulting contract',
      'time': '1 month ago',
      'category': 'Onboarding',
      'status': FlowPayAppStatus.success,
      'amount': Money.fromMajorString('0.00', Currency.mxn),
      'country': 'MX',
      'ref': 'REF-2024-045',
      'rail': 'BMONI IDV',
      'icon': Icons.how_to_reg_rounded,
      'iconColor': FlowPayColors.accent,
    },
    {
      'id': 'aud_046',
      'title': 'Cloudflare Enterprise Edge Security',
      'desc': 'Card •••• 8814 billed for DDoS protection & edge DNS routing',
      'time': '1 month ago',
      'category': 'Cards',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('320.00', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-046',
      'rail': 'Virtual Mastercard',
      'icon': Icons.cloud_done_rounded,
      'iconColor': FlowPayColors.primary,
    },
    {
      'id': 'aud_047',
      'title': 'Mid-Month Payroll Run (Nigeria)',
      'desc': 'Disbursed ₦18,400,000 across 9 engineering contractors',
      'time': '1 month ago',
      'category': 'Payroll',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('11870.96', Currency.usd),
      'country': 'NG',
      'ref': 'REF-2024-047',
      'rail': 'NIP Instant',
      'icon': Icons.payments_rounded,
      'iconColor': FlowPayColors.primary,
    },
    {
      'id': 'aud_048',
      'title': 'Postman API Team Workspace',
      'desc': 'Card •••• 4289 billed for automated regression test collections',
      'time': '1 month ago',
      'category': 'Cards',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('96.00', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-048',
      'rail': 'Virtual Mastercard',
      'icon': Icons.credit_card_rounded,
      'iconColor': FlowPayColors.amber,
    },
    {
      'id': 'aud_049',
      'title': 'Annual AML Audit Compliance Certificate',
      'desc': 'External cryptographic AML compliance attestation verified',
      'time': '1 month ago',
      'category': 'Compliance',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('0.00', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-049',
      'rail': 'Audited Ledger',
      'icon': Icons.verified_user_rounded,
      'iconColor': FlowPayColors.info,
    },
    {
      'id': 'aud_050',
      'title': 'Genesis Corporate Ledger Creation',
      'desc': 'FlowPay corporate treasury vault deployed on BMONI protocol',
      'time': '1 month ago',
      'category': 'Treasury',
      'status': FlowPayAppStatus.completed,
      'amount': Money.fromMajorString('100000.00', Currency.usd),
      'country': 'US',
      'ref': 'REF-2024-050',
      'rail': 'BMONI Core',
      'icon': Icons.account_balance_wallet_rounded,
      'iconColor': FlowPayColors.primary,
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredActivities {
    return _businessActivities.where((item) {
      final title = (item['title'] as String).toLowerCase();
      final desc = (item['desc'] as String).toLowerCase();
      final ref = (item['ref'] as String).toLowerCase();
      final q = _searchQuery.toLowerCase();

      final matchesQuery = _searchQuery.isEmpty ||
          title.contains(q) ||
          desc.contains(q) ||
          ref.contains(q);

      if (!matchesQuery) return false;

      if (_selectedCategory == 'All') return true;
      return (item['category'] as String) == _selectedCategory;
    }).toList();
  }

  void _openDetailSheet(Map<String, dynamic> item) {
    final sharedTx = SharedTransactionModel(
      id: item['id'] as String,
      title: item['title'] as String,
      amount: item['amount'] as Money,
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      status: item['status'] == FlowPayAppStatus.completed ||
              item['status'] == FlowPayAppStatus.success
          ? TransactionStatus.completed
          : TransactionStatus.processing,
      type: item['category'] == 'Cards'
          ? TransactionType.cardTransaction
          : (item['category'] == 'Payroll'
              ? TransactionType.payrollRun
              : TransactionType.walletOperation),
      country: item['country'] as String?,
      flowpayReference: item['ref'] as String?,
      bmoniReference: '0x${(item['ref'] as String).hashCode.toRadixString(16).padLeft(64, '0')}',
      description: item['desc'] as String,
    );

    TransactionDetailSheet.show(context, sharedTx);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? FlowPayColors.darkBackground : FlowPayColors.paper;
    final surfaceColor = FlowPayColors.surfaceOf(context);
    final borderColor = FlowPayColors.borderOf(context);
    final textPrimaryColor =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final textSecondaryColor =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.textSecondary;
    final canPop = Navigator.canPop(context);

    final filtered = _filteredActivities;

    final content = ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 1. Corporate Audit Telemetry Header Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: FlowPayRadii.cardSmall,
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              _AuditHeaderStatPill(
                label: 'EVENTS',
                value: '${_businessActivities.length} items',
                icon: Icons.history_edu_rounded,
                iconColor: FlowPayColors.primary,
                isDark: isDark,
              ),
              Container(
                height: 32,
                width: 1,
                color: borderColor,
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
              _AuditHeaderStatPill(
                label: 'COUNTRIES',
                value: '2 (Nigeria, Mexico)',
                icon: Icons.public_rounded,
                iconColor: FlowPayColors.accent,
                isDark: isDark,
              ),
              Container(
                height: 32,
                width: 1,
                color: borderColor,
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
              _AuditHeaderStatPill(
                label: 'SECURITY',
                value: 'Secured',
                icon: Icons.lock_outline_rounded,
                iconColor: FlowPayColors.info,
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Pillowed Search Bar
        Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: FlowPayRadii.input,
            border: Border.all(color: borderColor),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() {
            _searchQuery = val.trim();
            _currentPage = 1;
          }),
            style: FlowPayTypography.body(color: textPrimaryColor),
            decoration: InputDecoration(
              hintText: 'Search activity...',
              hintStyle: FlowPayTypography.body(
                  color: textSecondaryColor.withValues(alpha: 0.6)),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: textSecondaryColor,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded,
                          size: 18, color: textSecondaryColor),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                        _searchQuery = '';
                        _currentPage = 1;
                      });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 3. Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _AuditFilterChip(
                label: 'All (${_businessActivities.length})',
                isSelected: _selectedCategory == 'All',
                onTap: () => setState(() {
                  _selectedCategory = 'All';
                  _currentPage = 1;
                }),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _AuditFilterChip(
                label: 'Payroll',
                isSelected: _selectedCategory == 'Payroll',
                onTap: () => setState(() {
                  _selectedCategory = 'Payroll';
                  _currentPage = 1;
                }),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _AuditFilterChip(
                label: 'Cards',
                isSelected: _selectedCategory == 'Cards',
                onTap: () => setState(() {
                  _selectedCategory = 'Cards';
                  _currentPage = 1;
                }),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _AuditFilterChip(
                label: 'Treasury',
                isSelected: _selectedCategory == 'Treasury',
                onTap: () => setState(() {
                  _selectedCategory = 'Treasury';
                  _currentPage = 1;
                }),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _AuditFilterChip(
                label: 'Onboarding',
                isSelected: _selectedCategory == 'Onboarding',
                onTap: () => setState(() {
                  _selectedCategory = 'Onboarding';
                  _currentPage = 1;
                }),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _AuditFilterChip(
                label: 'Compliance',
                isSelected: _selectedCategory == 'Compliance',
                onTap: () => setState(() {
                  _selectedCategory = 'Compliance';
                  _currentPage = 1;
                }),
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Audit Event List
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.find_in_page_outlined,
                    size: 40,
                    color: textSecondaryColor.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text(
                  'No matching activity found',
                  style: FlowPayTypography.body(color: textSecondaryColor),
                ),
              ],
            ),
          )
        else ...[
          ...PaginatedResult.paginateList(
            filtered,
            page: _currentPage,
            limit: _pageSize,
          ).items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: FlowPayRadii.card,
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openDetailSheet(item),
                    borderRadius: FlowPayRadii.card,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Squircle Category Icon Container
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: (item['iconColor'] as Color)
                                      .withValues(alpha: isDark ? 0.18 : 0.12),
                                  borderRadius: FlowPayRadii.avatar,
                                  border: Border.all(
                                    color: (item['iconColor'] as Color)
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  item['icon'] as IconData,
                                  color: item['iconColor'] as Color,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['title'] as String,
                                      style: FlowPayTypography.body(
                                              color: textPrimaryColor)
                                          .copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item['desc'] as String,
                                      style: FlowPayTypography.captionStyle(
                                          color: textSecondaryColor),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  FlowPayStatusBadge(
                                    appStatus:
                                        item['status'] as FlowPayAppStatus,
                                    showDot: true,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['time'] as String,
                                    style: FlowPayTypography.captionStyle(
                                      color: textSecondaryColor,
                                    ).copyWith(fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Divider(color: borderColor, height: 1),
                          const SizedBox(height: 10),

                          // Reference Hash Pill Row with Copy
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? FlowPayColors.darkSurfaceElevated
                                          .withValues(alpha: 0.5)
                                      : FlowPayColors.mint100
                                          .withValues(alpha: 0.4),
                                  borderRadius: FlowPayRadii.chip,
                                  border: Border.all(
                                    color: borderColor.withValues(alpha: 0.7),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.fingerprint_rounded,
                                        size: 12,
                                        color: FlowPayColors.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      item['ref'] as String,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                item['rail'] as String,
                                style: FlowPayTypography.captionStyle(
                                        color: textSecondaryColor)
                                    .copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_ios_rounded,
                                  size: 10, color: FlowPayColors.primary),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (filtered.length > _pageSize) ...[
            const SizedBox(height: 8),
            FlowPayPaginationBar(
              currentPage: _currentPage,
              totalPages: (filtered.length / _pageSize).ceil(),
              totalItems: filtered.length,
              pageSize: _pageSize,
              itemLabel: 'events',
              onPageChanged: (newPage) {
                setState(() => _currentPage = newPage);
              },
            ),
            const SizedBox(height: 16),
          ],
        ],
      ],
    );

    if (canPop) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            'Business Activity',
            style: FlowPayTypography.title(color: textPrimaryColor).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
        ),
        body: content,
      );
    }

    return Container(
      color: backgroundColor,
      child: content,
    );
  }
}

class _AuditHeaderStatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final bool isDark;

  const _AuditHeaderStatPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final textSecondary =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.textSecondary;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: iconColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: FlowPayTypography.captionStyle(color: textSecondary).copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: FlowPayTypography.body(color: textPrimary).copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _AuditFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _AuditFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final selectedBg =
        isDark ? FlowPayColors.primary.withValues(alpha: 0.22) : FlowPayColors.mint100;
    final unselectedBg = FlowPayColors.surfaceOf(context);
    const selectedBorder = FlowPayColors.primary;
    final unselectedBorder = FlowPayColors.borderOf(context);
    final selectedText =
        isDark ? FlowPayColors.accent : FlowPayColors.primary;
    final unselectedText =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: FlowPayRadii.chip,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : unselectedBg,
            borderRadius: FlowPayRadii.chip,
            border: Border.all(
              color: isSelected ? selectedBorder : unselectedBorder,
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? selectedText : unselectedText,
            ),
          ),
        ),
      ),
    );
  }
}
