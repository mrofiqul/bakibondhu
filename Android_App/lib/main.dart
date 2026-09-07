import 'package:flutter/material.dart';

import 'package:bakibondhu/app.dart';
import 'package:bakibondhu/data/local_database.dart';
import 'package:bakibondhu/data/sqflite_ledger_repository.dart';

/// Entry point. Opens the local SQLite store (offline-first) and starts the app
/// with a sqflite-backed repository.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await openLocalDatabase();
  final repo = SqfliteLedgerRepository(db);
  runApp(BakiBondhuApp(repo: repo));
}
