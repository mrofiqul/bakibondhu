import 'dart:convert';

import 'package:http/http.dart' as http;

/// Result of a successful register/login.
class AuthResult {
  final String accessToken;
  final int expiresIn;
  final String? role;
  final String? businessId;

  /// Subscription end date (YYYY-MM-DD) for this shop, or null = unlimited.
  /// Drives the in-app trial-ending reminder.
  final String? expiresAt;

  const AuthResult({
    required this.accessToken,
    this.expiresIn = 0,
    this.role,
    this.businessId,
    this.expiresAt,
  });
}

/// Thrown for a non-2xx auth response (e.g. wrong password, duplicate user).
class AuthException implements Exception {
  final int status;
  final String message;
  final String? code;
  AuthException(this.status, this.message, [this.code]);
  @override
  String toString() => 'AuthException($status, $code): $message';
}

/// Client for the backend auth endpoints (REST API §2).
class AuthApi {
  final Uri baseUrl;
  final http.Client _client;

  AuthApi({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  Future<AuthResult> register({
    required String name,
    required String phone,
    required String password,
    required String businessName,
    String? thana,
    String? zila,
  }) =>
      _post('/api/v1/auth/register', {
        'name': name,
        'phone': phone,
        'password': password,
        'business_name': businessName,
        'thana': thana,
        'zila': zila,
      });

  Future<AuthResult> login({
    required String identifier,
    required String password,
  }) =>
      _post('/api/v1/auth/login', {
        'identifier': identifier,
        'password': password,
      });

  Future<AuthResult> _post(String path, Map<String, Object?> body) async {
    final res = await _client.post(
      baseUrl.resolve(path),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(body),
    );
    final decoded = res.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final tokens = decoded['tokens'] as Map<String, dynamic>;
      final business = decoded['business'] as Map<String, dynamic>?;
      return AuthResult(
        accessToken: tokens['access_token'] as String,
        expiresIn: (tokens['access_expires_in'] as num?)?.toInt() ?? 0,
        role: decoded['role'] as String?,
        businessId: (business?['id'] ?? decoded['business_id']) as String?,
        // register nests it under business; login returns it at top level.
        expiresAt: (business?['expires_at'] ?? decoded['expires_at']) as String?,
      );
    }

    final error = decoded['error'] as Map<String, dynamic>?;
    throw AuthException(
      res.statusCode,
      (error?['message'] as String?) ?? 'authentication failed',
      error?['code'] as String?,
    );
  }
}
