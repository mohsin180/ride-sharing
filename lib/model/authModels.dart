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

  RegisterResponse({required this.id, required this.email});

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {"id": id, "email": email};
}

// login Models
class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {"email": email, "password": password};
}

class LoginResponse {
  final String token;

  LoginResponse({required this.token});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(token: (json['token'] ?? '').toString());
  }

  Map<String, dynamic> toJson() => {"token": token};
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
