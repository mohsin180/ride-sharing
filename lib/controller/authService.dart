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
    return LoginResponse.fromJson(json as Map<String, dynamic>);
  }

  Future<RegisterResponse> register(RegisterRequest request) async {
    final json = await apiclient.post(
      Apiconsonants.registerEndpoint,
      request.toJson(),
    );
    return RegisterResponse.fromJson(json as Map<String, dynamic>);
  }

  Future<void> verifyEmail(String token) async {
    await apiclient.get("${Apiconsonants.verifyEmailEndpoint}?token=$token");
  }

  Future<void> resendVerification(String email) async {
    await apiclient.post(
      Apiconsonants.resendVerificationEndpoint,
      {"email": email},
    );
  }

  Future<bool> isEmailVerified(String userId) async {
    final result = await apiclient.get(
      Apiconsonants.isEmailVerifiedEndpoint(userId),
    );
    if (result is bool) return result;
    if (result is Map && result['verified'] is bool) {
      return result['verified'] as bool;
    }
    return false;
  }

  Future<void> forgotPassword(ForgotPassword request) async {
    await apiclient.post(
      Apiconsonants.forgotPasswordEndpoint,
      request.toJson(),
    );
  }

  Future<void> resetPassword(ResetPasswordDto request) async {
    await apiclient.post(
      Apiconsonants.resetPasswordEndpoint,
      request.toJson(),
    );
  }

  Future<bool> checkResetStatus(String token) async {
    final result = await apiclient.get(
      "${Apiconsonants.resetStatusEndpoint}?token=$token",
    );
    if (result is bool) return result;
    if (result is Map && result['valid'] is bool) {
      return result['valid'] as bool;
    }
    return false;
  }

  /// Finishes signup. The backend identifies the user from
  /// [onboardingToken] (issued by register, or by a login that reported
  /// `roleRequired`) rather than from a user id in the URL.
  Future<LoginResponse> assignRole(String onboardingToken, String role) async {
    final json = await apiclient.post(
      Apiconsonants.selectRoleEndpoint,
      {"role": role},
      token: onboardingToken,
    );
    return LoginResponse.fromJson(json as Map<String, dynamic>);
  }
}
