import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/domain/models.dart';
import 'package:bakibondhu/domain/money.dart';

/// Screen 5 — Reminder preview: a polite, pre-filled Bangla message the merchant
/// can edit, then send via the OS SMS composer or WhatsApp (spec §9/§34, §5.10).
/// v1 is merchant-triggered — the app never auto-sends.
class ReminderPreviewScreen extends StatefulWidget {
  final Customer customer;
  final Money balance;
  final String shopName;

  const ReminderPreviewScreen({
    required this.customer,
    required this.balance,
    this.shopName = S.shopNamePlaceholder,
    super.key,
  });

  @override
  State<ReminderPreviewScreen> createState() => _ReminderPreviewScreenState();
}

class _ReminderPreviewScreenState extends State<ReminderPreviewScreen> {
  late final TextEditingController _msgCtrl =
      TextEditingController(text: buildReminderMessage(
    name: widget.customer.name,
    balance: widget.balance,
    shopName: widget.shopName,
  ));

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  String get _phoneDigits =>
      (widget.customer.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> _launch(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(S.couldNotOpen)));
    }
  }

  Future<void> _sendSms() async {
    final uri = Uri(
      scheme: 'sms',
      path: widget.customer.phone,
      queryParameters: {'body': _msgCtrl.text},
    );
    await _launch(uri);
  }

  Future<void> _sendWhatsApp() async {
    final uri = Uri.parse(
        'https://wa.me/$_phoneDigits?text=${Uri.encodeComponent(_msgCtrl.text)}');
    await _launch(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.reminderTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(widget.customer.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(widget.customer.phone ?? ''),
            ),
            const SizedBox(height: 8),
            Text('✎ ${S.editBeforeSend}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            TextField(
              controller: _msgCtrl,
              maxLines: 6,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _sendSms,
                    icon: const Icon(Icons.sms),
                    label: const Text(S.sendSms),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _phoneDigits.isEmpty ? null : _sendWhatsApp,
                    icon: const Icon(Icons.chat),
                    label: const Text(S.whatsapp),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The pre-filled polite Bangla reminder (mirrors the system template in the DB
/// seed / spec §5.2). `shopName` comes from business settings once that exists.
String buildReminderMessage({
  required String name,
  required Money balance,
  required String shopName,
}) {
  return 'আসসালামু আলাইকুম $name ভাই। আপনার কাছে $shopName-এ '
      '${balance.format()} বাকি আছে। সুবিধামতো পরিশোধ করলে উপকৃত হতাম। ধন্যবাদ।';
}
