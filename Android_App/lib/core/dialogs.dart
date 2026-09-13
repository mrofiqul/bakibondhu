import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/core/validators.dart';
import 'package:bakibondhu/domain/money.dart';

/// Add- or edit-customer dialog: name and mobile number are required (mobile
/// validated as a Bangladesh number), address is optional. [phoneExists] checks
/// whether another customer in this shop already uses the (normalized) mobile
/// number, so numbers stay unique within a shop; a match is shown inline. Pass
/// [initial] to prefill for editing (the caller's [phoneExists] should then
/// exclude the customer being edited).
Future<({String name, String phone, String? address})?> showAddCustomerDialog(
    BuildContext context,
    {required Future<bool> Function(String normalizedPhone) phoneExists,
    ({String name, String? phone, String? address})? initial,
    String? title,
    String? submitLabel}) {
  final nameCtrl = TextEditingController(text: initial?.name ?? '');
  final phoneCtrl = TextEditingController(text: initial?.phone ?? '');
  final addressCtrl = TextEditingController(text: initial?.address ?? '');
  final formKey = GlobalKey<FormState>();

  return showDialog<({String name, String phone, String? address})>(
    context: context,
    builder: (context) {
      String? dupError; // set when the mobile number is already used in this shop
      var checking = false;
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title ?? S.newCustomer),
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
                  decoration: InputDecoration(
                    labelText: S.mobileLabelRequired,
                    errorText: dupError,
                  ),
                  // Clear the duplicate error as soon as the number changes.
                  onChanged: (_) {
                    if (dupError != null) setState(() => dupError = null);
                  },
                  validator: bdMobileValidator,
                ),
                TextFormField(
                  controller: addressCtrl,
                  decoration:
                      const InputDecoration(labelText: S.addressLabelOptional),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(S.cancel)),
            FilledButton(
              onPressed: checking
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      final phone = normalizeBdMobile(phoneCtrl.text.trim());
                      setState(() => checking = true);
                      final taken = await phoneExists(phone);
                      if (taken) {
                        setState(() {
                          dupError = S.duplicateCustomerPhone;
                          checking = false;
                        });
                        return;
                      }
                      if (!context.mounted) return;
                      final address = addressCtrl.text.trim();
                      Navigator.pop(context, (
                        name: nameCtrl.text.trim(),
                        phone: phone,
                        address: address.isEmpty ? null : address,
                      ));
                    },
              child: Text(submitLabel ?? S.add),
            ),
          ],
        ),
      );
    },
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
