class Apiconsonants {
  // user-service endpoints
  static const String userServicebaseUrl = "http://localhost:8080/api/v1/auth";
  static const String registerEndpoint = "$userServicebaseUrl/register";
  static const String loginEndpoint = "$userServicebaseUrl/login";
  static const String forgotPasswordEndpoint =
      "$userServicebaseUrl/forgot-password";
  static const String resetPasswordEndpoint =
      "$userServicebaseUrl/reset-password";
  static const String resetStatusEndpoint = "$userServicebaseUrl/reset/status";
  static const String selectedRoleEndpoint = "$userServicebaseUrl/select-role";
  // profile-service endpoints
  static const String profileServicebaseUrl =
      "http://localhost:8080/api/v1/profile";
  static const String createPassengerProfileEndpoint =
      "$profileServicebaseUrl/passenger";
  static const String createDriverProfileEndpoint =
      "$profileServicebaseUrl/driver";
}
