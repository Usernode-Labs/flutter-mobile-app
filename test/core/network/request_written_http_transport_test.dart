import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto_mobile_app/core/network/request_written_http_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('signals a complete request write before a withheld response', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final responseGate = Completer<void>();
    final receivedBody = Completer<List<int>>();
    final subscription = server.listen((request) async {
      receivedBody.complete(await request.fold<List<int>>(
        <int>[],
        (bytes, chunk) => bytes..addAll(chunk),
      ));
      await responseGate.future;
      request.response
        ..statusCode = HttpStatus.accepted
        ..write('accepted');
      await request.response.close();
    });
    addTearDown(() async {
      if (!responseGate.isCompleted) responseGate.complete();
      await subscription.cancel();
      await server.close(force: true);
    });

    final transport = RequestWrittenHttpTransport();
    addTearDown(transport.close);
    final requestWritten = Completer<void>();
    final body = utf8.encode('request-body-is-complete');
    final request = http.Request(
      'POST',
      Uri.parse('http://${server.address.host}:${server.port}/withhold'),
    )
      ..headers['content-type'] = 'text/plain; charset=utf-8'
      ..bodyBytes = body;

    final responseFuture = transport.send(
      request,
      onRequestWritten: requestWritten.complete,
    );
    var responseSettled = false;
    unawaited(responseFuture.then<void>(
      (_) => responseSettled = true,
      onError: (_) => responseSettled = true,
    ));

    await Future.wait<void>([
      requestWritten.future,
      receivedBody.future.then((_) {}),
    ]).timeout(const Duration(seconds: 2));

    expect(await receivedBody.future, body);
    expect(responseSettled, isFalse);

    responseGate.complete();
    final response = await responseFuture;
    expect(response.statusCode, HttpStatus.accepted);
    expect(await response.stream.bytesToString(), 'accepted');
  });

  test('returns redirects without sending an unpermitted follow-up', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var redirectedRequestCount = 0;
    final subscription = server.listen((request) async {
      if (request.uri.path == '/redirected') {
        redirectedRequestCount += 1;
        request.response.statusCode = HttpStatus.ok;
      } else {
        request.response
          ..statusCode = HttpStatus.found
          ..headers.set(HttpHeaders.locationHeader, '/redirected');
      }
      await request.response.close();
    });
    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
    });

    final transport = RequestWrittenHttpTransport();
    addTearDown(transport.close);
    final response = await transport.send(
      http.Request(
        'GET',
        Uri.parse('http://${server.address.host}:${server.port}/initial'),
      ),
      onRequestWritten: () {},
    );

    expect(response.statusCode, HttpStatus.found);
    expect(redirectedRequestCount, 0);
  });
}
