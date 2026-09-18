import 'package:flutter/material.dart';

import 'package:bakibondhu/core/app_scope.dart';
import 'package:bakibondhu/core/dialogs.dart';
import 'package:bakibondhu/core/format.dart';
import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/core/theme.dart';
import 'package:bakibondhu/data/ledger_repository.dart';
import 'package:bakibondhu/domain/money.dart';
import 'package:bakibondhu/features/customers/customer_detail_screen.dart';
import 'package:bakibondhu/features/customers/customer_report_export.dart';
import 'package:bakibondhu/features/reports/sales_report_screen.dart';
import 'package:bakibondhu/features/settings/settings_screen.dart';
import 'package:bakibondhu/features/sync/sync_center_screen.dart';

/// How the Home customer list is ordered.
enum CustomerSort { owed, name, recent }

extension CustomerSortLabel on CustomerSort {
  String get label => switch (this) {
        CustomerSort.owed => S.sortMostOwed,
        CustomerSort.name => S.sortByName,
        CustomerSort.recent => S.sortRecent,
      };
}

/// Screen 1 — Home ("money out there"): one big total, customers sorted by who
/// owes most, and a button to add a customer (spec §8.2, Android UI/UX §5.4).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeData {
  final Money total;
  final Money todaySales;
  final List<CustomerBalance> customers;
  const _HomeData(this.total, this.todaySales, this.customers);
}

class _HomeScreenState extends State<HomeScreen> {
  _HomeData? _data;
  String? _shopName;

  /// Days until the subscription ends (negative = already expired); null when
  /// there's no expiry (unlimited / offline / logged out) or it's dismissed.
  int? _expiryDaysLeft;

  /// Live search query for the customer list (matches name or mobile).
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  /// How the customer list is ordered.
  CustomerSort _sort = CustomerSort.owed;

