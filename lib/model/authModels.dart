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

class LoginResponse {
  /// Empty when the account still has no role — see [roleRequired].
  final String token;

  /// True when the credentials were correct but signup was never finished.
  /// The app then sends the user to role selection instead of showing an
  /// error, which is the only way to rescue an account whose app was killed
  /// mid-signup.
  final bool roleRequired;
  final String userId;
  final String onboardingToken;

  LoginResponse({
    required this.token,
    this.roleRequired = false,
    this.userId = '',
    this.onboardingToken = '',
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: (json['token'] ?? '').toString(),
      roleRequired: json['roleRequired'] == true,
      userId: (json['userId'] ?? '').toString(),
      onboardingToken: (json['onboardingToken'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    "token": token,
    "roleRequired": roleRequired,
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
