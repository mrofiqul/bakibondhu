import 'package:flutter/material.dart';

import 'package:bakibondhu/core/app_scope.dart';
import 'package:bakibondhu/core/connectivity_status.dart';
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
    // Build the theme ONCE and reuse the same instance across language-toggle
    // rebuilds — a fresh ThemeData each rebuild makes MaterialApp's AnimatedTheme
    // animate a non-change (~200ms), which makes switching language feel slow.
    final theme = AppTheme.light();
    final home = startLanding ? const LandingScreen() : const HomeScreen();
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
          theme: theme,
          home: home,
          // Show a top-bar offline notice on every screen when there's no network.
          builder: (context, child) =>
              _OfflineWrap(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}

/// Wraps every route with a persistent offline notice at the very top (above the
/// app bar) whenever the device has no connection. When online it's invisible.
class _OfflineWrap extends StatelessWidget {
  final Widget child;
  const _OfflineWrap({required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: appOnline,
      builder: (context, online, _) {
        if (online) return child;
        final mq = MediaQuery.of(context);
        return Column(
          children: [
            Material(
              color: const Color(0xFFFBEED6), // soft amber
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, mq.padding.top + 8, 14, 8),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off, size: 18, color: Color(0xFF8A5300)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        S.offlineBanner,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: Color(0xFF8A5300),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Remove the top inset the banner already consumed so the app bar
            // below doesn't double-count the status bar.
            Expanded(
              child: MediaQuery(
                data: mq.removePadding(removeTop: true),
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}
