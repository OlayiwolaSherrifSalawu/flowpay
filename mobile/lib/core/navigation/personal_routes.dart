import 'package:flutter/material.dart';
import '../../modules/personal/money_missions_screen.dart';
import '../../modules/personal/personal_activity_screen.dart';
import '../../modules/personal/personal_dashboard_screen.dart';
import '../../modules/personal/personal_security_screen.dart';
import '../../modules/personal/send_money_screen.dart';
import '../../modules/personal/wallets_screen.dart';
import '../state/app_state.dart';
import 'app_routes.dart';

class PersonalDestination {
  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const PersonalDestination({
    required this.route,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

class PersonalRoutes {
  static const List<PersonalDestination> destinations = [
    PersonalDestination(
      route: AppRoutes.personalDashboard,
      label: 'Overview',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    PersonalDestination(
      route: AppRoutes.personalWallets,
      label: 'Wallets',
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
    ),
    PersonalDestination(
      route: AppRoutes.personalMissions,
      label: 'Missions',
      icon: Icons.bolt_outlined,
      selectedIcon: Icons.bolt,
    ),
    PersonalDestination(
      route: AppRoutes.personalActivity,
      label: 'Activity',
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
    ),
    PersonalDestination(
      route: AppRoutes.personalSecurity,
      label: 'Security',
      icon: Icons.shield_outlined,
      selectedIcon: Icons.shield,
    ),
  ];

  static Widget buildScreen(int index, AppState appState) {
    switch (index) {
      case 0:
        return PersonalDashboardScreen(appState: appState);
      case 1:
        return WalletsScreen(appState: appState);
      case 2:
        return MoneyMissionsScreen(appState: appState);
      case 3:
        return PersonalActivityScreen(appState: appState);
      case 4:
        return PersonalSecurityScreen(appState: appState);
      default:
        return PersonalDashboardScreen(appState: appState);
    }
  }

  static Route<dynamic>? onGenerateRoute(
      RouteSettings settings, AppState appState) {
    switch (settings.name) {
      case AppRoutes.personalDashboard:
        return MaterialPageRoute(
            builder: (_) => PersonalDashboardScreen(appState: appState));
      case AppRoutes.personalWallets:
        return MaterialPageRoute(
            builder: (_) => WalletsScreen(appState: appState));
      case AppRoutes.personalSendMoney:
        return MaterialPageRoute(
            builder: (_) => SendMoneyScreen(appState: appState));
      case AppRoutes.personalMissions:
        return MaterialPageRoute(
            builder: (_) => MoneyMissionsScreen(appState: appState));
      case AppRoutes.personalActivity:
        return MaterialPageRoute(
            builder: (_) => PersonalActivityScreen(appState: appState));
      case AppRoutes.personalSecurity:
        return MaterialPageRoute(
            builder: (_) => PersonalSecurityScreen(appState: appState));
      default:
        return null;
    }
  }
}
