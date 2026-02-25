import 'package:ride_sharing/controller/apiClient.dart';
import 'package:ride_sharing/model/authModels.dart';
import 'package:ride_sharing/widgets/consonants/apiConsonants.dart';

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

  Future<void> assignRole({
    required String role,
    required String accessToken,
  }) async {
    await apiclient.post(Apiconsonants.selectedRoleEndpoint, {
      "role": role,
    }, accessToken: accessToken);
  }
}
