import 'package:flutter/material.dart';
import '../../modules/business/business_activity_screen.dart';
import '../../modules/business/business_dashboard_screen.dart';
import '../../modules/business/employee_detail_screen.dart';
import '../../modules/business/employees_screen.dart';
import '../../modules/business/payroll_screen.dart';
import '../repositories/employee_repository.dart';
import '../state/app_state.dart';
import 'app_routes.dart';

class BusinessDestination {
  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const BusinessDestination({
    required this.route,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

class BusinessRoutes {
  static const List<BusinessDestination> destinations = [
    BusinessDestination(
      route: AppRoutes.businessDashboard,
      label: 'Overview',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
    ),
    BusinessDestination(
      route: AppRoutes.businessEmployees,
      label: 'Team',
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
    ),
    BusinessDestination(
      route: AppRoutes.businessPayroll,
      label: 'Payroll',
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments,
    ),
    BusinessDestination(
      route: AppRoutes.businessActivity,
      label: 'Audit',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
    ),
  ];

  static Widget buildScreen(int index, AppState appState) {
    switch (index) {
      case 0:
        return BusinessDashboardScreen(appState: appState);
      case 1:
        return EmployeesScreen(appState: appState);
      case 2:
        return PayrollScreen(appState: appState);
      case 3:
        return BusinessActivityScreen(appState: appState);
      default:
        return BusinessDashboardScreen(appState: appState);
    }
  }

  static Route<dynamic>? onGenerateRoute(RouteSettings settings, AppState appState) {
    switch (settings.name) {
      case AppRoutes.businessDashboard:
        return MaterialPageRoute(builder: (_) => BusinessDashboardScreen(appState: appState));
      case AppRoutes.businessEmployees:
        return MaterialPageRoute(builder: (_) => EmployeesScreen(appState: appState));
      case AppRoutes.businessPayroll:
        return MaterialPageRoute(builder: (_) => PayrollScreen(appState: appState));
      case AppRoutes.businessActivity:
        return MaterialPageRoute(builder: (_) => BusinessActivityScreen(appState: appState));
      case AppRoutes.businessEmployeeDetail:
        final employee = settings.arguments as EmployeeModel?;
        if (employee != null) {
          return MaterialPageRoute(
            builder: (_) => EmployeeDetailScreen(appState: appState, employee: employee),
          );
        }
        return null;
      default:
        return null;
    }
  }
}
