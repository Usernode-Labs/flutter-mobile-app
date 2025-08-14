import 'package:flutter/material.dart';

class AppConstants {
  // App Information
  static const String appName =
      'Usernode'; // 🔥 CHANGED: From 'CryptoMobile' to 'Usernode'
  static const String appTagline = 'Your Gateway to DeFi';
  static const String appVersion = '1.0.0';

  // Animation Durations
  static const Duration splashDuration = Duration(seconds: 1);
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 500);
  static const Duration longAnimation = Duration(seconds: 1);

  // Navigation - Updated to match screenshot
  static const List<NavigationItem> navigationItems = [
    NavigationItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
      index: 0,
    ),
    NavigationItem(
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet,
      label: 'Wallet',
      index: 1,
    ),
    NavigationItem(
      icon: Icons.hub_outlined,
      activeIcon: Icons.hub,
      label: 'Node',
      index: 2,
    ),
  ];

  // Sizes
  static const double splashIconSize = 80.0;
  static const double placeholderIconSize = 64.0;
  static const double borderRadius = 8.0;

  // Spacing
  static const EdgeInsets screenPadding = EdgeInsets.all(16.0);
  static const EdgeInsets navIconPadding = EdgeInsets.all(8.0);
}

class NavigationItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final int index;

  const NavigationItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.index,
  });
}
