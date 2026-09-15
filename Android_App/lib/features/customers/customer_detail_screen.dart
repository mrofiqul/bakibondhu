import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:bakibondhu/core/app_scope.dart';
import 'package:bakibondhu/core/dialogs.dart';
import 'package:bakibondhu/core/format.dart';
import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/core/theme.dart';
import 'package:bakibondhu/data/ledger_repository.dart';
import 'package:bakibondhu/domain/models.dart';
import 'package:bakibondhu/features/customers/history_export.dart';
import 'package:bakibondhu/domain/money.dart';
import 'package:bakibondhu/features/collections/collection_screen.dart';
import 'package:bakibondhu/features/reminders/reminder_preview_screen.dart';
import 'package:bakibondhu/features/transactions/add_transaction_screen.dart';

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
  _DetailData? _data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refresh();
  }

  /// Reloads balance + history into state and rebuilds. Storing the result
  /// (rather than swapping a FutureBuilder's future) makes a reload after a new
  /// transaction reliably repaint.
  Future<void> _refresh() async {
    final repo = AppScope.of(context);
    final customer = await repo.customer(widget.customerId);
    final balance = await repo.balanceOf(widget.customerId);
    final history = await repo.transactionsOf(widget.customerId);
    if (!mounted) return;
    setState(() => _data = _DetailData(customer!, balance, history));
  }

  Future<void> _openAdd(TxnType type) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddTransactionScreen(customerId: widget.customerId, type: type),
      ),
    );
    if (saved == true) _refresh();
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _exportHistory(_DetailData data) async {
    if (data.history.isEmpty) {
      _snack(S.nothingToExport);
      return;
    }
    final shopName = await AppScope.settingsOf(context).shopName();
    if (!mounted) return;
    final statement = buildHistoryStatement(
      customer: data.customer,
      history: data.history,
      balance: data.balance,
      shopName: (shopName == null || shopName.trim().isEmpty)
          ? S.shopNamePlaceholder
          : shopName.trim(),
    );
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${data.customer.name} · ${S.historyExportTitle}',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 10),
              Flexible(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(statement,
                        style: const TextStyle(fontSize: 13, height: 1.5)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy),
                      label: const Text(S.copyText),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: statement));
                        if (ctx.mounted) Navigator.pop(ctx);
                        _snack(S.copied);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.share),
                      label: const Text(S.shareText),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Share.share(statement,
                            subject:
                                '${data.customer.name} · ${S.historyExportTitle}');
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editCustomer(_DetailData data) async {
    final repo = AppScope.of(context);
    final c = data.customer;
    final input = await showAddCustomerDialog(
      context,
      title: S.editCustomer,
      submitLabel: S.save,
      initial: (name: c.name, phone: c.phone, address: c.address),
      // Unique within the shop, but the customer keeps its own number.
      phoneExists: (phone) async {
        final other = await repo.customerByPhone(phone);
        return other != null && other.id != c.id;
      },
    );
    if (input == null) return;
    await repo.updateCustomer(
        id: c.id, name: input.name, phone: input.phone, address: input.address);
    await _refresh();
    if (mounted) _snack(S.customerUpdated);
  }

  Future<void> _deleteCustomer(_DetailData data) async {
    // A customer who still owes money can't be deleted — settle up first. Once
    // the balance is settled (পরিশোধিত), deleting removes them and their history.
    if (data.balance.isPositive) {
      _snack(S.cannotDeleteHasDue);
      return;
    }
    final repo = AppScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(S.deleteCustomer),
        content: Text(S.deleteCustomerConfirm(data.customer.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(S.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.owed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(S.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await repo.deleteCustomer(data.customer.id);
    } on CustomerHasOutstandingDue {
      if (mounted) _snack(S.cannotDeleteHasDue);
      return;
    }
    if (mounted) Navigator.pop(context); // back to Home (which refreshes)
  }

  Future<void> _openReminder(_DetailData data) async {
    if (data.balance <= Money.zero) return _snack(S.nothingDue);
    final phone = data.customer.phone;
    if (phone == null || phone.isEmpty) return _snack(S.needPhone);
    final shopName = await AppScope.settingsOf(context).shopName();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReminderPreviewScreen(
          customer: data.customer,
          balance: data.balance,
          shopName: shopName ?? S.shopNamePlaceholder,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      appBar: AppBar(
        title: Text(data?.customer.name ?? ''),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_outlined),
            tooltip: S.collections,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    CollectionScreen(customerId: widget.customerId),
              ),
            ),
          ),
          if (data != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'export') _exportHistory(data);
                if (v == 'edit') _editCustomer(data);
                if (v == 'delete') _deleteCustomer(data);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'export',
                  child: ListTile(
                      leading: Icon(Icons.ios_share),
                      title: Text(S.exportHistory),
                      contentPadding: EdgeInsets.zero),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text(S.editCustomer),
                      contentPadding: EdgeInsets.zero),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                      leading: Icon(Icons.delete_outline, color: AppTheme.owed),
                      title: Text(S.deleteCustomer),
                      contentPadding: EdgeInsets.zero),
                ),
              ],
            ),
        ],
      ),
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : _body(data),
    );
  }

  Widget _body(_DetailData data) {
    return Column(
      children: [
        _BalanceHeader(customer: data.customer, balance: data.balance),
        _ActionsRow(
          onCredit: () => _openAdd(TxnType.credit),
          onPayment: () => _openAdd(TxnType.payment),
          onRemind: () => _openReminder(data),
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
