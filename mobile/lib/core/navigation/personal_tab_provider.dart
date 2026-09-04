import 'package:flutter_riverpod/legacy.dart';

/// Indices for destinations in [PersonalShell]
class PersonalTab {
  static const int overview = 0;
  static const int wallets = 1;
  static const int missions = 2;
  static const int activity = 3;
  static const int security = 4;
}

/// Global Riverpod provider for the active tab index in Personal account mode.
final personalTabIndexProvider = StateProvider<int>((ref) => PersonalTab.overview);
