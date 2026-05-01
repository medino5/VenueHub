import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({this.token});

  String? token;
  final String baseUrl = AppConfig.apiBaseUrl;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> get(String path) async {
    return _send(() => http.get(Uri.parse('$baseUrl$path'), headers: _headers));
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    return _send(() => http.post(Uri.parse('$baseUrl$path'), headers: _headers, body: jsonEncode(body)));
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    return _send(() => http.put(Uri.parse('$baseUrl$path'), headers: _headers, body: jsonEncode(body)));
  }

  Future<Map<String, dynamic>> delete(String path) async {
    return _send(() => http.delete(Uri.parse('$baseUrl$path'), headers: _headers));
  }

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(const Duration(seconds: 30));
      return _decode(response);
    } on SocketException {
      throw ApiException('Cannot reach VenueHub right now. Check your internet connection and try again.');
    } on TimeoutException {
      throw ApiException('VenueHub is taking too long to respond. Please try again in a moment.');
    } on FormatException {
      throw ApiException('VenueHub returned an unexpected response. Please try again later.');
    } on http.ClientException {
      throw ApiException('Network request failed. Please check your connection and try again.');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(decoded['message']?.toString() ?? 'Request failed.');
    }

    return decoded;
  }
}
