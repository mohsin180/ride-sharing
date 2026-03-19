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
    return PassengerProfileResponse.fromJson(json);
  }

  // profile creation for drivers
  Future<DriverProfileResponse> createDriverProfile(
    DriverProfileRequest request,
  ) async {
    final json = await apiclient.post(
      Apiconsonants.createDriverProfileEndpoint,
      request.toJson(),
    );
    return DriverProfileResponse.fromJson(json);
  }
}
