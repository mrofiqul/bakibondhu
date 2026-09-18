import 'package:flutter/foundation.dart';

import 'package:bakibondhu/core/strings_bn.dart';

/// Rebuild trigger for a language change. The app root listens to this and
/// rebuilds the whole UI whenever the active language ([S.lang]) changes.
final ValueNotifier<AppLang> appLanguage = ValueNotifier<AppLang>(S.lang);

AppLang langFromCode(String? code) => code == 'en' ? AppLang.en : AppLang.bn;
String codeOfLang(AppLang lang) => lang == AppLang.en ? 'en' : 'bn';

/// Switches the active language immediately: updates [S.lang] and notifies the
/// root so the whole app re-renders. Persistence is done by the caller (which
/// has the settings store) via [SettingsStore.setLanguage].
void applyLanguage(AppLang lang) {
  if (S.lang == lang && appLanguage.value == lang) return;
  S.lang = lang;
  appLanguage.value = lang;
}
