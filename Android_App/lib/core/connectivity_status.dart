import 'package:flutter/foundation.dart';

/// Whether the device currently has a network connection. Updated by
/// [AutoSync] (the single connectivity listener) and watched by the UI to show
/// the offline banner. Defaults to true so nothing flashes before the first
/// connectivity check.
final ValueNotifier<bool> appOnline = ValueNotifier<bool>(true);
