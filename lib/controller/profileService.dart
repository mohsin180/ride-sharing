import 'package:ride_sharing/controller/apiClient.dart';
import 'package:ride_sharing/model/profileModels.dart';
import 'package:ride_sharing/widgets/consonants/apiConsonants.dart';

class Profileservice {
  final Apiclient apiclient;

  Profileservice({required this.apiclient});

  // profile creation for passengers
  Future<PassengerProfileResponse> createPassengerProfile(
    PassengerProfileRequest request,
  ) async {
    final json = await apiclient.post(
      Apiconsonants.createPassengerProfileEndpoint,
      request.toJson(),
    );
    return PassengerProfileResponse.fromJson(json as Map<String, dynamic>);
  }

  // profile creation for drivers
  Future<DriverProfileResponse> createDriverProfile(
    DriverProfileRequest request,
  ) async {
    final json = await apiclient.post(
      Apiconsonants.createDriverProfileEndpoint,
      request.toJson(),
    );
    return DriverProfileResponse.fromJson(json as Map<String, dynamic>);
  }

  /// Fetches the currently-authenticated passenger's profile. The user is
  /// identified by the JWT (auto-attached by [Apiclient]); no userId in
  /// the path or body.
  Future<PassengerProfileResponse> getPassengerProfile() async {
    final json = await apiclient.get(Apiconsonants.getPassengerProfileEndpoint);
    return PassengerProfileResponse.fromJson(json as Map<String, dynamic>);
  }

  /// Updates the authenticated passenger's profile. Backend contract:
  /// `PUT /api/v1/profile/passenger` with the same body shape as create
  /// — `{ fullName, phoneNo, cnic }`. Email and gender are *not* edited
  /// here (email change typically requires re-verification; gender is
  /// fixed at signup).
  Future<PassengerProfileResponse> updatePassengerProfile(
    PassengerProfileRequest request,
  ) async {
    final json = await apiclient.put(
      Apiconsonants.updatePassengerProfileEndpoint,
      request.toJson(),
    );
    return PassengerProfileResponse.fromJson(json as Map<String, dynamic>);
  }

  /// Fetches the currently-authenticated driver's profile (incl. vehicle).
  /// Same JWT-based identification as the passenger endpoint.
  Future<DriverProfileResponse> getDriverProfile() async {
    final json = await apiclient.get(Apiconsonants.getDriverProfileEndpoint);
    return DriverProfileResponse.fromJson(json as Map<String, dynamic>);
  }

  /// Updates the authenticated driver's profile. Backend contract:
  /// `PUT /api/v1/profile/driver` with the same body shape as create —
  /// `{ fullName, phoneNo, cnic, vehicle: {...} }`. Email and gender
  /// are intentionally not editable here.
  Future<DriverProfileResponse> updateDriverProfile(
    DriverProfileRequest request,
  ) async {
    final json = await apiclient.put(
      Apiconsonants.updateDriverProfileEndpoint,
      request.toJson(),
    );
    return DriverProfileResponse.fromJson(json as Map<String, dynamic>);
  }
}