  LedgerRepository get _repo => AppScope.of(context);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Customers matching the current search (name or mobile, case-insensitive).
  List<CustomerBalance> _filtered(List<CustomerBalance> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((r) {
      final name = r.customer.name.toLowerCase();
      final phone = (r.customer.phone ?? '').toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();
  }

  /// A copy of [rows] ordered by the selected sort.
  List<CustomerBalance> _sorted(List<CustomerBalance> rows) {
    final out = [...rows];
    switch (_sort) {
      case CustomerSort.owed: // biggest owed first
        out.sort((a, b) => b.balance.compareTo(a.balance));
      case CustomerSort.name: // A–Z (Bangla + English)
        out.sort((a, b) =>
            a.customer.name.toLowerCase().compareTo(b.customer.name.toLowerCase()));
      case CustomerSort.recent: // newest first; unknown dates sink to the bottom
        out.sort((a, b) {
          final da = a.customer.createdAt, db = b.customer.createdAt;
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return db.compareTo(da);
        });
    }
    return out;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refresh();
  }

  /// Whether to show the trial-ending reminder, and how urgent. Shows within a
  /// week of expiry (and once expired), unless dismissed earlier today.
  Future<int?> _computeExpiryBanner() async {
    final expiresAt = AppScope.sessionOf(context).expiresAt;
    if (expiresAt == null || expiresAt.isEmpty) return null;
    final exp = DateTime.tryParse(expiresAt);
    if (exp == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = DateTime(exp.year, exp.month, exp.day).difference(today).inDays;
    if (days > 7) return null; // only remind within the final week
    final todayStr = today.toIso8601String().substring(0, 10);
    final dismissedOn =
        await AppScope.settingsOf(context).trialReminderDismissedOn();
    if (dismissedOn == todayStr) return null;
    return days;
  }

  Future<void> _dismissExpiryBanner() async {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    await AppScope.settingsOf(context).setTrialReminderDismissedOn(todayStr);
    if (!mounted) return;
    setState(() => _expiryDaysLeft = null);
  }

  /// Reloads customers + total from the repository and rebuilds. We store the
  /// result in state (rather than swapping a FutureBuilder's future) so a reload
  /// after add/edit reliably repaints — swapping the future left the old
  /// snapshot on screen.
  Future<void> _refresh() async {
    final repo = AppScope.of(context);
    final shopName = await AppScope.settingsOf(context).shopName();
    final customers = await repo.customersWithBalances();
    final total = await repo.totalReceivable();
    final todaySales = await repo.todaysSales();
    final expiryDays = await _computeExpiryBanner();
    if (!mounted) return;
    setState(() {
      _shopName = shopName;
      _data = _HomeData(total, todaySales, customers);
      _expiryDaysLeft = expiryDays;
    });
  }

  Future<void> _addCustomer() async {
    final input = await showAddCustomerDialog(
      context,
      phoneExists: (phone) async => (await _repo.customerByPhone(phone)) != null,
    );
    if (input == null) return;
    await _repo.addCustomer(
        name: input.name, phone: input.phone, address: input.address);
    await _refresh();
  }

  Future<void> _exportExcel() async {
    final rows = _data?.customers ?? const <CustomerBalance>[];
    final messenger = ScaffoldMessenger.of(context);
    if (rows.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text(S.exportNoCustomers)));
      return;
    }
    messenger.showSnackBar(const SnackBar(content: Text(S.exportPreparing)));
    try {
      await exportCustomerReport(rows: rows, shopName: _shopName ?? '');
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text(S.exportFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text((_shopName == null || _shopName!.trim().isEmpty)
            ? S.appName
            : '${S.appName} / ${_shopName!.trim()}'),
        actions: [
          PopupMenuButton<CustomerSort>(
            icon: const Icon(Icons.sort),
            tooltip: S.sortBy,
            initialValue: _sort,
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (_) => [
              for (final s in CustomerSort.values)
                CheckedPopupMenuItem(
                  value: s,
                  checked: s == _sort,
                  child: Text(s.label),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.grid_on),
            tooltip: S.exportExcelTooltip,
            onPressed: _exportExcel,
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: S.syncCenter,
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SyncCenterScreen()),
              );
              _refresh();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: S.settings,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCustomer,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text(S.newCustomer),
      ),
      body: Builder(
        builder: (context) {
          final data = _data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              if (_expiryDaysLeft != null)
                _TrialBanner(
                  daysLeft: _expiryDaysLeft!,
                  onDismiss: _dismissExpiryBanner,
                ),
              _TotalCard(total: data.total, count: data.customers.length),
              _SalesCard(
                todaySales: data.todaySales,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SalesReportScreen()),
                  );
                  _refresh();
                },
              ),
              if (data.customers.isNotEmpty)
                _SearchField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  onClear: () => setState(() {
                    _searchCtrl.clear();
                    _query = '';
                  }),
                ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (data.customers.isEmpty) return const _EmptyState();
                    final rows = _sorted(_filtered(data.customers));
                    if (rows.isEmpty) return _NoSearchResults(query: _query);
                    return ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final row = rows[i];
                        return _CustomerTile(
                          row: row,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CustomerDetailScreen(
                                    customerId: row.customer.id),
                              ),
                            );
                            _refresh(); // balance may have changed
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Home reminder that a shop's subscription is about to end (or has ended).
/// Amber while counting down, red once expired; dismissible for the day.
class _TrialBanner extends StatelessWidget {
  final int daysLeft;
  final VoidCallback onDismiss;
  const _TrialBanner({required this.daysLeft, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final expired = daysLeft < 0;
    final Color bg = expired ? const Color(0xFFFBE9E7) : const Color(0xFFFDF1DD);
    final Color fg = expired ? const Color(0xFFB3261E) : const Color(0xFF8A5A00);
    final message = expired ? S.trialExpired : S.trialEndsInDays(daysLeft);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(expired ? Icons.error_outline : Icons.access_time, color: fg, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(color: fg, fontWeight: FontWeight.w600, height: 1.35)),
          ),
          IconButton(
            icon: Icon(Icons.close, color: fg, size: 20),
            tooltip: S.trialDismiss,
            visualDensity: VisualDensity.compact,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

/// Search box that filters the customer list by name or mobile number.
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  const _SearchField(
      {required this.controller,
      required this.onChanged,
      required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: S.searchCustomers,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: S.cancel,
                  onPressed: onClear,
                ),
          isDense: true,
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _NoSearchResults extends StatelessWidget {
  final String query;
  const _NoSearchResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(S.noSearchResults(query),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final Money total;
  final int count;
  const _TotalCard({required this.total, required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.totalOwedLabel,
              style: TextStyle(color: scheme.onPrimaryContainer)),
          const SizedBox(height: 6),
          Text(total.format(),
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: scheme.onPrimaryContainer,
              )),
          const SizedBox(height: 2),
          Text(S.customerCount(count),
              style: TextStyle(color: scheme.onPrimaryContainer)),
        ],
      ),
    );
  }
}

class _SalesCard extends StatelessWidget {
  final Money todaySales;
  final VoidCallback onTap;
  const _SalesCard({required this.todaySales, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Material(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.trending_up, color: scheme.onSecondaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(S.todaysSales,
                          style: TextStyle(
                              color: scheme.onSecondaryContainer,
                              fontWeight: FontWeight.w600)),
                      Text(S.viewDailySales,
                          style: TextStyle(
                              color: scheme.onSecondaryContainer
                                  .withValues(alpha: 0.75),
                              fontSize: 12)),
                    ],
                  ),
                ),
                Text(todaySales.format(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSecondaryContainer,
                    )),
                Icon(Icons.chevron_right, color: scheme.onSecondaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final CustomerBalance row;
  final VoidCallback onTap;
  const _CustomerTile({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final owed = row.balance.isPositive;
    return ListTile(
      onTap: onTap,
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title: Text(row.customer.name,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: row.customer.phone == null ? null : Text(row.customer.phone!),
      trailing: Text(
        balanceLabel(row.balance),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: owed ? AppTheme.owed : Colors.grey,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(S.emptyTitle,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(S.emptyPrompt, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
