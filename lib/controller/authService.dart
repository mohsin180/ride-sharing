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

  /// Records the chosen role. The backend identifies the signup from
  /// [onboardingToken] (issued by register, or by a login that reported an
  /// unfinished stage) rather than from a user id in the URL.
  ///
  /// Hands back no session — a role is the second of five steps, and the
  /// account doesn't exist until identity verification passes.
  Future<OnboardingState> assignRole(String onboardingToken, String role) async {
    final json = await apiclient.post(
      Apiconsonants.selectRoleEndpoint,
      {"role": role},
      token: onboardingToken,
    );
    return OnboardingState.fromJson(json as Map<String, dynamic>);
  }

  // ── Onboarding: everything before an account exists ───────────────
  // All of these carry the onboarding token explicitly, because the stored
  // session token is empty until the very last call succeeds.

  /// Where this signup left off. Drives cold-start routing.
  Future<OnboardingState> onboardingState(String onboardingToken) async {
    final json = await apiclient.get(
      Apiconsonants.onboardingStateEndpoint,
      token: onboardingToken,
    );
    return OnboardingState.fromJson(json as Map<String, dynamic>);
  }

  Future<OnboardingState> savePassengerOnboardingProfile(
    String onboardingToken,
    Map<String, dynamic> profile,
  ) async {
    final json = await apiclient.post(
      Apiconsonants.onboardingPassengerProfileEndpoint,
      profile,
      token: onboardingToken,
    );
    return OnboardingState.fromJson(json as Map<String, dynamic>);
  }

  /// Driver profile and vehicle go together — the app collects them on two
  /// screens but only sends once both are filled.
  Future<OnboardingState> saveDriverOnboardingProfile(
    String onboardingToken,
    Map<String, dynamic> profileWithVehicle,
  ) async {
    final json = await apiclient.post(
      Apiconsonants.onboardingDriverProfileEndpoint,
      profileWithVehicle,
      token: onboardingToken,
    );
    return OnboardingState.fromJson(json as Map<String, dynamic>);
  }

  /// Corrects the gender picked at registration — the fix for a KYC rejection
  /// where the scanned CNIC contradicts the account.
  Future<OnboardingState> changeOnboardingGender(
    String onboardingToken,
    String gender,
  ) async {
    final json = await apiclient.post(
      Apiconsonants.onboardingGenderEndpoint,
      {"gender": gender},
      token: onboardingToken,
    );
    return OnboardingState.fromJson(json as Map<String, dynamic>);
  }

  Future<OnboardingState> startOnboardingKyc(String onboardingToken) async {
    final json = await apiclient.post(
      Apiconsonants.onboardingKycStartEndpoint,
      const {},
      token: onboardingToken,
    );
    return OnboardingState.fromJson(json as Map<String, dynamic>);
  }

  /// Polls the verification. The reply that first reports APPROVED carries
  /// the account's real token — save it and onboarding is over.
  Future<OnboardingState> onboardingKycStatus(String onboardingToken) async {
    final json = await apiclient.get(
      Apiconsonants.onboardingKycStatusEndpoint,
      token: onboardingToken,
    );
    return OnboardingState.fromJson(json as Map<String, dynamic>);
  }

  /// Corrects the gender chosen at signup. The backend refuses once KYC has
  /// approved the account, and hands back a new token otherwise.
  Future<LoginResponse> changeGender(String gender) async {
    final json = await apiclient.put(
      Apiconsonants.changeGenderEndpoint,
      {"gender": gender},
    );
    return LoginResponse.fromJson(json as Map<String, dynamic>);
  }
}
