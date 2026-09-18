import 'package:flutter/material.dart';

import 'package:bakibondhu/core/app_scope.dart';
import 'package:bakibondhu/core/format.dart';
import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/domain/models.dart';
import 'package:bakibondhu/domain/money.dart';

/// Screen 3 — Add transaction: a big number pad, date (defaults to today),
/// due date (credits only), and an optional note (spec §8.6/§8.7, UI/UX §5.8).
/// Pushed with a fixed [type]; pops `true` after a successful save.
class AddTransactionScreen extends StatefulWidget {
  final String customerId;
  final TxnType type; // credit or payment
  const AddTransactionScreen({
    required this.customerId,
    required this.type,
    super.key,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  String _amount = '';
  DateTime _date = DateTime.now();
  DateTime? _dueDate;
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  bool get _isCredit => widget.type == TxnType.credit;
  num? get _parsed => num.tryParse(_amount);
  bool get _valid => (_parsed ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    if (_isCredit) _dueDate = DateTime.now(); // sensible default; editable
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  void _tap(String key) {
    setState(() {
      if (key == '⌫') {
        if (_amount.isNotEmpty) _amount = _amount.substring(0, _amount.length - 1);
      } else if (key == '.') {
        if (!_amount.contains('.')) _amount += _amount.isEmpty ? '0.' : '.';
      } else {
        _amount += key;
      }
    });
  }

  Future<void> _pickDate({required bool due}) async {
    final initial = due ? (_dueDate ?? DateTime.now()) : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => due ? _dueDate = picked : _date = picked);
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    final repo = AppScope.of(context);
    final amount = Money.taka(_parsed!);
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    if (_isCredit) {
      await repo.recordCredit(
          customerId: widget.customerId,
          amount: amount,
          dueDate: _dueDate,
          note: note,
          at: _date);
    } else {
      await repo.recordPayment(
          customerId: widget.customerId, amount: amount, note: note, at: _date);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final title = _isCredit ? S.gaveCredit : S.gotPayment;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      // SafeArea keeps the pinned Save button clear of the phone's gesture /
      // navigation bar; the top section scrolls so nothing is cut off on short
      // screens.
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Amount display
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      alignment: Alignment.center,
                      child: Text(
                        '৳ ${_amount.isEmpty ? '0' : _amount}',
                        style: const TextStyle(
                            fontSize: 44, fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Date + due date + note
                    ListTile(
                      leading: const Icon(Icons.event),
                      title: Text(S.dateLabel),
                      trailing:
                          Text(_isToday(_date) ? S.today : shortDate(_date)),
                      onTap: () => _pickDate(due: false),
                    ),
                    if (_isCredit)
                      ListTile(
                        leading: const Icon(Icons.schedule),
                        title: Text(S.dueDateLabel),
                        trailing:
                            Text(_dueDate == null ? '—' : shortDate(_dueDate!)),
                        onTap: () => _pickDate(due: true),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _noteCtrl,
                        decoration:
                            InputDecoration(labelText: S.noteLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _NumberPad(onKey: _tap),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _valid && !_saving ? _save : null,
                  child: Text(S.save),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

class _NumberPad extends StatelessWidget {
  final void Function(String) onKey;
  const _NumberPad({required this.onKey});

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['.', '0', '⌫'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in _rows)
          Row(
            children: [
              for (final key in row)
                Expanded(
                  child: InkWell(
                    onTap: () => onKey(key),
                    child: Container(
                      height: 60,
                      alignment: Alignment.center,
                      child: Text(key,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
