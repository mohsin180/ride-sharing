import 'dart:convert';

import 'package:ride_sharing/controller/apiClient.dart';
import 'package:ride_sharing/model/authModels.dart';
import 'package:ride_sharing/widgets/consonants/apiConsonants.dart';
import 'package:http/http.dart' as http;

class Authservice {
  final Apiclient apiclient;
  Authservice({required this.apiclient});

  Future<LoginResponse> login(LoginRequest request) async {
    final json = await apiclient.post(
      Apiconsonants.loginEndpoint,
      request.toJson(),
    );
    return LoginResponse.fromJson(json);
  }

  Future<RegisterResponse> register(RegisterRequest request) async {
    final json = await apiclient.post(
      Apiconsonants.registerEndpoint,
      request.toJson(),
    );
    return RegisterResponse.fromJson(json);
  }

  Future<bool> isEmailVerified(String userId) async {
    final isEmailVerifiedEndpoint =
        "http://localhost:8080/api/v1/user/$userId/is-Email-Verified";
    final result = await apiclient.get(isEmailVerifiedEndpoint);
    return result;
  }

  Future<void> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse(Apiconsonants.forgotPasswordEndpoint),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email}),
    );
    if (response.statusCode != 200) {
      throw Exception(response.body);
    }
  }

  Future<void> resetPassword(ResetPasswordDto request) async {
    await apiclient.post(Apiconsonants.resetPasswordEndpoint, request.toJson());
  }
}
