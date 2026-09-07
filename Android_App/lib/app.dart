import 'package:flutter/material.dart';

import 'package:bakibondhu/core/app_scope.dart';
import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/core/theme.dart';
import 'package:bakibondhu/data/ledger_repository.dart';
import 'package:bakibondhu/features/dashboard/home_screen.dart';

/// Root widget. Holds the repository (via [AppScope]) and opens on the Home
/// screen. No signup wall (spec §7 / FR-7): the app is usable immediately.
class BakiBondhuApp extends StatelessWidget {
  final LedgerRepository repo;

  const BakiBondhuApp({required this.repo, super.key});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      repo: repo,
      child: MaterialApp(
        title: S.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const HomeScreen(),
      ),
    );
  }
}
