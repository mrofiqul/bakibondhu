import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bakibondhu/core/config.dart';
import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/data/infinityfree_client.dart';

/// A newer app build advertised by the server.
class AppUpdateInfo {
  final String version;
  final int build;
  final String url;
  final String notes;
  const AppUpdateInfo({
    required this.version,
    required this.build,
    required this.url,
    required this.notes,
  });
}

/// Asks the server for the latest Android build and returns [AppUpdateInfo]
/// when it is newer than this one; returns null when up-to-date, and also when
/// the check fails for any reason (offline, timeout, bad response) — the app is
/// offline-first, so a failed check must never disrupt the UI.
Future<AppUpdateInfo?> checkForAppUpdate({int currentBuild = kAppBuild}) async {
  // Use InfinityFreeClient (not a plain http client) so the shared-host anti-bot
  // "browser check" is solved — otherwise the request gets the challenge HTML
  // instead of JSON and the update is never seen.
  final client = InfinityFreeClient();
  try {
    final uri = Uri.parse('$kSyncBaseUrl/api/v1/app/version');
    final res = await client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body);
    if (body is! Map) return null;
    final a = body['android'];
    if (a is! Map) return null;
    final build = (a['build'] as num?)?.toInt() ?? 0;
    if (build <= currentBuild) return null;
    final url = (a['url'] ?? '').toString();
    if (url.isEmpty) return null;
    return AppUpdateInfo(
      version: (a['version'] ?? '').toString(),
      build: build,
      url: url,
      notes: (a['notes'] ?? '').toString(),
    );
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

/// Shows the "an update is available" pop-up. "Update App" opens the APK
/// download so the owner can install it over the existing app — which keeps all
/// existing data (same signed package). "Later" just dismisses it.
Future<void> showUpdateDialog(BuildContext context, AppUpdateInfo info) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(S.updateAvailableTitle),
      content: Text(
        '${S.updateAvailableBody(info.version)}'
        '${info.notes.isNotEmpty ? '\n\n${info.notes}' : ''}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(S.updateLater),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            openUpdateUrl(info.url);
          },
          child: Text(S.updateNow),
        ),
      ],
    ),
  );
}

/// Opens the APK download link in the browser / installer.
Future<void> openUpdateUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
