import 'package:flutter/material.dart';

import 'package:bakibondhu/core/app_scope.dart';
import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/features/sync/sync_center_screen.dart';

/// Settings: shop name (feeds reminder signatures), account/sync, and about.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _shopCtrl = TextEditingController();
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      AppScope.settingsOf(context).shopName().then((name) {
        if (mounted) setState(() => _shopCtrl.text = name ?? '');
      });
    }
  }

  @override
  void dispose() {
    _shopCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveShopName() async {
    await AppScope.settingsOf(context).setShopName(_shopCtrl.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(S.savedMsg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.sessionOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text(S.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(S.shopNameSetting, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _shopCtrl,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _saveShopName, child: const Text(S.save)),
          ]),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text(S.accountSection),
            subtitle: Text(session.isLoggedIn
                ? S.loggedInAs(session.role ?? '')
                : S.notLoggedIn),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SyncCenterScreen()));
              if (mounted) setState(() {});
            },
          ),
          const Divider(height: 32),
          Text(S.aboutSection, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('${S.appName} · v0.1.17'),
            subtitle: Text('Bangla-first · offline-first'),
          ),
        ],
      ),
    );
  }
}
