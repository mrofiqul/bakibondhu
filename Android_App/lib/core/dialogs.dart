import 'package:flutter/material.dart';

import 'package:bakibondhu/core/strings_bn.dart';

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
