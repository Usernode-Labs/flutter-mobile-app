import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

typedef RequestWrittenCallback = FutureOr<void> Function();

/// `dart:io` HTTP transport with an explicit request-written boundary.
///
/// The request body is materialized so the transport can set an exact content
/// length. Once that complete body has been flushed and the request sink has
/// been closed, [onRequestWritten] runs without waiting for response headers.
/// Authenticated callers use that callback as their effect-permit handoff.
final class RequestWrittenHttpTransport {
  RequestWrittenHttpTransport({HttpClient? client})
      : _client = client ?? HttpClient();

  HttpClient? _client;

  Future<http.StreamedResponse> send(
    http.BaseRequest request, {
    required RequestWrittenCallback onRequestWritten,
  }) async {
    final client = _client;
    if (client == null) {
      throw http.ClientException(
        'HTTP request failed. Transport is already closed.',
        request.url,
      );
    }

    final body = await request.finalize().toBytes();
    final declaredLength = request.contentLength;
    if (declaredLength != null && declaredLength != body.length) {
      throw http.ClientException(
        'Request content length does not match its finalized body.',
        request.url,
      );
    }

    try {
      final ioRequest = await client.openUrl(request.method, request.url)
        ..followRedirects = false
        ..persistentConnection = request.persistentConnection
        ..bufferOutput = false
        ..contentLength = body.length;
      request.headers.forEach(ioRequest.headers.set);

      ioRequest.add(body);
      await ioRequest.flush();
      final responseFuture = ioRequest.close();

      try {
        await Future<void>.sync(onRequestWritten);
      } catch (error, stackTrace) {
        unawaited(responseFuture.then<void>(
          (response) => response.drain<void>(),
          onError: (_) {},
        ));
        Error.throwWithStackTrace(error, stackTrace);
      }

      final response = await responseFuture;
      final headers = <String, String>{};
      response.headers.forEach((name, values) {
        headers[name] = values.join(',');
      });
      return _RequestWrittenStreamedResponse(
        response,
        response.statusCode,
        url: response.redirects.isEmpty
            ? request.url
            : response.redirects.last.location,
        contentLength:
            response.contentLength < 0 ? null : response.contentLength,
        request: request,
        headers: headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } on SocketException catch (error) {
      throw http.ClientException(error.message, request.url);
    } on HttpException catch (error) {
      throw http.ClientException(error.message, error.uri ?? request.url);
    }
  }

  void close() {
    _client?.close(force: true);
    _client = null;
  }
}

final class _RequestWrittenStreamedResponse extends http.StreamedResponse
    implements http.BaseResponseWithUrl {
  _RequestWrittenStreamedResponse(
    super.stream,
    super.statusCode, {
    required this.url,
    super.contentLength,
    super.request,
    super.headers,
    super.isRedirect,
    super.persistentConnection,
    super.reasonPhrase,
  });

  @override
  final Uri url;
}
