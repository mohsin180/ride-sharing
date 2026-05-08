import 'package:ride_sharing/widgets/consonants/env.dart';

/// Single source of truth for backend endpoints. The host comes from
/// `.env` (`API_BASE_URL`) so the same build works against localhost,
/// LAN, staging, or prod without recompiling.
class Apiconsonants {
  Apiconsonants._();

  static String get baseUrl => Env.apiBaseUrl;
  

  // ── user-service endpoints ─────────────────────────────────────
  static String get userServicebaseUrl => "$baseUrl/auth";
  static String get registerEndpoint => "$userServicebaseUrl/register";
  static String get loginEndpoint => "$userServicebaseUrl/login";
  static String get forgotPasswordEndpoint =>
      "$userServicebaseUrl/forgot-password";
  static String get resetPasswordEndpoint =>
      "$userServicebaseUrl/reset-password";
  static String get resetStatusEndpoint => "$userServicebaseUrl/reset/status";
  static String get verifyEmailEndpoint => "$userServicebaseUrl/verify-email";

  static String isEmailVerifiedEndpoint(String userId) =>
      "$userServicebaseUrl/is-email-verified/$userId";

  static String selectRoleEndpoint(String userId) =>
      "$userServicebaseUrl/$userId/select-role";

  // ── profile-service endpoints ──────────────────────────────────
  static String get profileServicebaseUrl => "$baseUrl/profile";
  static String get createPassengerProfileEndpoint =>
      "$profileServicebaseUrl/passenger";
  static String get createDriverProfileEndpoint =>
      "$profileServicebaseUrl/driver";
  static String get getPassengerProfileEndpoint =>
      "$profileServicebaseUrl/passenger";
  static String get getDriverProfileEndpoint =>
      "$profileServicebaseUrl/driver";
  static String get updatePassengerProfileEndpoint =>
      "$profileServicebaseUrl/passenger";
  static String get updateDriverProfileEndpoint =>
      "$profileServicebaseUrl/driver";

  // ── ride-service endpoints ─────────────────────────────────────
  static String get rideServicebaseUrl => "$baseUrl/rides";

  /// Stats for the authenticated user (role inferred from JWT).
  /// Response shape documented on [RideStats].
  static String get rideStatsEndpoint => "$rideServicebaseUrl/stats";

  /// `POST` to create a passenger ride request. Request shape documented
  /// on [CreateRideRequest]; response on [RideResponse].
  static String get createRideEndpoint => rideServicebaseUrl;
}
