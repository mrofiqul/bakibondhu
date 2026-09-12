/// App-wide build configuration.
///
/// [kSyncBaseUrl] is the backend base URL. It defaults to the Android-emulator
/// host loopback for local dev and is overridden for release builds with:
///   --dart-define=SYNC_BASE_URL=https://bakibondhu.infinityfreeapp.com
const String kSyncBaseUrl = String.fromEnvironment(
  'SYNC_BASE_URL',
  defaultValue: 'http://10.0.2.2:5080',
);

/// The web super-admin panel, served alongside the backend at `/admin/`.
/// Opened in the device browser from Settings (login-gated).
Uri get kAdminPanelUrl => Uri.parse(kSyncBaseUrl).resolve('/admin/');
