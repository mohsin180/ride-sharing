import 'package:ride_sharing/model/kycModels.dart';

// register models
class RegisterRequest {
  final String email;
  final String password;
  final String gender;

  RegisterRequest({
    required this.email,
    required this.password,
    required this.gender,
  });

  Map<String, dynamic> toJson() => {
    "email": email,
    "password": password,
    "gender": gender,
  };
}

class RegisterResponse {
  final String id;
  final String email;

  /// Authorises the later `/select-role` call. Persisted so signup survives
  /// the app being killed while the user verifies their email.
  final String onboardingToken;

  RegisterResponse({
    required this.id,
    required this.email,
    required this.onboardingToken,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      onboardingToken: (json['onboardingToken'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() =>
      {"id": id, "email": email, "onboardingToken": onboardingToken};
}

// login Models
class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {"email": email, "password": password};
}

/// How far a signup got. The server decides this and the app renders the
/// matching screen — nothing here is inferred from which lookups succeed,
/// which is what used to drop half-finished users on the home screen.
enum OnboardingStage {
  emailVerification,
  role,
  profile,
  vehicle,
  kyc,

  /// Verified, promoted, and holding a real token — an account exists.
  complete;

  static OnboardingStage parse(String? raw) {
    switch (raw) {
      case 'EMAIL_VERIFICATION':
        return OnboardingStage.emailVerification;
      case 'ROLE':
        return OnboardingStage.role;
      case 'PROFILE':
        return OnboardingStage.profile;
      case 'VEHICLE':
        return OnboardingStage.vehicle;
      case 'KYC':
        return OnboardingStage.kyc;
      case 'COMPLETE':
        return OnboardingStage.complete;
      default:
        // An unknown stage must never read as "finished" — that would be a
        // free pass into the app.
        return OnboardingStage.emailVerification;
    }
  }
}

/// The reply to every onboarding call: where the signup stands and what the
/// app needs to continue. [token] is non-empty only at
/// [OnboardingStage.complete], because a session can't exist before the
/// account does.
class OnboardingState {
  final OnboardingStage stage;
  final String onboardingToken;
  final String token;
  final String email;
  final String? role;
  final String? gender;
  final KycStatusResponse? kyc;

  const OnboardingState({
    required this.stage,
    this.onboardingToken = '',
    this.token = '',
    this.email = '',
    this.role,
    this.gender,
    this.kyc,
  });

  bool get isComplete => stage == OnboardingStage.complete && token.isNotEmpty;

  factory OnboardingState.fromJson(Map<String, dynamic> json) {
    final kycJson = json['kyc'];
    return OnboardingState(
      stage: OnboardingStage.parse(json['stage']?.toString()),
      onboardingToken: (json['onboardingToken'] ?? '').toString(),
      token: (json['token'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: json['role']?.toString(),
      gender: json['gender']?.toString(),
      kyc: kycJson is Map<String, dynamic>
          ? KycStatusResponse.fromJson(kycJson)
          : null,
    );
  }
}

class LoginResponse {
  /// Empty for anyone who hasn't finished signing up — see [onboardingStage].
  final String token;

  /// Where the credentials' owner stands. [OnboardingStage.complete] means a
  /// real account answered and [token] is usable; anything else means the
  /// address belongs to a signup still in flight, and the app reopens that
  /// step instead of showing an error. Rescuing a half-finished signup this
  /// way is the only route back for someone who reinstalled the app.
  final OnboardingStage onboardingStage;
  final String userId;
  final String onboardingToken;

  LoginResponse({
    required this.token,
    this.onboardingStage = OnboardingStage.complete,
    this.userId = '',
    this.onboardingToken = '',
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: (json['token'] ?? '').toString(),
      onboardingStage: OnboardingStage.parse(json['onboardingStage']?.toString()),
      userId: (json['userId'] ?? '').toString(),
      onboardingToken: (json['onboardingToken'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    "token": token,
    "onboardingStage": onboardingStage.name,
    "userId": userId,
    "onboardingToken": onboardingToken,
  };
}

// reset Password
class ResetPasswordDto {
  final String token;
  final String newPassword;

  ResetPasswordDto({required this.token, required this.newPassword});

  Map<String, dynamic> toJson() => {
    "token": token,
    "newPassword": newPassword,
  };
}

class ForgotPassword {
  final String email;

  ForgotPassword({required this.email});

  Map<String, dynamic> toJson() => {"email": email};
}
