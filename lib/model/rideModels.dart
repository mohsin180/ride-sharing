/// Aggregate ride statistics for the authenticated user. Returned by
/// `GET /api/v1/rides/stats` — role (passenger vs driver) is inferred
/// from the JWT, so the same endpoint serves both.
///
/// Backend contract:
///   {
///     "trips":  24,        // int, count of COMPLETED rides for this user
///                          //   passenger → rides taken
///                          //   driver    → rides offered
///     "rating": 4.8        // double 1.0–5.0, average across all ratings;
///                          //   nullable: omit (or send null) for users
///                          //   who haven't been rated yet
///   }
class RideStats {
  /// Count of completed rides for the authenticated user.
  final int trips;

  /// Average rating, 1.0–5.0. Null when the user has no ratings yet.
  final double? rating;

  const RideStats({required this.trips, this.rating});

  factory RideStats.fromJson(Map<String, dynamic> json) {
    final rawTrips = json['trips'];
    final rawRating = json['rating'];
    return RideStats(
      trips: rawTrips is num ? rawTrips.toInt() : 0,
      rating: rawRating is num ? rawRating.toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() => {
    "trips": trips,
    if (rating != null) "rating": rating,
  };
}

/// Lifecycle of a passenger's ride request, from initial creation through
/// completion. Backend should send the uppercase string (`"PENDING"`,
/// `"ACCEPTED"`, …); the parser falls back to [RideStatus.unknown] for
/// values the client doesn't recognise (so a future backend status doesn't
/// crash older app versions).
enum RideStatus {
  pending,
  accepted,
  started,
  completed,
  cancelled,
  unknown;

  static RideStatus fromWire(String? raw) {
    switch (raw?.toUpperCase()) {
      case 'PENDING':
        return RideStatus.pending;
      case 'ACCEPTED':
        return RideStatus.accepted;
      case 'STARTED':
      case 'IN_PROGRESS':
        return RideStatus.started;
      case 'COMPLETED':
        return RideStatus.completed;
      case 'CANCELLED':
      case 'CANCELED':
        return RideStatus.cancelled;
      default:
        return RideStatus.unknown;
    }
  }

  String toWire() => switch (this) {
    RideStatus.pending => 'PENDING',
    RideStatus.accepted => 'ACCEPTED',
    RideStatus.started => 'STARTED',
    RideStatus.completed => 'COMPLETED',
    RideStatus.cancelled => 'CANCELLED',
    RideStatus.unknown => 'UNKNOWN',
  };
}

/// Body for `POST /api/v1/rides` — passenger requests a ride.
///
/// Backend contract:
///   {
///     "pickup":    "Hostel City, Block B",
///     "drop":      "Faizabad Metro",
///     "pickupLat": 33.6844,
///     "pickupLng": 73.0479,
///     "dropLat":   33.6620,
///     "dropLng":   73.0708,
///     "seats":     2,                 // 1..6
///     "rideType":  "ECONOMY"          // "ECONOMY" | "PREMIUM"
///   }
class CreateRideRequest {
  final String pickup;
  final String drop;
  final double pickupLat;
  final double pickupLng;
  final double dropLat;
  final double dropLng;
  final int seats;
  final String rideType;

  const CreateRideRequest({
    required this.pickup,
    required this.drop,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropLat,
    required this.dropLng,
    required this.seats,
    required this.rideType,
  });

  Map<String, dynamic> toJson() => {
    "pickup": pickup,
    "drop": drop,
    "pickupLat": pickupLat,
    "pickupLng": pickupLng,
    "dropLat": dropLat,
    "dropLng": dropLng,
    "seats": seats,
    "rideType": rideType,
  };
}

/// Response shape for `POST /api/v1/rides` (and any other endpoint that
/// echoes a single ride). Tolerant of missing fields — the only thing
/// strictly required for the UI to function is `id`.
class RideResponse {
  final String id;
  final String? passengerId;
  final String? driverId;
  final String pickup;
  final String drop;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropLat;
  final double? dropLng;
  final int seats;
  final String rideType;
  final RideStatus status;
  final DateTime? createdAt;

  const RideResponse({
    required this.id,
    this.passengerId,
    this.driverId,
    required this.pickup,
    required this.drop,
    this.pickupLat,
    this.pickupLng,
    this.dropLat,
    this.dropLng,
    required this.seats,
    required this.rideType,
    required this.status,
    this.createdAt,
  });

  factory RideResponse.fromJson(Map<String, dynamic> json) {
    String? readString(String key) {
      final v = json[key];
      if (v == null) return null;
      final s = v.toString();
      return s.isEmpty ? null : s;
    }

    double? readDouble(String key) {
      final v = json[key];
      return v is num ? v.toDouble() : null;
    }

    DateTime? readDate(String key) {
      final raw = readString(key);
      if (raw == null) return null;
      return DateTime.tryParse(raw);
    }

    return RideResponse(
      id: (json["id"] ?? '').toString(),
      passengerId: readString("passengerId"),
      driverId: readString("driverId"),
      pickup: (json["pickup"] ?? '').toString(),
      drop: (json["drop"] ?? '').toString(),
      pickupLat: readDouble("pickupLat"),
      pickupLng: readDouble("pickupLng"),
      dropLat: readDouble("dropLat"),
      dropLng: readDouble("dropLng"),
      seats: json["seats"] is num ? (json["seats"] as num).toInt() : 1,
      rideType: (json["rideType"] ?? 'ECONOMY').toString(),
      status: RideStatus.fromWire(readString("status")),
      createdAt: readDate("createdAt"),
    );
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    if (passengerId != null) "passengerId": passengerId,
    if (driverId != null) "driverId": driverId,
    "pickup": pickup,
    "drop": drop,
    if (pickupLat != null) "pickupLat": pickupLat,
    if (pickupLng != null) "pickupLng": pickupLng,
    if (dropLat != null) "dropLat": dropLat,
    if (dropLng != null) "dropLng": dropLng,
    "seats": seats,
    "rideType": rideType,
    "status": status.toWire(),
    if (createdAt != null) "createdAt": createdAt!.toIso8601String(),
  };
}
