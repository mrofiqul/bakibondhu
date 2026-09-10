import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bakibondhu/data/infinityfree_client.dart';

/// The real InfinityFree "browser check" page (constants captured from a live
/// response). A browser runs the JS to set a __test cookie; this client must
/// compute the same cookie so the retry gets through.
const _challenge =
    '<html><body><script type="text/javascript" src="/aes.js"></script><script>'
    'function toNumbers(d){var e=[];d.replace(/(..)/g,function(d){e.push(parseInt(d,16))});return e}'
    'var a=toNumbers("f655ba9d09a112d4968c63579db590b4"),'
    'b=toNumbers("98344c2eee86c3994890592585b49f80"),'
    'c=toNumbers("6b410f0595840b2804de4845ae32f7df");'
    'document.cookie="__test="+toHex(slowAES.decrypt(c,2,a,b))+"; path=/";'
    'location.href="http://x/health?i=1";</script></body></html>';

// The cookie a browser computes for the constants above (verified with openssl).
const _expectedCookie = '4bf24b82b9e30ff2a98e7e609d919077';

void main() {
  test('solves the browser-check challenge and replays the request', () async {
    var served = 0;
    final client = InfinityFreeClient(() => MockClient((req) async {
          final cookie = req.headers['cookie'] ?? '';
          if (cookie.contains('__test=$_expectedCookie')) {
            return http.Response('{"status":"ok"}', 200,
                headers: {'content-type': 'application/json'});
          }
          served++;
          return http.Response(_challenge, 200,
              headers: {'content-type': 'text/html'});
        }));

    final res = await client.get(Uri.parse('http://x/health'));

    expect(res.statusCode, 200);
    expect(res.body, contains('ok'));
    expect(served, 1, reason: 'challenge should be solved on the first pass');
  });

  test('passes through unchanged when there is no challenge (normal host)',
      () async {
    final client = InfinityFreeClient(() => MockClient((req) async {
          expect(req.headers.containsKey('cookie'), isFalse);
          return http.Response('{"ok":true}', 201,
              headers: {'content-type': 'application/json'});
        }));

    final res = await client.post(Uri.parse('https://api.example.com/x'),
        body: '{}', headers: {'content-type': 'application/json'});

    expect(res.statusCode, 201);
  });
}
