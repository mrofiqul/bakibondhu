import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/core/validators.dart';
import 'package:bakibondhu/domain/money.dart';

/// Add-customer dialog: name and mobile number are required (mobile validated
/// as a Bangladesh number), address is optional.
Future<({String name, String phone, String? address})?> showAddCustomerDialog(
    BuildContext context) {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return showDialog<({String name, String phone, String? address})>(
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
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: S.nameLabel),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? S.nameRequired : null,
            ),
            TextFormField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: S.mobileLabelRequired),
              validator: bdMobileValidator,
            ),
            TextFormField(
              controller: addressCtrl,
              decoration: const InputDecoration(labelText: S.addressLabelOptional),
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
            final address = addressCtrl.text.trim();
            Navigator.pop(context, (
              name: nameCtrl.text.trim(),
              phone: normalizeBdMobile(phoneCtrl.text.trim()),
              address: address.isEmpty ? null : address,
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
