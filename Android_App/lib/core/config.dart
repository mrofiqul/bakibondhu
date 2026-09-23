/// App-wide build configuration.
///
/// [kSyncBaseUrl] is the backend base URL. It defaults to the Android-emulator
/// host loopback for local dev and is overridden for release builds with:
///   --dart-define=SYNC_BASE_URL=https://bakibondhu.infinityfreeapp.com
const String kSyncBaseUrl = String.fromEnvironment(
  'SYNC_BASE_URL',
  defaultValue: 'http://10.0.2.2:5080',
);

/// This build's version, kept in sync with `pubspec.yaml`. The update check
/// compares [kAppBuild] (the numeric build after the `+`) against the latest
/// build the server advertises at `/api/v1/app/version`.
const String kAppVersion = '0.1.30';
const int kAppBuild = 31;

/// Subscription plan + payment details shown on the Subscription screen.
/// Every shop starts with a [kTrialDays]-day free trial; after that the owner
/// renews by paying the monthly price and confirming with the numbers below.
const int kTrialDays = 30;
const int kPriceBdtPerMonth = 100; // ৳ per month, inside Bangladesh
const String kPriceUsdPerMonth = '1.20'; // US$ per month, outside Bangladesh
const String kBkashNumber = '01723-967187'; // bKash (personal)
const String kSupportWhatsApp = '01730781320'; // WhatsApp (local format)
const String kSupportWhatsAppIntl = '8801730781320'; // for wa.me links
const String kSupportEmail = 'rofiqulislam90.cse@gmail.com';
