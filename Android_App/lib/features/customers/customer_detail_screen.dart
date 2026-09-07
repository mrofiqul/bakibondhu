import 'package:flutter/material.dart';

import 'package:bakibondhu/core/app_scope.dart';
import 'package:bakibondhu/core/dialogs.dart';
import 'package:bakibondhu/core/format.dart';
import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/core/theme.dart';
import 'package:bakibondhu/data/ledger_repository.dart';
import 'package:bakibondhu/domain/models.dart';
import 'package:bakibondhu/domain/money.dart';

/// Screen 2 — Customer detail: balance on top, full history, and the three
/// actions বাকি দিলাম · টাকা পেলাম · মনে করান (spec §8.5, Android UI/UX §5.7).
class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  const CustomerDetailScreen({required this.customerId, super.key});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _DetailData {
  final Customer customer;
  final Money balance;
  final List<TxnEntry> history;
  const _DetailData(this.customer, this.balance, this.history);
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late Future<_DetailData> _future;

  LedgerRepository get _repo => AppScope.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = _load();
  }

  Future<_DetailData> _load() async {
    final repo = AppScope.of(context);
    final customer = await repo.customer(widget.customerId);
    final balance = await repo.balanceOf(widget.customerId);
    final history = await repo.transactionsOf(widget.customerId);
    return _DetailData(customer!, balance, history);
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _recordCredit() async {
    final input = await showAmountDialog(context, title: S.gaveCredit);
    if (input == null) return;
    await _repo.recordCredit(
        customerId: widget.customerId, amount: input.amount, note: input.note);
    _refresh();
  }

  Future<void> _recordPayment() async {
    final input = await showAmountDialog(context, title: S.gotPayment);
    if (input == null) return;
    await _repo.recordPayment(
        customerId: widget.customerId, amount: input.amount, note: input.note);
    _refresh();
  }

  void _remind() {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text(S.reminderSoon)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DetailData>(
      future: _future,
      builder: (context, snap) {
        final title = snap.hasData ? snap.data!.customer.name : '';
        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: switch (snap.connectionState) {
            ConnectionState.done => _body(snap.data!),
            _ => const Center(child: CircularProgressIndicator()),
          },
        );
      },
    );
  }

  Widget _body(_DetailData data) {
    return Column(
      children: [
        _BalanceHeader(customer: data.customer, balance: data.balance),
        _ActionsRow(
          onCredit: _recordCredit,
          onPayment: _recordPayment,
          onRemind: _remind,
        ),
        const Divider(height: 1),
        Expanded(
          child: data.history.isEmpty
              ? const Center(child: Text(S.noHistory))
              : ListView.separated(
                  itemCount: data.history.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _HistoryTile(entry: data.history[i]),
                ),
        ),
      ],
    );
  }
}

class _BalanceHeader extends StatelessWidget {
  final Customer customer;
  final Money balance;
  const _BalanceHeader({required this.customer, required this.balance});

  @override
  Widget build(BuildContext context) {
    final owed = balance.isPositive;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (customer.phone != null)
            Row(children: [
              const Icon(Icons.phone, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(customer.phone!, style: const TextStyle(color: Colors.grey)),
            ]),
          const SizedBox(height: 10),
          Text(S.currentDue, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            balanceLabel(balance),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: owed ? AppTheme.owed : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  final VoidCallback onCredit;
  final VoidCallback onPayment;
  final VoidCallback onRemind;
  const _ActionsRow(
      {required this.onCredit,
      required this.onPayment,
      required this.onRemind});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: onCredit,
              icon: const Icon(Icons.arrow_upward),
              label: const Text(S.gaveCredit),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: onPayment,
              icon: const Icon(Icons.arrow_downward),
              label: const Text(S.gotPayment),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: onRemind,
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: S.remind,
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final TxnEntry entry;
  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final increasing = entry.type.isIncreasing;
    final sign = increasing ? '+' : '−';
    final color = increasing ? AppTheme.owed : AppTheme.seed;
    final label = increasing ? S.gaveCredit : S.gotPayment;
    return ListTile(
      leading: Icon(
        increasing ? Icons.arrow_upward : Icons.arrow_downward,
        color: color,
      ),
      title: Text(label),
      subtitle: Text([
        shortDate(entry.createdAt),
        if (entry.note != null) entry.note!,
      ].join(' · ')),
      trailing: Text(
        '$sign ${entry.amount.format()}',
        style: TextStyle(fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
