import 'package:flutter/material.dart';

import 'package:bakibondhu/core/app_scope.dart';
import 'package:bakibondhu/core/language.dart';
import 'package:bakibondhu/core/strings_bn.dart';

/// A compact "বাংলা | English" switch. Tapping a side applies the language
/// immediately (the whole app re-renders via [appLanguage]) and persists the
/// choice. Because the app root rebuilds on change, this widget always shows
/// the current selection.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  Future<void> _set(BuildContext context, AppLang lang) async {
    final settings = AppScope.settingsOf(context);
    applyLanguage(lang);
    await settings.setLanguage(codeOfLang(lang));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget seg(String label, AppLang lang) {
      final on = S.lang == lang;
      return GestureDetector(
        onTap: () => _set(context, lang),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: on ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: on ? scheme.onPrimary : scheme.onSurfaceVariant,
              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg(S.langBanglaName, AppLang.bn),
          seg(S.langEnglishName, AppLang.en),
        ],
      ),
    );
  }
}
