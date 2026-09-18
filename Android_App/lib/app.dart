import 'package:flutter/material.dart';

import 'package:bakibondhu/core/app_scope.dart';
import 'package:bakibondhu/core/language.dart';
import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/core/theme.dart';
import 'package:bakibondhu/data/auth_api.dart';
import 'package:bakibondhu/data/ledger_repository.dart';
import 'package:bakibondhu/data/session.dart';
import 'package:bakibondhu/data/settings_store.dart';
import 'package:bakibondhu/features/dashboard/home_screen.dart';
import 'package:bakibondhu/features/onboarding/landing_screen.dart';
import 'package:bakibondhu/sync/sync_engine.dart';
import 'package:bakibondhu/sync/sync_store.dart';

/// Root widget. Holds shared services (via [AppScope]) and opens on onboarding
/// for a first run, otherwise straight to Home (no signup wall).
class BakiBondhuApp extends StatelessWidget {
  final LedgerRepository repo;
  final SettingsStore settings;
  final SyncStore syncStore;
  final SyncEngine? syncEngine;
  final Session session;
  final AuthApi authApi;

  /// Show the landing (Login / Register / offline) screen on launch. False once
  /// the user has logged in or completed offline setup — then we open on Home.
  final bool startLanding;

  const BakiBondhuApp({
    required this.repo,
    required this.settings,
    required this.syncStore,
    required this.session,
    required this.authApi,
    this.syncEngine,
    this.startLanding = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AppScope(
      repo: repo,
      settings: settings,
      syncStore: syncStore,
      syncEngine: syncEngine,
      session: session,
      authApi: authApi,
      child: ValueListenableBuilder<AppLang>(
        valueListenable: appLanguage,
        builder: (context, _, __) => MaterialApp(
          title: S.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: startLanding ? const LandingScreen() : const HomeScreen(),
        ),
      ),
    );
  }
}
