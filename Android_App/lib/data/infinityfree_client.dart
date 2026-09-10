import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart';

/// An [http.Client] wrapper that transparently passes InfinityFree's (iFastNet)
/// "browser check". Free shared hosts answer the first request from a non-browser
/// with a tiny JavaScript page that computes a `__test` cookie via AES and
/// reloads. A normal HTTP client can't run that JS, so every API call would fail.
///
/// This client detects that challenge page, solves it (AES-128-CBC decrypt of the
/// embedded block → hex → the cookie value), caches the cookie, and replays the
/// original request — so register/login work from the app. Each attempt uses a
/// fresh connection: the host's proxy rejects the cookied retry with "400 Bad
/// Request" if it's pipelined on the same keep-alive connection as the challenge.
///
/// On a normal API host it's inert (no challenge ever appears).
class InfinityFreeClient extends http.BaseClient {
  /// Makes a fresh client per request so the challenge and the cookied retry
  /// never share a keep-alive connection (the host's proxy 400s that).
  final http.Client Function() _newClient;
  String? _cookie;

  InfinityFreeClient([http.Client Function()? newClient])
      : _newClient = newClient ?? http.Client.new;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final method = request.method;
    final url = request.url;
    final headers = Map<String, String>.from(request.headers)
      ..remove('cookie');
    final body = await request.finalize().toBytes();

    _Result res = await _once(method, url, headers, body);
    for (var attempt = 0; attempt < 2 && _isChallenge(res.bytes); attempt++) {
      final cookie = _solve(utf8.decode(res.bytes, allowMalformed: true));
      if (cookie == null) break;
      _cookie = cookie;
      res = await _once(method, url, headers, body);
    }
    return res.toStreamed(request);
  }

  /// One request on a fresh connection (so the challenge and the cookied retry
  /// don't share a keep-alive connection, which the host's proxy 400s).
  Future<_Result> _once(
      String method, Uri url, Map<String, String> headers, List<int> body) async {
    final client = _newClient();
    try {
      final req = http.Request(method, url);
      req.headers.addAll(headers);
      if (_cookie != null) req.headers['cookie'] = '__test=$_cookie';
      if (body.isNotEmpty) req.bodyBytes = Uint8List.fromList(body);
      final streamed = await client.send(req);
      final bytes = await streamed.stream.toBytes();
      return _Result(streamed.statusCode, streamed.headers, bytes,
          streamed.reasonPhrase, streamed.isRedirect,
          streamed.persistentConnection);
    } finally {
      client.close();
    }
  }

  static bool _isChallenge(List<int> bytes) {
    if (bytes.length > 4096) return false; // the challenge page is tiny
    final text = utf8.decode(bytes, allowMalformed: true);
    return text.contains('toNumbers(') &&
        (text.contains('slowAES') || text.contains('aes.js'));
  }

  static String? _solve(String html) {
    final hexes = RegExp(r'toNumbers\("([0-9a-f]+)"\)')
        .allMatches(html)
        .map((m) => m.group(1)!)
        .toList();
    if (hexes.length < 3) return null;
    final key = _fromHex(hexes[0]);
    final iv = _fromHex(hexes[1]);
    final ct = _fromHex(hexes[2]);
    if (key.length != 16 || iv.length != 16 || ct.length != 16) return null;

    // CBC decrypt of the single block == AES_decrypt(ct) XOR iv.
    final cipher = CBCBlockCipher(AESEngine())
      ..init(false, ParametersWithIV<KeyParameter>(KeyParameter(key), iv));
    final out = Uint8List(16);
    cipher.processBlock(ct, 0, out, 0);
    return _toHex(out);
  }

  static Uint8List _fromHex(String h) {
    final out = Uint8List(h.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(h.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  static String _toHex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

  @override
  void close() {} // each request closes its own client
}

class _Result {
  final int status;
  final Map<String, String> headers;
  final List<int> bytes;
  final String? reason;
  final bool isRedirect;
  final bool persistent;
  _Result(this.status, this.headers, this.bytes, this.reason, this.isRedirect,
      this.persistent);

  http.StreamedResponse toStreamed(http.BaseRequest request) {
    return http.StreamedResponse(
      Stream.value(bytes),
      status,
      contentLength: bytes.length,
      request: request,
      headers: headers,
      isRedirect: isRedirect,
      persistentConnection: persistent,
      reasonPhrase: reason,
    );
  }
}
