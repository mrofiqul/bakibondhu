import 'package:flutter/material.dart';

import 'package:bakibondhu/core/app_scope.dart';
import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/core/theme.dart';
import 'package:bakibondhu/data/ledger_repository.dart';
import 'package:bakibondhu/data/settings_store.dart';
import 'package:bakibondhu/features/dashboard/home_screen.dart';
import 'package:bakibondhu/features/onboarding/onboarding_screen.dart';
import 'package:bakibondhu/sync/sync_engine.dart';
import 'package:bakibondhu/sync/sync_store.dart';

/// Root widget. Holds shared services (via [AppScope]) and opens on onboarding
/// for a first run, otherwise straight to Home (no signup wall).
class BakiBondhuApp extends StatelessWidget {
  final LedgerRepository repo;
  final SettingsStore settings;
  final SyncStore syncStore;
  final SyncEngine? syncEngine;
  final bool startOnboarding;

  const BakiBondhuApp({
    required this.repo,
    required this.settings,
    required this.syncStore,
    this.syncEngine,
    this.startOnboarding = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AppScope(
      repo: repo,
      settings: settings,
      syncStore: syncStore,
      syncEngine: syncEngine,
      child: MaterialApp(
        title: S.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: startOnboarding ? const OnboardingScreen() : const HomeScreen(),
      ),
    );
  }
}
