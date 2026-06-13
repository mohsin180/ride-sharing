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
  static String get resendVerificationEndpoint =>
      "$userServicebaseUrl/resend-verification";

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

  /// `GET` full details of one ride by id — used by viewRequest to
  /// render host, co-passengers, fare breakdown, route. Backend
  /// contract documented on [RideDetails].
  static String rideDetailsEndpoint(String id) => "$rideServicebaseUrl/$id";

  /// `GET` ride history for the authenticated user. Backend infers
  /// passenger vs. driver perspective from the JWT — same endpoint
  /// serves both roles. Returns rides that are COMPLETED or CANCELLED
  /// (in-flight rides live in the active-trip screens).
  /// Contract: see [PassengerRideHistoryItem] for the passenger shape.
  static String get rideHistoryEndpoint => "$rideServicebaseUrl/history";

  /// `GET` the list of rides the authenticated user *created* and that
  /// are still active (status PENDING / ACCEPTED — not completed or
  /// cancelled). Drives the "Your Rides" tab on the rides screen so
  /// hosts can see the trips they're running.
  static String get myRidesEndpoint => "$rideServicebaseUrl/mine";

  /// `POST` to cancel a ride the authenticated user hosts. Backend
  /// must reject if the caller isn't the host. Returns 204 / the
  /// updated ride — frontend just invalidates [myRidesProvider] on
  /// success and re-reads.
  static String cancelRideEndpoint(String id) =>
      "$rideServicebaseUrl/$id/cancel";

  /// `POST` to join a ride as a co-passenger. Backend must:
  ///   - reject if the caller is the host (can't join your own ride)
  ///   - reject if seats are full
  ///   - reject if the caller has already joined
  ///   - add the caller to the ride's participants
  /// Returns 204 / the updated ride.
  static String joinRideEndpoint(String id) =>
      "$rideServicebaseUrl/$id/join";

  /// `POST` (host) accepts a co-passenger's join request → they join.
  static String acceptJoinRequestEndpoint(String rideId, String requestId) =>
      "$rideServicebaseUrl/$rideId/join-requests/$requestId/accept";

  /// `POST` (host) declines a co-passenger's join request.
  static String declineJoinRequestEndpoint(String rideId, String requestId) =>
      "$rideServicebaseUrl/$rideId/join-requests/$requestId/decline";

  /// `POST` to leave a ride the authenticated user previously joined.
  /// Backend removes the caller from participants and frees a seat.
  /// Reject if the caller hasn't joined this ride.
  static String leaveRideEndpoint(String id) =>
      "$rideServicebaseUrl/$id/leave";

  /// `GET` the list of rides created by other passengers that the
  /// authenticated user can join — backend filters out the user's own
  /// rides, completed/cancelled rides, and rides with no seats left.
  ///
  /// Optional `lat`/`lng` query params let the backend compute the
  /// per-ride distance from the passenger's current location for the
  /// "Nearest / under X km" sort & filter pills. When omitted, the
  /// backend leaves `distanceKm` null and the UI shows "—".
  static String availableRidesEndpoint({double? lat, double? lng}) {
    if (lat == null || lng == null) return "$rideServicebaseUrl/available";
    return "$rideServicebaseUrl/available?lat=$lat&lng=$lng";
  }

  // ── driver ride-lifecycle endpoints ────────────────────────────

  /// `GET` the fresh ride requests a driver can claim (status PENDING,
  /// seats left). Same JSON shape as [availableRidesEndpoint] —
  /// contract documented on [AvailableRide] — but distanceKm/etaMinutes
  /// come back null (no rider location to measure from).
  static String get driverFeedEndpoint => "$rideServicebaseUrl/driver/feed";

  /// `POST` to claim a PENDING ride as its driver. Backend sets the
  /// driverId + moves status → ACCEPTED. Rejects (409) the driver's own
  /// ride, an already-taken ride, or when the driver already has an
  /// active ride. Returns the updated [RideResponse].
  static String acceptRideEndpoint(String id) =>
      "$rideServicebaseUrl/$id/accept";

  /// `POST` to move an ACCEPTED ride → STARTED (driver en route /
  /// trip begun). Only the assigned driver may call it.
  static String startRideEndpoint(String id) =>
      "$rideServicebaseUrl/$id/start";

  /// `POST` to move a STARTED ride → COMPLETED. Only the assigned
  /// driver may call it; this is what surfaces the ride (with driver
  /// name + car) in the passenger's history.
  static String completeRideEndpoint(String id) =>
      "$rideServicebaseUrl/$id/complete";

  /// `POST` for the assigned driver to back out — the ride re-opens
  /// (PENDING) for another driver; passengers keep their ride.
  static String driverCancelRideEndpoint(String id) =>
      "$rideServicebaseUrl/$id/driver-cancel";

  /// `GET` the ride(s) the authenticated driver is currently running
  /// (ACCEPTED or STARTED), as full [RideDetails] for the active-trip
  /// cockpit.
  static String get driverActiveRidesEndpoint =>
      "$rideServicebaseUrl/driver/active";

  // ── ratings (post-trip, on a COMPLETED ride) ───────────────────

  /// `POST` a passenger's rating of the ride's driver. Body `{ "stars": 5 }`.
  /// Backend resolves the driver from the ride. 409 if already rated /
  /// the ride isn't completed.
  static String rateDriverEndpoint(String id) =>
      "$rideServicebaseUrl/$id/rate/driver";

  /// `POST` the driver's rating of one passenger on the ride.
  /// Body `{ "ratedId": "<uuid>", "stars": 5 }`.
  static String ratePassengerEndpoint(String id) =>
      "$rideServicebaseUrl/$id/rate/passenger";

  /// `POST` a passenger's rating of a co-passenger (leave-time, bidirectional).
  /// Body `{ "ratedId": "<uuid>", "stars": 5 }`. Works on an active or
  /// completed ride and recognizes members who already left.
  static String rateCoPassengerEndpoint(String id) =>
      "$rideServicebaseUrl/$id/rate/copassenger";

  // ── driver availability (online/offline) ───────────────────────

  /// `GET` the authenticated driver's persisted online/offline status.
  /// Response: `{ "online": true, "lastSeenAt": "..." }`.
  static String get driverStatusEndpoint => "$rideServicebaseUrl/driver/status";

  /// `POST` to mark the driver online. Returns the updated status.
  static String get driverGoOnlineEndpoint => "$rideServicebaseUrl/driver/online";

  /// `POST` to mark the driver offline. Returns the updated status.
  static String get driverGoOfflineEndpoint =>
      "$rideServicebaseUrl/driver/offline";

  // ── notification-service endpoints ─────────────────────────────
  static String get notificationServicebaseUrl => "$baseUrl/notifications";

  /// `GET` the authenticated user's notifications (newest first).
  /// Contract documented on [AppNotification].
  static String get notificationsEndpoint => notificationServicebaseUrl;

  /// `GET` the count of unread notifications — drives the bell badge.
  /// Response: `{ "count": 3 }`.
  static String get unreadCountEndpoint =>
      "$notificationServicebaseUrl/unread-count";

  /// `POST` to mark one notification read.
  static String markNotificationReadEndpoint(String id) =>
      "$notificationServicebaseUrl/$id/read";

  /// `POST` to mark every notification read (clears the badge).
  static String get markAllNotificationsReadEndpoint =>
      "$notificationServicebaseUrl/read-all";

  /// `DELETE` one notification permanently.
  static String deleteNotificationEndpoint(String id) =>
      "$notificationServicebaseUrl/$id";

  // ── messaging-service endpoints ────────────────────────────────
  static String get messagingServicebaseUrl => "$baseUrl/messages";

  /// `GET` the user's chats (one per ride), newest activity first.
  static String get myChatsEndpoint => "$messagingServicebaseUrl/chats";

  /// `GET` total unread message count — drives the messages-bell badge.
  static String get unreadMessagesCountEndpoint =>
      "$messagingServicebaseUrl/unread-count";

  /// `GET` full message history for a ride's chat (also marks it read).
  static String chatMessagesEndpoint(String rideId) =>
      "$messagingServicebaseUrl/$rideId";

  /// `POST` a text message to a ride's chat (REST fallback for WS).
  static String sendMessageEndpoint(String rideId) =>
      "$messagingServicebaseUrl/$rideId";

  /// `POST` to mark a ride's chat read.
  static String markChatReadEndpoint(String rideId) =>
      "$messagingServicebaseUrl/$rideId/read";

  /// STOMP WebSocket URL (same host as the REST API, ws:// scheme).
  /// e.g. http://host:8080/api/v1 → ws://host:8080/api/v1/messages/ws
  static String get chatWsUrl =>
      "${baseUrl.replaceFirst('http', 'ws')}/messages/ws";

  /// Live tracking shares the same messaging-service WebSocket endpoint —
  /// only the STOMP topic differs (`/topic/track.<rideId>`).
  static String get trackWsUrl => chatWsUrl;

  /// `GET` the passenger's in-progress trip (ACCEPTED/STARTED) for the live map.
  static String get myActiveTripEndpoint => "$rideServicebaseUrl/my/active";
}
