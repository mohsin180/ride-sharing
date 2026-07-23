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
  /// isn't the host (backend should return 403/404). Cancelling is free
  /// until the driver reaches the pickup (ride ARRIVED); after that the
  /// returned [CancellationResult] carries the flat fee recorded.
  Future<CancellationResult> cancelRide(String id, {String? reason}) async {
    final json = await apiclient.post(
      Apiconsonants.cancelRideEndpoint(id),
      {if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()},
    );
    if (json is Map<String, dynamic>) {
      return CancellationResult.fromJson(json);
    }
    // Older/empty response — treat as a free cancellation.
    return const CancellationResult(fee: 0, currency: 'PKR', strikeCount: 0);
  }

  /// Host publishes the ride to the driver feed (drivers can then accept it,
  /// even if all passenger seats are taken). Backend rejects if the caller
  /// isn't the host or the ride is no longer PENDING.
  Future<void> publishRide(String id) async {
    await apiclient.post(Apiconsonants.publishRideEndpoint(id), const {});
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
    int? seats,
  }) async {
    await apiclient.post(Apiconsonants.joinRideEndpoint(id), {
      if (pickup != null) 'pickup': pickup,
      if (pickupLat != null) 'pickupLat': pickupLat,
      if (pickupLng != null) 'pickupLng': pickupLng,
      if (drop != null) 'drop': drop,
      if (dropLat != null) 'dropLat': dropLat,
      if (dropLng != null) 'dropLng': dropLng,
      if (seats != null) 'seats': seats,
    });
  }

  /// Host accepts a co-passenger's join request — the requester then joins.
  Future<void> acceptJoinRequest(String rideId, String requestId) async {
    await apiclient.post(
      Apiconsonants.acceptJoinRequestEndpoint(rideId, requestId),
      const {},
    );
  }

  /// Host accepts a driver's offer — that driver is assigned and the ride
  /// moves to ACCEPTED.
  Future<void> acceptDriverOffer(String rideId, String offerId) async {
    await apiclient.post(
      Apiconsonants.acceptDriverOfferEndpoint(rideId, offerId),
      const {},
    );
  }

  /// Host declines a driver's offer.
  Future<void> declineDriverOffer(String rideId, String offerId) async {
    await apiclient.post(
      Apiconsonants.declineDriverOfferEndpoint(rideId, offerId),
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
    double? dropLat,
    double? dropLng,
    int? seats,
  }) async {
    final json = await apiclient.get(
      Apiconsonants.availableRidesEndpoint(
          lat: lat, lng: lng, dropLat: dropLat, dropLng: dropLng, seats: seats),
    );
    if (json is! List) return const [];
    return json
        .whereType<Map<String, dynamic>>()
        .map(AvailableRide.fromJson)
        .toList(growable: false);
  }

  // ── driver ride-lifecycle ──────────────────────────────────────

  /// Fresh ride requests the authenticated driver can claim. Re-uses the
  /// [AvailableRide] DTO (same on-screen shape as the passenger feed). Passes
  /// the driver's current location so the backend can bound the feed by
  /// proximity and stamp each ride with a distanceKm; pass null on both when
  /// no fix is available and the backend returns the full pending feed.
  Future<List<AvailableRide>> getDriverFeed({double? lat, double? lng}) async {
    final json = await apiclient.get(
      Apiconsonants.driverFeedEndpoint(lat: lat, lng: lng),
    );
    if (json is! List) return const [];
    return json
        .whereType<Map<String, dynamic>>()
        .map(AvailableRide.fromJson)
        .toList(growable: false);
  }

  /// Driver OFFERS to drive a PENDING ride — does NOT assign them. The host
  /// gets a notification to accept or decline. Throws (via `ApiException`)
  /// when the ride was just taken, is the driver's own ride, a duplicate
  /// offer, or the driver already has an active ride — the 409 message
  /// surfaces in the UI. Body intentionally empty; the path identifies the ride.
  Future<void> offerToDrive(String id) async {
    await apiclient.post(
      Apiconsonants.offerToDriveEndpoint(id),
      const {},
    );
  }

  /// Driver dismisses a ride from their feed — recorded so it stays hidden
  /// for them on later polls.
  Future<void> driverDeclineRide(String id) async {
    await apiclient.post(Apiconsonants.driverDeclineRideEndpoint(id), const {});
  }

  /// TRUE fare preview for joining [id] with your own route + seats.
  Future<JoinFarePreview> getJoinFarePreview(
    String id, {
    required double pickupLat,
    required double pickupLng,
    required double dropLat,
    required double dropLng,
    int seats = 1,
  }) async {
    final json = await apiclient.get(Apiconsonants.farePreviewEndpoint(id,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropLat: dropLat,
        dropLng: dropLng,
        seats: seats));
    return JoinFarePreview.fromJson(json as Map<String, dynamic>);
  }

  /// The host's before/after fare picture for a pending join request.
  Future<HostAcceptFarePreview> getAcceptFarePreview(
      String rideId, String requestId) async {
    final json = await apiclient
        .get(Apiconsonants.acceptFarePreviewEndpoint(rideId, requestId));
    return HostAcceptFarePreview.fromJson(json as Map<String, dynamic>);
  }

  /// Assigned driver marks a rider as picked up (in the vehicle).
  Future<void> markRiderPickedUp(String rideId, String riderId) async {
    await apiclient.post(
        Apiconsonants.riderPickupEndpoint(rideId, riderId), const {});
  }

  /// Assigned driver drops a rider at their stop — settles their cash fare.
  Future<void> markRiderDroppedOff(String rideId, String riderId) async {
    await apiclient.post(
        Apiconsonants.riderDropoffEndpoint(rideId, riderId), const {});
  }

  /// Report another user for misconduct on a ride.
  Future<void> reportUser(String rideId, String reportedUserId,
      {String? reason}) async {
    await apiclient.post(Apiconsonants.reportUserEndpoint(rideId), {
      'reportedUserId': reportedUserId,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }

  /// Block another user — they no longer appear in each other's matching.
  Future<void> blockUser(String userId) async {
    await apiclient.post(Apiconsonants.blockUserEndpoint(userId), const {});
  }

  /// Moves an ACCEPTED ride → ARRIVED (driver reached the pickup). Only the
  /// assigned driver may call; every rider's screen flips to "driver arrived".
  Future<RideResponse> arriveRide(String id) async {
    final json = await apiclient.post(
      Apiconsonants.arriveRideEndpoint(id),
      const {},
    );
    return RideResponse.fromJson(json as Map<String, dynamic>);
  }

  /// Moves an ACCEPTED/ARRIVED ride → STARTED. Only the assigned driver may call.
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

  /// A ride's cash fare ledger — one entry per rider. Any member may read it
  /// (driver collects; riders see their own paid state).
  Future<List<RidePaymentEntry>> getRidePayments(String id) async {
    final json = await apiclient.get(Apiconsonants.ridePaymentsEndpoint(id));
    if (json is List) {
      return json
          .whereType<Map<String, dynamic>>()
          .map(RidePaymentEntry.fromJson)
          .toList();
    }
    return const [];
  }

  /// The assigned driver confirms they collected a rider's cash fare.
  Future<RidePaymentEntry> collectPayment(String id, String riderId) async {
    final json = await apiclient.post(
      Apiconsonants.collectPaymentEndpoint(id, riderId),
      const {},
    );
    return RidePaymentEntry.fromJson(json as Map<String, dynamic>);
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

  /// Driver ride history (completed + cancelled). Backend infers the
  /// driver from the JWT. Contract: see [DriverRideHistory].
  Future<List<DriverRideHistory>> getDriverHistory() async {
    final json = await apiclient.get(Apiconsonants.driverHistoryEndpoint);
    if (json is! List) return const [];
    return json
        .whereType<Map<String, dynamic>>()
        .map(DriverRideHistory.fromJson)
        .toList(growable: false);
  }

  /// The driver's earnings summary (today + lifetime) for the home
  /// dashboard. Contract: see [DriverEarnings].
  Future<DriverEarnings> getDriverEarnings() async {
    final json = await apiclient.get(Apiconsonants.driverEarningsEndpoint);
    return DriverEarnings.fromJson(json as Map<String, dynamic>);
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
