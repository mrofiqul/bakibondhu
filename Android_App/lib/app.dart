import 'package:flutter/material.dart';

import 'package:bakibondhu/core/app_scope.dart';
import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/core/theme.dart';
import 'package:bakibondhu/data/ledger_repository.dart';
import 'package:bakibondhu/data/settings_store.dart';
import 'package:bakibondhu/features/dashboard/home_screen.dart';
import 'package:bakibondhu/features/onboarding/onboarding_screen.dart';

/// Root widget. Holds the repository + settings (via [AppScope]) and opens on
/// onboarding for a first run, otherwise straight to Home (no signup wall).
class BakiBondhuApp extends StatelessWidget {
  final LedgerRepository repo;
  final SettingsStore settings;
  final bool startOnboarding;

  const BakiBondhuApp({
    required this.repo,
    required this.settings,
    this.startOnboarding = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AppScope(
      repo: repo,
      settings: settings,
      child: MaterialApp(
        title: S.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: startOnboarding ? const OnboardingScreen() : const HomeScreen(),
      ),
    );
  }
}
