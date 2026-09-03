import 'package:flutter/material.dart';

/// FlowPay Corner Radii (Locked Tokens)
/// Derived strictly from .agents/skills/flowpay-core/design.md §3.4
class FlowPayRadii {
  /// Button (primary / secondary / tertiary) — universal pill
  static const button = BorderRadius.all(Radius.circular(9999));
  static const double buttonValue = 9999.0;

  /// Card — wallet cards, transaction group cards, card-object
  static const card = BorderRadius.all(Radius.circular(20));
  static const double cardValue = 20.0;

  /// Sheet / modal — bottom sheets, dialogs (top corners only)
  static const sheet = BorderRadius.vertical(top: Radius.circular(24));
  static const double sheetValue = 24.0;

  /// Input / text field
  static const input = BorderRadius.all(Radius.circular(12));
  static const double inputValue = 12.0;

  /// Chip / tag — currency chips, filter chips, status pills
  static const chip = BorderRadius.all(Radius.circular(9999));
  static const double chipValue = 9999.0;

  /// Avatar / logo tile — bank logos, merchant tiles
  static const avatar = BorderRadius.all(Radius.circular(12));
  static const double avatarValue = 12.0;
}
