import 'package:flutter/material.dart';

import 'package:bakibondhu/core/app_scope.dart';
import 'package:bakibondhu/core/dialogs.dart';
import 'package:bakibondhu/core/format.dart';
import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/core/theme.dart';
import 'package:bakibondhu/data/ledger_repository.dart';
import 'package:bakibondhu/domain/money.dart';
import 'package:bakibondhu/features/customers/customer_detail_screen.dart';
import 'package:bakibondhu/features/sync/sync_center_screen.dart';

/// Screen 1 — Home ("money out there"): one big total, customers sorted by who
/// owes most, and a button to add a customer (spec §8.2, Android UI/UX §5.4).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeData {
  final Money total;
  final List<CustomerBalance> customers;
  const _HomeData(this.total, this.customers);
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> _future;

  LedgerRepository get _repo => AppScope.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final repo = AppScope.of(context);
    final customers = await repo.customersWithBalances();
    final total = await repo.totalReceivable();
    return _HomeData(total, customers);
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _addCustomer() async {
    final input = await showAddCustomerDialog(context);
    if (input == null) return;
    await _repo.addCustomer(name: input.name, phone: input.phone);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(S.appName),
        actions: [
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
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCustomer,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text(S.newCustomer),
      ),
      body: FutureBuilder<_HomeData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!;
          if (data.customers.isEmpty) return const _EmptyState();
          return Column(
            children: [
              _TotalCard(total: data.total, count: data.customers.length),
              Expanded(
                child: ListView.separated(
                  itemCount: data.customers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final row = data.customers[i];
                    return _CustomerTile(
                      row: row,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CustomerDetailScreen(customerId: row.customer.id),
                          ),
                        );
                        _refresh(); // balance may have changed
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
