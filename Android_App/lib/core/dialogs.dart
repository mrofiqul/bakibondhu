import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/domain/money.dart';

/// Lightweight add-customer dialog so Home is usable now. The full Add-customer
/// screen (Screen 4) with more fields comes later; name-only is enough to start.
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

/// Record a direct sale: an amount (+ optional note), no customer.
Future<({Money amount, String? note})?> showAddSaleDialog(BuildContext context) {
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return showDialog<({Money amount, String? note})>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(S.addSale),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(labelText: S.saleAmountLabel),
              validator: (v) {
                final n = num.tryParse((v ?? '').trim());
                return (n == null || n <= 0) ? S.amountRequired : null;
              },
            ),
            TextFormField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: S.saleNoteLabel),
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
          child: const Text(S.add),
        ),
      ],
    ),
  );
}
