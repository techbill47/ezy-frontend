import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client, this.token}) : _client = client ?? http.Client();
  final http.Client _client;
  final String? token;

  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> post(String path, [Map<String, dynamic>? body]) => _send('POST', path, body);

  Future<dynamic> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$apiBaseUrl$path');
    final headers = <String, String>{'Accept': 'application/json', 'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'};
    if (token != null && token!.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _client.send(request).timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamed).timeout(const Duration(seconds: 15));
      dynamic decoded;
      try { decoded = response.body.isEmpty ? null : jsonDecode(response.body); } catch (_) { decoded = null; }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = decoded is Map ? decoded['error']?.toString() : null;
        throw ApiException(message?.isNotEmpty == true ? message! : 'Server error (${response.statusCode}). Please try again.', statusCode: response.statusCode);
      }
      return decoded;
    } on ApiException { rethrow; }
    on TimeoutException { throw ApiException('The server took too long to respond. Please try again.'); }
    on SocketException { throw ApiException('Cannot reach the server. Check your internet connection and server address.'); }
    on http.ClientException { throw ApiException('Cannot reach the server. Check your internet connection and server address.'); }
    catch (error) { throw ApiException('Request failed: $error'); }
  }
}
