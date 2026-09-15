/// Small app settings: the shop name (used in reminder signatures) and whether
/// first-run onboarding is done. Pure Dart so it can be tested without Flutter;
/// the persistent implementation lives in `shared_prefs_settings_store.dart`.
abstract class SettingsStore {
  Future<String?> shopName();
  Future<void> setShopName(String? name);
  Future<bool> onboardingComplete();
  Future<void> setOnboardingComplete(bool value);

  /// The date (YYYY-MM-DD) on which the user last dismissed the trial-ending
  /// reminder, so it stays hidden for that day and reappears the next.
  Future<String?> trialReminderDismissedOn();
  Future<void> setTrialReminderDismissedOn(String date);

  /// The business (shop) id whose data currently lives in the local database.
  /// Used to isolate shops on a shared device: if a different shop logs in, the
  /// previous shop's local data is cleared before syncing the new one. Null
  /// means the local data isn't yet tied to any account (fresh/offline).
  Future<String?> dataOwnerBusinessId();
  Future<void> setDataOwnerBusinessId(String? businessId);
}

/// In-memory settings for tests.
class InMemorySettingsStore implements SettingsStore {
  String? _shopName;
  bool _onboarded = false;
  String? _trialDismissedOn;

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

  @override
  Future<String?> trialReminderDismissedOn() async => _trialDismissedOn;

  @override
  Future<void> setTrialReminderDismissedOn(String date) async =>
      _trialDismissedOn = date;

  String? _dataOwner;

  @override
  Future<String?> dataOwnerBusinessId() async => _dataOwner;

  @override
  Future<void> setDataOwnerBusinessId(String? businessId) async =>
      _dataOwner = businessId;
}
