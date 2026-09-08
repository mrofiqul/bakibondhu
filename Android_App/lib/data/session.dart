import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:bakibondhu/data/auth_api.dart';

/// Holds the signed-in session (JWT + business + role), persisted in secure
/// storage. The app works fully offline with no session; a token is only needed
/// to sync. [HttpSyncApi.accessToken] reads [token] here.
class Session {
  static const _kToken = 'access_token';
  static const _kBusiness = 'business_id';
  static const _kRole = 'role';

  final FlutterSecureStorage _storage;
  Session(this._storage);

  String? _token;
  String? _businessId;
  String? _role;

  bool get isLoggedIn => _token != null;
  String? get token => _token;
  String? get role => _role;
  String? get businessId => _businessId;

  /// Restore any persisted session on startup.
  Future<void> load() async {
    _token = await _storage.read(key: _kToken);
    _businessId = await _storage.read(key: _kBusiness);
    _role = await _storage.read(key: _kRole);
  }

  Future<void> save(AuthResult result) async {
    _token = result.accessToken;
    _businessId = result.businessId;
    _role = result.role;
    await _storage.write(key: _kToken, value: _token);
    await _storage.write(key: _kBusiness, value: _businessId);
    await _storage.write(key: _kRole, value: _role);
  }

  Future<void> clear() async {
    _token = null;
    _businessId = null;
    _role = null;
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kBusiness);
    await _storage.delete(key: _kRole);
  }
}
