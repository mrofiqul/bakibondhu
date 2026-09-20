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
const String kAppVersion = '0.1.28';
const int kAppBuild = 29;
