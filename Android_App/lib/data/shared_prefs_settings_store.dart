import 'package:shared_preferences/shared_preferences.dart';

import 'package:bakibondhu/data/settings_store.dart';

/// [SettingsStore] backed by shared_preferences (on-device persistence).
class SharedPrefsSettingsStore implements SettingsStore {
  static const _kShopName = 'shop_name';
  static const _kOnboarded = 'onboarding_complete';
  static const _kTrialDismissedOn = 'trial_reminder_dismissed_on';
  static const _kDataOwner = 'data_owner_business_id';

  final SharedPreferences _prefs;
  SharedPrefsSettingsStore(this._prefs);

  @override
  Future<String?> shopName() async => _prefs.getString(_kShopName);

  @override
  Future<void> setShopName(String? name) async {
    if (name == null || name.isEmpty) {
      await _prefs.remove(_kShopName);
    } else {
      await _prefs.setString(_kShopName, name);
    }
  }

  @override
  Future<bool> onboardingComplete() async =>
      _prefs.getBool(_kOnboarded) ?? false;

  @override
  Future<void> setOnboardingComplete(bool value) async =>
      _prefs.setBool(_kOnboarded, value);

  @override
  Future<String?> trialReminderDismissedOn() async =>
      _prefs.getString(_kTrialDismissedOn);

  @override
  Future<void> setTrialReminderDismissedOn(String date) async =>
      _prefs.setString(_kTrialDismissedOn, date);

  @override
  Future<String?> dataOwnerBusinessId() async =>
      _prefs.getString(_kDataOwner);

  @override
  Future<void> setDataOwnerBusinessId(String? businessId) async {
    if (businessId == null || businessId.isEmpty) {
      await _prefs.remove(_kDataOwner);
    } else {
      await _prefs.setString(_kDataOwner, businessId);
    }
  }
}
