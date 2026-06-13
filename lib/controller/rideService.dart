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

  /// Fetches the full details of one ride by id — host, route, fare,
  /// who's joined. Drives the viewRequest screen.
  /// Contract: see [RideDetails].
  Future<RideDetails> getRideDetails(String id) async {
    final json = await apiclient.get(Apiconsonants.rideDetailsEndpoint(id));
    return RideDetails.fromJson(json as Map<String, dynamic>);
  }

  /// Passenger ride history (completed + cancelled). Backend infers
  /// the role from the JWT so we don't pass it explicitly here.
  /// Contract: see [PassengerRideHistoryItem].
  Future<List<PassengerRideHistoryItem>> getPassengerRideHistory() async {
    final json = await apiclient.get(Apiconsonants.rideHistoryEndpoint);
    if (json is! List) return const [];
    return json
        .whereType<Map<String, dynamic>>()
        .map(PassengerRideHistoryItem.fromJson)
        .toList(growable: false);
  }

  /// Lists rides the authenticated user *created* and that are still
  /// active (PENDING / ACCEPTED). Re-uses the [AvailableRide] DTO
  /// because the on-screen shape is identical — the only difference
  /// is which user the rides belong to.
  Future<List<AvailableRide>> getMyRides() async {
    final json = await apiclient.get(Apiconsonants.myRidesEndpoint);
    if (json is! List) return const [];
    return json
        .whereType<Map<String, dynamic>>()
        .map(AvailableRide.fromJson)
        .toList(growable: false);
  }

  /// Cancels a ride the authenticated user hosts. Throws if the user
  /// isn't the host (backend should return 403/404). Body intentionally
  /// empty — the URL path identifies the ride.
  Future<void> cancelRide(String id) async {
    await apiclient.post(Apiconsonants.cancelRideEndpoint(id), const {});
  }

  /// Requests to join a ride — this does NOT add the rider; the host gets a
  /// notification to accept or decline. Sends the rider's OWN route so the
  /// host can see where they're headed. Throws (409 message via
  /// `ApiException`) when full, already joined, already requested, or the
  /// rider is in another active ride.
  Future<void> requestToJoin(
    String id, {
    String? pickup,
    double? pickupLat,
    double? pickupLng,
    String? drop,
    double? dropLat,
    double? dropLng,
  }) async {
    await apiclient.post(Apiconsonants.joinRideEndpoint(id), {
      if (pickup != null) 'pickup': pickup,
      if (pickupLat != null) 'pickupLat': pickupLat,
      if (pickupLng != null) 'pickupLng': pickupLng,
      if (drop != null) 'drop': drop,
      if (dropLat != null) 'dropLat': dropLat,
      if (dropLng != null) 'dropLng': dropLng,
    });
  }

  /// Host accepts a co-passenger's join request — the requester then joins.
  Future<void> acceptJoinRequest(String rideId, String requestId) async {
    await apiclient.post(
      Apiconsonants.acceptJoinRequestEndpoint(rideId, requestId),
      const {},
    );
  }

  /// Host declines a co-passenger's join request.
  Future<void> declineJoinRequest(String rideId, String requestId) async {
    await apiclient.post(
      Apiconsonants.declineJoinRequestEndpoint(rideId, requestId),
      const {},
    );
  }

  /// Leaves a ride the user previously joined. Throws if the user
  /// isn't a participant of the ride (backend 409).
  Future<void> leaveRide(String id) async {
    await apiclient.post(Apiconsonants.leaveRideEndpoint(id), const {});
  }

  /// Lists rides created by other passengers that the authenticated
  /// user can join. Passes the user's current location so the backend
  /// can rank by proximity and stamp each ride with a distanceKm —
  /// pass null on both when no fix is available; backend then leaves
  /// the distance field null and the UI falls back to "—".
  /// Contract: see [AvailableRide].
  Future<List<AvailableRide>> getAvailableRides({
    double? lat,
    double? lng,
  }) async {
    final json = await apiclient.get(
      Apiconsonants.availableRidesEndpoint(lat: lat, lng: lng),
    );
    if (json is! List) return const [];
    return json
        .whereType<Map<String, dynamic>>()
        .map(AvailableRide.fromJson)
        .toList(growable: false);
  }

  // ── driver ride-lifecycle ──────────────────────────────────────

  /// Fresh ride requests the authenticated driver can claim. Re-uses the
  /// [AvailableRide] DTO (same on-screen shape as the passenger feed);
  /// distanceKm / etaMinutes come back null.
  Future<List<AvailableRide>> getDriverFeed() async {
    final json = await apiclient.get(Apiconsonants.driverFeedEndpoint);
    if (json is! List) return const [];
    return json
        .whereType<Map<String, dynamic>>()
        .map(AvailableRide.fromJson)
        .toList(growable: false);
  }

  /// Claims a PENDING ride as its driver. Throws (via `ApiException`)
  /// when the ride was just taken, is the driver's own ride, or the
  /// driver already has an active ride — the 409 message surfaces in
  /// the UI. Body intentionally empty; the path identifies the ride.
  Future<RideResponse> acceptRide(String id) async {
    final json = await apiclient.post(
      Apiconsonants.acceptRideEndpoint(id),
      const {},
    );
    return RideResponse.fromJson(json as Map<String, dynamic>);
  }

  /// Moves an ACCEPTED ride → STARTED. Only the assigned driver may call.
  Future<RideResponse> startRide(String id) async {
    final json = await apiclient.post(
      Apiconsonants.startRideEndpoint(id),
      const {},
    );
    return RideResponse.fromJson(json as Map<String, dynamic>);
  }

  /// Moves a STARTED ride → COMPLETED. Only the assigned driver may call.
  Future<RideResponse> completeRide(String id) async {
    final json = await apiclient.post(
      Apiconsonants.completeRideEndpoint(id),
      const {},
    );
    return RideResponse.fromJson(json as Map<String, dynamic>);
  }

  /// The assigned driver backs out — the ride re-opens (PENDING) for
  /// another driver; passengers keep their ride.
  Future<void> driverCancelRide(String id) async {
    await apiclient.post(Apiconsonants.driverCancelRideEndpoint(id), const {});
  }

  /// The ride(s) the authenticated driver is currently running
  /// (ACCEPTED / STARTED), as full [RideDetails] for the active-trip
  /// cockpit. Empty when the driver isn't on a trip.
  Future<List<RideDetails>> getDriverActiveRides() async {
    final json = await apiclient.get(Apiconsonants.driverActiveRidesEndpoint);
    if (json is! List) return const [];
    return json
        .whereType<Map<String, dynamic>>()
        .map(RideDetails.fromJson)
        .toList(growable: false);
  }

  /// The passenger's in-progress trip (ACCEPTED / STARTED), hosted or
  /// joined — drives the passenger live-tracking screen. Empty when not
  /// on a trip.
  Future<List<RideDetails>> getMyActiveTrip() async {
    final json = await apiclient.get(Apiconsonants.myActiveTripEndpoint);
    if (json is! List) return const [];
    return json
        .whereType<Map<String, dynamic>>()
        .map(RideDetails.fromJson)
        .toList(growable: false);
  }

  // ── ratings (post-trip) ────────────────────────────────────────

  /// A passenger rates the driver of a completed ride (1–5 stars). Throws
  /// (via `ApiException`) on 409 — already rated, or the ride isn't
  /// completed. Backend resolves the driver from the ride.
  Future<void> rateDriver(String rideId, int stars) async {
    await apiclient.post(
      Apiconsonants.rateDriverEndpoint(rideId),
      {"stars": stars},
    );
  }

  /// The driver rates one passenger of a completed ride (1–5 stars).
  Future<void> ratePassenger(String rideId, String ratedId, int stars) async {
    await apiclient.post(
      Apiconsonants.ratePassengerEndpoint(rideId),
      {"ratedId": ratedId, "stars": stars},
    );
  }

  /// A passenger rates a co-passenger (1–5 stars). Used at leave-time —
  /// works on an active ride and for members who already left.
  Future<void> rateCoPassenger(String rideId, String ratedId, int stars) async {
    await apiclient.post(
      Apiconsonants.rateCoPassengerEndpoint(rideId),
      {"ratedId": ratedId, "stars": stars},
    );
  }

  // ── driver availability ────────────────────────────────────────

  /// The driver's persisted online/offline status. Defaults to offline
  /// when the backend has no record yet.
  Future<bool> getDriverStatus() async {
    final json = await apiclient.get(Apiconsonants.driverStatusEndpoint);
    return json is Map && json["online"] == true;
  }

  /// Marks the driver online; returns the resulting online flag.
  Future<bool> goOnline() async {
    final json = await apiclient.post(
      Apiconsonants.driverGoOnlineEndpoint,
      const {},
    );
    return json is Map && json["online"] == true;
  }

  /// Marks the driver offline; returns the resulting online flag.
  Future<bool> goOffline() async {
    final json = await apiclient.post(
      Apiconsonants.driverGoOfflineEndpoint,
      const {},
    );
    return json is Map && json["online"] == true;
  }
}
