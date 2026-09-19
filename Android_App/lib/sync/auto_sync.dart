import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import 'package:bakibondhu/core/connectivity_status.dart';
import 'package:bakibondhu/data/session.dart';
import 'package:bakibondhu/sync/sync_engine.dart';
import 'package:bakibondhu/sync/sync_store.dart';

/// Automatically syncs the ledger to the server whenever it can — so the
/// merchant never has to tap "Sync now". It fires:
///   * on startup,
///   * when the device comes back online (connectivity change),
///   * when the app is resumed to the foreground,
///   * and on a light poll that pushes any pending local changes.
///
/// All triggers are no-ops unless the user is logged in and actually online,
/// are guarded against overlap, and swallow errors (offline-first: a failed
/// attempt just retries on the next trigger).
class AutoSync with WidgetsBindingObserver {
  final SyncEngine engine;
  final Session session;
  final SyncStore store;

  final Connectivity _conn = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _poll;
  bool _busy = false;
  bool _wasOnline = true;

  AutoSync({required this.engine, required this.session, required this.store});

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _sub = _conn.onConnectivityChanged.listen((results) {
      final online = _isOnline(results);
      appOnline.value = online; // drive the UI's offline banner
      // Only act on the offline -> online edge, so we don't re-sync on every
      // Wi-Fi/mobile flip while already connected.
      if (online && !_wasOnline) _fullSync();
      _wasOnline = online;
    });
    // Seed the initial state (the stream only fires on change).
    _conn.checkConnectivity().then((r) {
      final online = _isOnline(r);
      appOnline.value = online;
      _wasOnline = online;
    });
    // Catches changes made while online (and retries) without hooking the repo.
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => _pushPending());
    _fullSync(); // initial attempt on launch
  }

  void dispose() {
    _poll?.cancel();
    _sub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _fullSync();
  }

  bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  bool get _loggedIn => (session.token ?? '').isNotEmpty;

  Future<bool> _online() async => _isOnline(await _conn.checkConnectivity());

  /// Full push + pull. Used on startup / resume / reconnect.
  Future<void> _fullSync() async {
    if (_busy || !_loggedIn) return;
    if (!await _online()) return;
    _busy = true;
    try {
      await engine.syncNow();
    } catch (_) {
      // offline-first — ignore; a later trigger retries.
    } finally {
      _busy = false;
    }
  }

  /// Sync only when there is something waiting to upload (cheap when idle).
  Future<void> _pushPending() async {
    if (_busy || !_loggedIn) return;
    final pending = await store.pendingChanges();
    if (pending.isEmpty) return;
    if (!await _online()) return;
    _busy = true;
    try {
      await engine.syncNow();
    } catch (_) {
      // ignore — retries next poll.
    } finally {
      _busy = false;
    }
  }
}
