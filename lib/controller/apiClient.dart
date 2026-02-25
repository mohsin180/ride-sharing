import 'dart:convert';

import 'package:http/http.dart' as http;

class Apiclient {
  final _client = http.Client();

  Future<Map<String, dynamic>> post(
    String url,
    Map<String, dynamic> body, {
    String? accessToken,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
    final response = await _client.post(
      Uri.parse(url),
      body: jsonEncode(body),
      headers: headers,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);
    } else {
      throw Exception(response.body);
    }
  }

  Future<bool> get(String url, {String? accessToken}) async {
    final headers = {
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
    final response = await _client.get(Uri.parse(url), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as bool;
    } else {
      throw Exception(response.body);
    }
  }
}
