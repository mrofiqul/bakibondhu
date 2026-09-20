import 'package:flutter/material.dart';

import 'package:bakibondhu/core/app_scope.dart';
import 'package:bakibondhu/core/config.dart';
import 'package:bakibondhu/core/language_toggle.dart';
import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/core/update_service.dart';
import 'package:bakibondhu/features/subscription/subscription_screen.dart';
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
          .showSnackBar(SnackBar(content: Text(S.savedMsg)));
    }
  }

  bool _checkingUpdate = false;

  Future<void> _checkUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    final messenger = ScaffoldMessenger.of(context);
    final info = await checkForAppUpdate();
    if (!mounted) return;
    setState(() => _checkingUpdate = false);
    if (info != null) {
      await showUpdateDialog(context, info);
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(S.updateUpToDate(kAppVersion))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.sessionOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(S.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(S.language, style: Theme.of(context).textTheme.titleMedium),
              const LanguageToggle(),
            ],
          ),
          const Divider(height: 32),
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
            FilledButton(onPressed: _saveShopName, child: Text(S.save)),
          ]),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.sync),
            title: Text(S.accountSection),
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
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: Text(S.subscription),
            subtitle: Text(S.subscriptionSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen())),
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.system_update),
            title: Text(S.updateApp),
            subtitle: Text(S.updateAppSubtitle),
            trailing: _checkingUpdate
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.chevron_right),
            onTap: _checkingUpdate ? null : _checkUpdate,
          ),
          const Divider(height: 32),
          Text(S.aboutSection, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text('${S.appName} · v$kAppVersion'),
            subtitle: const Text('Bangla-first · offline-first'),
          ),
        ],
      ),
    );
  }
}
