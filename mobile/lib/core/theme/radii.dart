import 'package:flutter/material.dart';

/// FlowPay Corner Radii (Dribbble Reference Tokens)
/// Source: Smart Fintech App UI Design (Ofspace UX/UI) & FlowPay Design System
class FlowPayRadii {
  /// Button (primary / secondary / tertiary) — universal pill
  static const button = BorderRadius.all(Radius.circular(9999));
  static const double buttonValue = 9999.0;

  /// Card — pillowed rounded cards (24dp from Dribbble reference)
  static const card = BorderRadius.all(Radius.circular(24));
  static const double cardValue = 24.0;

  /// Card Large / Hero Card — 28dp for prominent hero cards & stacked decks
  static const cardLarge = BorderRadius.all(Radius.circular(28));
  static const double cardLargeValue = 28.0;

  /// Card Medium — 20dp
  static const cardMedium = BorderRadius.all(Radius.circular(20));
  static const double cardMediumValue = 20.0;

  /// Card Small — 16dp
  static const cardSmall = BorderRadius.all(Radius.circular(16));
  static const double cardSmallValue = 16.0;

  /// Sheet / modal — bottom sheets, dialogs (top corners only, 28dp)
  static const sheet = BorderRadius.vertical(top: Radius.circular(28));
  static const double sheetValue = 28.0;

  /// Input / text field — pillowed 16dp from Dribbble reference
  static const input = BorderRadius.all(Radius.circular(16));
  static const double inputValue = 16.0;

  /// Chip / tag — currency chips, filter chips, status pills
  static const chip = BorderRadius.all(Radius.circular(9999));
  static const double chipValue = 9999.0;

  /// Avatar / logo tile — bank logos, merchant tiles
  static const avatar = BorderRadius.all(Radius.circular(14));
  static const double avatarValue = 14.0;

  /// Squircle quick-action icon container — 18dp from Dribbble reference
  static const quickAction = BorderRadius.all(Radius.circular(18));
  static const double quickActionValue = 18.0;
}
