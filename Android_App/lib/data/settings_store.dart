/// Small app settings: the shop name (used in reminder signatures) and whether
/// first-run onboarding is done. Pure Dart so it can be tested without Flutter;
/// the persistent implementation lives in `shared_prefs_settings_store.dart`.
abstract class SettingsStore {
  Future<String?> shopName();
  Future<void> setShopName(String? name);
  Future<bool> onboardingComplete();
  Future<void> setOnboardingComplete(bool value);
}

/// In-memory settings for tests.
class InMemorySettingsStore implements SettingsStore {
  String? _shopName;
  bool _onboarded = false;

  InMemorySettingsStore({String? shopName, bool onboarded = false})
      : _shopName = shopName,
        _onboarded = onboarded;

  @override
  Future<String?> shopName() async => _shopName;

  @override
  Future<void> setShopName(String? name) async =>
      _shopName = (name == null || name.isEmpty) ? null : name;

  @override
  Future<bool> onboardingComplete() async => _onboarded;

  @override
  Future<void> setOnboardingComplete(bool value) async => _onboarded = value;
}
