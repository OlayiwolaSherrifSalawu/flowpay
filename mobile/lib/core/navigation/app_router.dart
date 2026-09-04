import 'package:flutter/material.dart';
import '../state/app_state.dart';
import 'business_routes.dart';
import 'personal_routes.dart';

class FlowPayRouter {
  static Route<dynamic> onGenerateRoute(
      RouteSettings settings, AppState appState) {
    // Try personal routes
    final personalRoute = PersonalRoutes.onGenerateRoute(settings, appState);
    if (personalRoute != null) return personalRoute;

    // Try business routes
    final businessRoute = BusinessRoutes.onGenerateRoute(settings, appState);
    if (businessRoute != null) return businessRoute;

    // Default fallback
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        body: Center(
          child: Text('No route defined for ${settings.name}'),
        ),
      ),
    );
  }

  static void navigateTo(BuildContext context, String routeName,
      {Object? arguments}) {
    Navigator.pushNamed(context, routeName, arguments: arguments);
  }

  static void replaceWith(BuildContext context, String routeName,
      {Object? arguments}) {
    Navigator.pushReplacementNamed(context, routeName, arguments: arguments);
  }
}
