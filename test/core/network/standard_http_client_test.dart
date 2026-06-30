import 'dart:io';

import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  group('StandardHttpClient', () {
    late HttpServer server;
    late Uri baseUrl;

    setUp(() async {
      server = await HttpServer.bind('localhost', 0);
      baseUrl = Uri.parse('http://localhost:${server.port}');
      server.listen((request) async {
        if (request.uri.path == '/ok') {
          request.response.headers.set('X-Custom', 'value');
          request.response.statusCode = 200;
          request.response.write('{"hello":"world"}');
        } else if (request.uri.path == '/echo-header') {
          final received = request.headers.value('X-Test') ?? '';
          request.response.statusCode = 200;
          request.response.write(received);
        } else if (request.uri.path == '/slow') {
          await Future.delayed(const Duration(seconds: 2));
          request.response.statusCode = 200;
          request.response.write('too late');
        } else {
          request.response.statusCode = 404;
        }
        await request.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('performs a GET request and returns body/status/headers', () async {
      final client = StandardHttpClient();
      final response = await client.get(baseUrl.replace(path: '/ok'));

      expect(response.statusCode, 200);
      expect(response.body, '{"hello":"world"}');
      expect(response.headers['x-custom'], 'value');
    });

    test('sends request headers', () async {
      final client = StandardHttpClient();
      final response = await client.get(
        baseUrl.replace(path: '/echo-header'),
        headers: {'X-Test': 'sent-value'},
      );

      expect(response.body, 'sent-value');
    });

    test('returns 404 for unknown path without throwing', () async {
      final client = StandardHttpClient();
      final response = await client.get(baseUrl.replace(path: '/missing'));
      expect(response.statusCode, 404);
    });

    test('throws RwHttpTransportException on timeout', () async {
      final client = StandardHttpClient(
        defaultTimeout: const Duration(milliseconds: 100),
      );

      expect(
        () => client.get(baseUrl.replace(path: '/slow')),
        throwsA(isA<RwHttpTransportException>()),
      );
    });

    test('throws RwHttpTransportException on connection failure', () async {
      final client = StandardHttpClient();
      // Nothing listening on this port.
      final deadUrl = Uri.parse('http://localhost:1');

      expect(
        () => client.get(deadUrl),
        throwsA(isA<RwHttpTransportException>()),
      );
    });
  });
}
