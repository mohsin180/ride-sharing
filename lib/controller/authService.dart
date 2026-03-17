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
    final response = await apiclient.post(
      Apiconsonants.registerEndpoint,
      request.toJson(),
    );
    return RegisterResponse.fromJson(response);
  }

  Future<void> verifyEmail(String token) async {
    final url = "http://localhost:8080/api/v1/auth/verify-email?token=$token";
    final response = await http.get(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
    );
    print("STATUS: ${response.statusCode}");
    print("BODY: ${response.body}");
  }

  Future<bool> isEmailVerified(String userId) async {
    final isEmailVerifiedEndpoint =
        "http://localhost:8080/api/v1/auth/is-email-verified/$userId";
    final result = await apiclient.get(isEmailVerifiedEndpoint);
    return result;
  }

  Future<void> forgotPassword(ForgotPassword request) async {
    await apiclient.post(
      Apiconsonants.forgotPasswordEndpoint,
      request.toJson(),
    );
  }

  Future<void> resetPassword(ResetPasswordDto request) async {
    await apiclient.post(Apiconsonants.resetPasswordEndpoint, request.toJson());
  }

  Future<bool> checkResetStatus(String token) async {
    final respose = await apiclient.get(
      "${Apiconsonants.resetStatusEndpoint}?token=$token",
    );
    return respose;
  }

  // selecting-role endpoint
  Future<LoginResponse> assignRole(String id, String role) async {
    String url = "http://localhost:8080/api/v1/auth/$id/select-role";
    final response = await apiclient.post(url, {"role": role});
    return LoginResponse.fromJson(response);
  }
}
