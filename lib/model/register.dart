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
