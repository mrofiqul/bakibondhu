import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:bakibondhu/data/auth_api.dart';

/// Holds the signed-in session (JWT + business + role), persisted in secure
/// storage. The app works fully offline with no session; a token is only needed
/// to sync. [HttpSyncApi.accessToken] reads [token] here.
class Session {
  static const _kToken = 'access_token';
  static const _kBusiness = 'business_id';
  static const _kRole = 'role';
  static const _kExpires = 'expires_at';

  final FlutterSecureStorage _storage;
  Session(this._storage);

  String? _token;
  String? _businessId;
  String? _role;
  String? _expiresAt;

  bool get isLoggedIn => _token != null;
  String? get token => _token;
  String? get role => _role;
  String? get businessId => _businessId;

  /// Subscription end date (YYYY-MM-DD), or null = unlimited / unknown.
  String? get expiresAt => _expiresAt;

  /// Restore any persisted session on startup.
  Future<void> load() async {
    _token = await _storage.read(key: _kToken);
    _businessId = await _storage.read(key: _kBusiness);
    _role = await _storage.read(key: _kRole);
    _expiresAt = await _storage.read(key: _kExpires);
  }

  Future<void> save(AuthResult result) async {
    _token = result.accessToken;
    _businessId = result.businessId;
    _role = result.role;
    _expiresAt = result.expiresAt;
    await _storage.write(key: _kToken, value: _token);
    await _storage.write(key: _kBusiness, value: _businessId);
    await _storage.write(key: _kRole, value: _role);
    await _storage.write(key: _kExpires, value: _expiresAt);
  }

  /// Refresh just the expiry (e.g. from a sync pull, where the admin may have
  /// changed it since login). A null value clears it to unlimited/unknown.
  Future<void> updateExpiresAt(String? value) async {
    if (value == _expiresAt) return;
    _expiresAt = value;
    if (value == null) {
      await _storage.delete(key: _kExpires);
    } else {
      await _storage.write(key: _kExpires, value: value);
    }
  }

  Future<void> clear() async {
    _token = null;
    _businessId = null;
    _role = null;
    _expiresAt = null;
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kBusiness);
    await _storage.delete(key: _kRole);
    await _storage.delete(key: _kExpires);
  }
}
