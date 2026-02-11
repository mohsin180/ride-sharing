// register models
class RegisterRequest {
  String username;
  String email;
  String password;
  String phoneNo;
  String gender;
  RegisterRequest({
    required this.username,
    required this.email,
    required this.password,
    required this.phoneNo,
    required this.gender,
  });

  Map<String, dynamic> toJson() {
    return {
      "username": username,
      "email": email,
      "password": password,
      "phoneNo": phoneNo,
      "gender": gender,
    };
  }
}

class RegisterResponse {
  final String username;
  final String email;
  final String gender;
  final String userId;

  RegisterResponse({
    required this.username,
    required this.email,
    required this.gender,
    required this.userId,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(
      username: json["username"],
      email: json["email"],
      gender: json["gender"],
      userId: json["keycloakId"],
    );
  }
}

// login Models
class LoginRequest {
  final String email;
  final String password;
  LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

class LoginResponse {
  final String acessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  LoginResponse({
    required this.acessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      acessToken: json['access_token'],
      refreshToken: json['refresh_token'],
      tokenType: json['token_type'],
      expiresIn: json['expires_in'],
    );
  }
}

// reset Password
class ResetPasswordDto {
  final String token;
  final String newPassword;

  ResetPasswordDto({required this.token, required this.newPassword});

  Map<String, dynamic> toJson() => {'token': token, 'newPassword': newPassword};
}

class ForgotPassword {
  final String email;

  ForgotPassword({required this.email});

  Map<String, dynamic> toJson() => {"email": email};
}
