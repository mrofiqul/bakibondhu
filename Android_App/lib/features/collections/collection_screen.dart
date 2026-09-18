import 'package:flutter/material.dart';

import 'package:bakibondhu/core/app_scope.dart';
import 'package:bakibondhu/core/format.dart';
import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/data/ledger_repository.dart';
import 'package:bakibondhu/domain/collections.dart';
import 'package:bakibondhu/domain/money.dart';
import 'package:bakibondhu/features/collections/collection_labels.dart';

/// Collection activities + promise-to-pay for one customer (spec §8.8/§8.9).
class CollectionScreen extends StatefulWidget {
  final String customerId;
  const CollectionScreen({required this.customerId, super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _Data {
  final List<CollectionActivity> activities;
  final List<PromiseToPay> promises;
  const _Data(this.activities, this.promises);
}

class _CollectionScreenState extends State<CollectionScreen> {
  _Data? _data;
  LedgerRepository get _repo => AppScope.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refresh();
  }

  /// Reloads activities + promises into state and rebuilds. Storing the result
  /// (rather than swapping a FutureBuilder's future) makes a reload after adding
  /// an activity/promise reliably repaint.
  Future<void> _refresh() async {
    final activities = await _repo.collectionActivitiesOf(widget.customerId);
    final promises = await _repo.promisesOf(widget.customerId);
    if (!mounted) return;
    setState(() => _data = _Data(activities, promises));
  }

  Future<void> _addActivity() async {
    final result = await _showActivityDialog(context);
    if (result == null) return;
    await _repo.addCollectionActivity(
      customerId: widget.customerId,
      method: result.method,
      status: result.status,
      note: result.note,
      nextFollowUp: result.nextFollowUp,
    );
    _refresh();
  }

  Future<void> _addPromise() async {
    final result = await _showPromiseDialog(context);
    if (result == null) return;
    await _repo.addPromise(
      customerId: widget.customerId,
      amount: result.amount,
      promiseDate: result.promiseDate,
      followUpDate: result.followUpDate,
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.collections)),
      body: Builder(
        builder: (context) {
          final data = _data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Row(children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _addActivity,
                    icon: const Icon(Icons.add_call),
                    label: Text(S.recordCollection),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _addPromise,
                    icon: const Icon(Icons.handshake_outlined),
                    label: Text(S.recordPromise),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              _SectionHeader(S.promises),
              if (data.promises.isEmpty)
                _Empty(S.noPromises)
              else
                ...data.promises.map((p) => _PromiseTile(p)),
              const SizedBox(height: 16),
              _SectionHeader(S.activityHistory),
              if (data.activities.isEmpty)
                _Empty(S.noActivity)
              else
                ...data.activities.map((a) => _ActivityTile(a)),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(8), child: Text(text));
}

class _ActivityTile extends StatelessWidget {
  final CollectionActivity a;
  const _ActivityTile(this.a);
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.record_voice_over_outlined),
      title: Text(collectionStatusLabels[a.status] ?? ''),
      subtitle: Text([
        contactMethodLabels[a.method] ?? '',
        shortDate(a.contactedAt),
        if (a.note != null) a.note!,
        if (a.nextFollowUp != null) '${S.nextFollowUpLabel}: ${shortDate(a.nextFollowUp!)}',
      ].join(' · ')),
    );
  }
}

class _PromiseTile extends StatelessWidget {
  final PromiseToPay p;
  const _PromiseTile(this.p);
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.handshake_outlined),
      title: Text(p.promisedAmount.format()),
      subtitle: Text([
        '${S.promiseDateLabel}: ${shortDate(p.promiseDate)}',
        promiseStatusLabels[p.status] ?? '',
      ].join(' · ')),
    );
  }
}

// ---- dialogs ----

typedef _ActivityResult = ({
  ContactMethod method,
  CollectionStatus status,
  String? note,
  DateTime? nextFollowUp,
});

Future<_ActivityResult?> _showActivityDialog(BuildContext context) {
  var method = ContactMethod.phone;
  var status = CollectionStatus.contacted;
  DateTime? followUp;
  final noteCtrl = TextEditingController();

  return showDialog<_ActivityResult>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(S.recordCollection),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<ContactMethod>(
              initialValue: method,
              decoration: InputDecoration(labelText: S.methodLabel),
              items: [
                for (final m in ContactMethod.values)
                  DropdownMenuItem(value: m, child: Text(contactMethodLabels[m]!)),
              ],
              onChanged: (v) => setState(() => method = v ?? method),
            ),
            DropdownButtonFormField<CollectionStatus>(
              initialValue: status,
              decoration: InputDecoration(labelText: S.statusLabel),
              items: [
                for (final s in CollectionStatus.values)
                  DropdownMenuItem(value: s, child: Text(collectionStatusLabels[s]!)),
              ],
              onChanged: (v) => setState(() => status = v ?? status),
            ),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(labelText: S.noteLabel),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(S.nextFollowUpLabel),
              trailing: Text(followUp == null ? '—' : shortDate(followUp!)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => followUp = picked);
              },
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(S.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, (
              method: method,
              status: status,
              note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
              nextFollowUp: followUp,
            )),
            child: Text(S.save),
          ),
        ],
      ),
    ),
  );
}

typedef _PromiseResult = ({Money amount, DateTime promiseDate, DateTime? followUpDate});

Future<_PromiseResult?> _showPromiseDialog(BuildContext context) {
  final amountCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  DateTime promiseDate = DateTime.now();

  return showDialog<_PromiseResult>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(S.recordPromise),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: S.promiseAmountLabel, prefixText: '৳ '),
              validator: (v) {
                final n = num.tryParse((v ?? '').trim());
                return (n == null || n <= 0) ? S.amountRequired : null;
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(S.promiseDateLabel),
              trailing: Text(shortDate(promiseDate)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: promiseDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => promiseDate = picked);
              },
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(S.cancel)),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context, (
                amount: Money.taka(num.parse(amountCtrl.text.trim())),
                promiseDate: promiseDate,
                followUpDate: null,
              ));
            },
            child: Text(S.save),
          ),
        ],
      ),
    ),
  );
}
