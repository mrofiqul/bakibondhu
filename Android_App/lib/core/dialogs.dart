import 'package:flutter/material.dart';

import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/domain/money.dart';

/// Lightweight inline dialogs so Home and Customer-detail are usable now. The
/// full Add-customer (Screen 4) and Add-transaction (Screen 3) come next.

/// Collects a customer name (required) + optional phone.
Future<({String name, String? phone})?> showAddCustomerDialog(
    BuildContext context) {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return showDialog<({String name, String? phone})>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(S.newCustomer),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: S.nameLabel),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? S.nameRequired : null,
            ),
            TextFormField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: S.mobileLabel),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text(S.cancel)),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            final phone = phoneCtrl.text.trim();
            Navigator.pop(context, (
              name: nameCtrl.text.trim(),
              phone: phone.isEmpty ? null : phone,
            ));
          },
          child: const Text(S.add),
        ),
      ],
    ),
  );
}

/// Collects an amount (> 0) + optional note. [title] is the action, e.g.
/// "বাকি দিলাম" / "টাকা পেলাম".
Future<({Money amount, String? note})?> showAmountDialog(
  BuildContext context, {
  required String title,
}) {
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return showDialog<({Money amount, String? note})>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: S.amountLabel, prefixText: '৳ '),
              validator: (v) {
                final n = num.tryParse((v ?? '').trim());
                return (n == null || n <= 0) ? S.amountRequired : null;
              },
            ),
            TextFormField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: S.noteLabel),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text(S.cancel)),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            final note = noteCtrl.text.trim();
            Navigator.pop(context, (
              amount: Money.taka(num.parse(amountCtrl.text.trim())),
              note: note.isEmpty ? null : note,
            ));
          },
          child: const Text(S.save),
        ),
      ],
    ),
  );
}
