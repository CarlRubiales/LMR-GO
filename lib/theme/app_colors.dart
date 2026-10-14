import 'package:flutter/material.dart';

/// Centralized Lumora color palette and semantic mappings.
abstract final class AppColors {
  // Lumora core palette
  static const plum = Color(0xFF3D1B3D); // primary: app bars, main buttons, headings, active states
  static const plumLight = Color(0xFF5A2E5A); // pressed/hover states
  static const orange = Color(0xFFE2703A); // accent: badges, labels, highlights
  static const rose = Color(0xFFB96562); // secondary accent, focused input border
  static const gold = Color(0xFFC9972B); // small premium accents
  static const cream = Color(0xFFFFFDFB); // scaffold and card background
  static const blush1 = Color(0xFFFBEFEA); // soft backgrounds and chips
  static const blush2 = Color(0xFFF3D8DE); // soft backgrounds and chips
  static const ink = Color(0xFF3A2E30); // body text
  static const muted = Color(0xFF8A7B7E); // secondary text
  static const line = Color(0xFFEBDDD8); // borders and dividers

  // Status colors (readable, never plum or orange)
  static const delivered = Color(0xFF2E7D32); // green
  static const pending = Color(0xFFD97706); // amber
  static const failed = Color(0xFFC62828); // red
  static const cancelled = Color(0xFFC62828); // red
  static const inTransit = Color(0xFF1976D2); // blue

  // Soft status surfaces
  static const deliveredSoft = Color(0xFFEEF5EB);
  static const pendingSoft = Color(0xFFFEF3C7);
  static const failedSoft = Color(0xFFFFF0ED);
  static const inTransitSoft = Color(0xFFEFF6FF);

  // Lumora Login & Auth specifications
  static const loginBackground = Color(0xFFFFFAF6);
  static const formBorder = Color(0xFFE8D8D0);
  static const inputBorder = Color(0xFFE8D8D0);
  static const inputFill = Color(0xFFFFFAF7);
  static const inputHint = Color(0xFFB2A4A1);
  static const inputIcon = Color(0xFFAA9898);
  static const dividerLine = Color(0xFFDEC8BC);
  static const errorBoxBg = Color(0xFFFFF0ED);
  static const errorBoxText = Color(0xFF9C3D38);
  static const errorBoxBorder = Color(0xFFF0CFC8);
  static const successBoxBg = Color(0xFFEEF5EB);
  static const successBoxText = Color(0xFF56704E);
  static const successBoxBorder = Color(0xFFD4E4CF);

  // Backward compatibility aliases for existing codebase
  static const primary = plum;
  static const primaryPressed = plumLight;
  static const accent = orange;
  static const accentDark = Color(0xFFC25B28);
  static const background = cream;
  static const softBackground = blush1;
  static const surface = cream;
  static const border = line;
  static const lightBorder = line;
  static const selected = blush2;
  static const textPrimary = ink;
  static const textSecondary = muted;
  static const placeholder = inputHint;
  static const success = delivered;
  static const successSoft = deliveredSoft;
  static const warning = pending;
  static const warningSoft = pendingSoft;
  static const error = failed;
  static const errorSoft = failedSoft;
  static const terracotta = orange;
  static const terracottaDark = Color(0xFFC25B28);
  static const blush = blush1;
  static const white = Color(0xFFFFFFFF);
  static const charcoalPlum = plum;
}

