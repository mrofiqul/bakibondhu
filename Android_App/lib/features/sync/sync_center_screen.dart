import 'package:flutter/material.dart';

import 'package:bakibondhu/core/app_scope.dart';
import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/sync/sync_store.dart';
import 'package:bakibondhu/sync/sync_types.dart';

/// Sync Center (spec §5.14): counts by state, a Sync Now action, and a
/// conflict-review list. Works read-only until a backend is configured
/// (syncEngine == null), so the merchant can always see what's pending.
class SyncCenterScreen extends StatefulWidget {
  const SyncCenterScreen({super.key});

  @override
  State<SyncCenterScreen> createState() => _SyncCenterScreenState();
}

class _SyncData {
  final SyncStatusCounts counts;
  final List<LocalChange> conflicts;
  const _SyncData(this.counts, this.conflicts);
}

class _SyncCenterScreenState extends State<SyncCenterScreen> {
  late Future<_SyncData> _future;
  bool _syncing = false;

  SyncStore get _store => AppScope.syncStoreOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = _load();
  }

  Future<_SyncData> _load() async =>
      _SyncData(await _store.status(), await _store.conflicts());

  void _refresh() => setState(() => _future = _load());

  Future<void> _syncNow() async {
    final engine = AppScope.syncEngineOf(context);
    if (engine == null) return;
    setState(() => _syncing = true);
    final report = await engine.syncNow();
    if (!mounted) return;
    setState(() => _syncing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(S.syncResult(report.pushed, report.pulled))),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final canSync = AppScope.syncEngineOf(context) != null;
    return Scaffold(
      appBar: AppBar(title: const Text(S.syncCenter)),
      body: FutureBuilder<_SyncData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!;
          final c = data.counts;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (c.unsynced == 0)
                _banner(context, Icons.cloud_done, S.allSynced,
                    Theme.of(context).colorScheme.primary)
              else
                _banner(context, Icons.cloud_upload,
                    '${c.unsynced} ${S.toUpload}', Colors.orange.shade800),
              const SizedBox(height: 12),
              _StatTile(label: S.synced, value: c.synced, icon: Icons.check_circle),
              _StatTile(label: S.toUpload, value: c.pending, icon: Icons.schedule),
              _StatTile(label: S.failedLabel, value: c.failed, icon: Icons.error_outline),
              _StatTile(
                  label: S.conflictsLabel, value: c.conflict, icon: Icons.merge_type),
              const SizedBox(height: 16),
              if (!canSync)
                Text(S.notConnected,
                    style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: (canSync && !_syncing) ? _syncNow : null,
                icon: _syncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sync),
                label: const Text(S.syncNow),
              ),
              if (data.conflicts.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(S.conflictsNeedReview,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(S.conflictReviewSoon,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                for (final ch in data.conflicts)
                  ListTile(
                    leading: const Icon(Icons.merge_type),
                    title: Text('${ch.kind.name} · ${ch.localId}'),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _banner(BuildContext context, IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: TextStyle(color: color, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  const _StatTile(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: Text('$value',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}
