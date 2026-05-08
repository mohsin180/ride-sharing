import 'package:ride_sharing/controller/apiClient.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/widgets/consonants/apiConsonants.dart';

class Rideservice {
  final Apiclient apiclient;
  Rideservice({required this.apiclient});

  /// Aggregate stats (trip count + average rating) for the authenticated
  /// user. Same endpoint serves passengers and drivers — backend
  /// disambiguates by role from the JWT.
  Future<RideStats> getMyStats() async {
    final json = await apiclient.get(Apiconsonants.rideStatsEndpoint);
    return RideStats.fromJson(json as Map<String, dynamic>);
  }

  /// Creates a new passenger ride request. The backend assigns the ID,
  /// sets `status: PENDING`, and starts looking for matching drivers.
  /// Backend contract: see [CreateRideRequest] / [RideResponse].
  Future<RideResponse> createRide(CreateRideRequest request) async {
    final json = await apiclient.post(
      Apiconsonants.createRideEndpoint,
      request.toJson(),
    );
    return RideResponse.fromJson(json as Map<String, dynamic>);
  }
}
