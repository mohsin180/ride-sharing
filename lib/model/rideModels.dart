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

  /// How many ratings the average is based on (0 when never rated).
  final int ratingCount;

  const RideStats({required this.trips, this.rating, this.ratingCount = 0});

  factory RideStats.fromJson(Map<String, dynamic> json) {
    final rawTrips = json['trips'];
    final rawRating = json['rating'];
    final rawCount = json['ratingCount'];
    return RideStats(
      trips: rawTrips is num ? rawTrips.toInt() : 0,
      rating: rawRating is num ? rawRating.toDouble() : null,
      ratingCount: rawCount is num ? rawCount.toInt() : 0,
    );
  }

  /// "4.8 (23)" / "New" — a one-glance rating label that won't read a
  /// single 5-star as a flat "5.0".
  String get ratingLabel {
    if (rating == null || ratingCount == 0) return 'New';
    return '${rating!.toStringAsFixed(1)} ($ratingCount)';
  }

  Map<String, dynamic> toJson() => {
    "trips": trips,
    if (rating != null) "rating": rating,
    "ratingCount": ratingCount,
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

/// One row in the passenger ride-history screen. Backed by
/// `GET /api/v1/rides/history` filtered to the authenticated user's
/// completed + cancelled rides.
///
/// Backend contract (one object per ride in the response array):
///   {
///     "id":          "uuid",
///     "pickup":      "Hostel City, Block B",
///     "drop":        "Taramri Chowk",
///     "status":      "COMPLETED" | "CANCELLED",
///     "completedAt": "2026-04-12T09:22:00Z",  // when ride ended/cancelled
///     "fare":        250,                     // double — what the user paid
///     "driverName":  "Ali Raza",              // nullable (cancelled rides)
///     "carInfo":     "Toyota · White",        // nullable (cancelled rides)
///     "ratingGiven": 4.9                      // double, nullable
///   }
class PassengerRideHistoryItem {
  final String id;
  final String pickup;
  final String drop;
  final RideStatus status;
  final DateTime? completedAt;
  final double fare;
  final String? driverName;
  final String? carInfo;
  final double? ratingGiven;

  const PassengerRideHistoryItem({
    required this.id,
    required this.pickup,
    required this.drop,
    required this.status,
    required this.fare,
    this.completedAt,
    this.driverName,
    this.carInfo,
    this.ratingGiven,
  });

  /// True for rides the user actually took (vs cancelled before start).
  /// Used by the screen to gate the fare + driver row.
  bool get isCompleted => status == RideStatus.completed;

  /// "12 Apr" — short month + day, locale-agnostic so we don't pull in
  /// `package:intl` just for one label.
  String get dateLabel {
    final dt = completedAt;
    if (dt == null) return '—';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  /// "09:22" — 24-hour HH:mm. Same locale-agnostic justification.
  String get timeLabel {
    final dt = completedAt;
    if (dt == null) return '—';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  factory PassengerRideHistoryItem.fromJson(Map<String, dynamic> json) {
    double? readDouble(String key) {
      final v = json[key];
      return v is num ? v.toDouble() : null;
    }

    DateTime? readDate(String key) {
      final raw = json[key];
      if (raw is! String || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    return PassengerRideHistoryItem(
      id: (json['id'] ?? '').toString(),
      pickup: (json['pickup'] ?? '').toString(),
      drop: (json['drop'] ?? '').toString(),
      status: RideStatus.fromWire(json['status'] as String?),
      completedAt: readDate('completedAt'),
      fare: readDouble('fare') ?? 0.0,
      driverName: json['driverName'] as String?,
      carInfo: json['carInfo'] as String?,
      ratingGiven: readDouble('ratingGiven'),
    );
  }
}

/// Host of a shared ride — the passenger who originally created it.
/// Returned as `host` on [RideDetails].
class RideHost {
  final String id;
  final String name;
  final double? rating;
  final int ratingCount;
  final int trips;
  final String? gender;

  const RideHost({
    required this.id,
    required this.name,
    required this.trips,
    this.rating,
    this.ratingCount = 0,
    this.gender,
  });

  /// "4.9 (12)" / "New" — rating with how many it's based on.
  String get ratingLabel {
    if (rating == null || ratingCount == 0) return 'New';
    return '${rating!.toStringAsFixed(1)} ($ratingCount)';
  }

  factory RideHost.fromJson(Map<String, dynamic> json) => RideHost(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        trips: json['trips'] is num ? (json['trips'] as num).toInt() : 0,
        rating: json['rating'] is num
            ? (json['rating'] as num).toDouble()
            : null,
        ratingCount: json['ratingCount'] is num
            ? (json['ratingCount'] as num).toInt()
            : 0,
        gender: json['gender'] as String?,
      );
}

/// One co-passenger sharing a ride — anyone who has joined besides
/// the host and the authenticated viewer. The backend's `coPassengers`
/// array on [RideDetails] is already filtered to exclude both.
class RideCoPassenger {
  final String id;
  final String name;
  final double? rating;
  final int ratingCount;
  final int trips;
  final String? gender;

  const RideCoPassenger({
    required this.id,
    required this.name,
    required this.trips,
    this.rating,
    this.ratingCount = 0,
    this.gender,
  });

  /// "4.7 (8)" / "New" — rating with how many it's based on.
  String get ratingLabel {
    if (rating == null || ratingCount == 0) return 'New';
    return '${rating!.toStringAsFixed(1)} ($ratingCount)';
  }

  factory RideCoPassenger.fromJson(Map<String, dynamic> json) =>
      RideCoPassenger(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        trips: json['trips'] is num ? (json['trips'] as num).toInt() : 0,
        rating: json['rating'] is num
            ? (json['rating'] as num).toDouble()
            : null,
        ratingCount: json['ratingCount'] is num
            ? (json['ratingCount'] as num).toInt()
            : 0,
        gender: json['gender'] as String?,
      );

  /// First letter of the name for the avatar circle. Falls back to "?"
  /// for empty/junk names so the UI never throws on `[0]`.
  String get initial =>
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}

/// The driver assigned to an active ride. Returned as the nested `driver`
/// object on [RideDetails] once a driver accepts — null while the ride is
/// still PENDING (no driver yet).
///
/// Backend contract:
///   {
///     "id":      "uuid",
///     "name":    "Ahmed Khan",   // nullable
///     "carInfo": "Toyota · Silver · LEA-2143", // nullable
///     "rating":  4.9,            // double 1.0–5.0, nullable (unrated)
///     "phone":   "+923001234567" // nullable
///   }
class DriverInfo {
  final String id;
  final String? name;
  final String? carInfo;
  final double? rating;
  final String? phone;

  const DriverInfo({
    required this.id,
    this.name,
    this.carInfo,
    this.rating,
    this.phone,
  });

  /// First letter of the driver's name for the avatar circle. Falls back
  /// to "?" for null/empty names so the UI never throws on `[0]`.
  String get initial {
    final n = name?.trim() ?? '';
    return n.isEmpty ? '?' : n[0].toUpperCase();
  }

  /// "Ahmed Khan" / "Your driver" — a safe display name when the backend
  /// hasn't sent one.
  String get displayName {
    final n = name?.trim() ?? '';
    return n.isEmpty ? 'Your driver' : n;
  }

  /// "4.9" / "New" — one-glance rating label.
  String get ratingLabel =>
      rating == null ? 'New' : rating!.toStringAsFixed(1);

  factory DriverInfo.fromJson(Map<String, dynamic> json) {
    String? readString(String key) {
      final v = json[key];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    return DriverInfo(
      id: (json['id'] ?? '').toString(),
      name: readString('name'),
      carInfo: readString('carInfo'),
      rating: json['rating'] is num ? (json['rating'] as num).toDouble() : null,
      phone: readString('phone'),
    );
  }
}

/// Fare math for a single rider on a shared ride. Backend computes
/// once and sends it down — frontend just renders.
class RideFareBreakdown {
  final double baseFare;
  final double sharedDiscount;
  final double perRider;

  /// ISO currency code. Defaults to PKR for the SafeRide market.
  final String currency;

  const RideFareBreakdown({
    required this.baseFare,
    required this.sharedDiscount,
    required this.perRider,
    this.currency = 'PKR',
  });

  factory RideFareBreakdown.fromJson(Map<String, dynamic> json) {
    double readDouble(String key) {
      final v = json[key];
      return v is num ? v.toDouble() : 0.0;
    }

    return RideFareBreakdown(
      baseFare: readDouble('baseFare'),
      sharedDiscount: readDouble('sharedDiscount'),
      perRider: readDouble('perRider'),
      currency: (json['currency'] as String?) ?? 'PKR',
    );
  }

  /// "Rs 200" / "$12" style label. Currency-code aware so adding USD
  /// markets later is a one-symbol mapping.
  String format(double amount) {
    final symbol = currency == 'PKR'
        ? 'Rs'
        : currency == 'USD'
            ? '\$'
            : currency;
    return '$symbol ${amount.round()}';
  }
}

/// Full backing data for the viewRequest screen — host, route, fare,
/// who's joined. Backed by `GET /api/v1/rides/{id}`.
///
/// Backend contract:
///   {
///     "id":              "uuid",
///     "pickup":          "Hostel City, Block B",
///     "drop":            "Taramri Chowk",
///     "pickupLat":       33.6844,
///     "pickupLng":       73.1234,
///     "dropLat":         33.6920,
///     "dropLng":         73.1500,
///     "rideType":        "ECONOMY" | "PREMIUM",
///     "status":          "PENDING" | "ACCEPTED" | ...,
///     "createdAt":       "2026-05-11T10:30:00Z",
///     "host":            { id, name, rating, trips, gender },
///     "seatsTotal":      4,
///     "seatsAvailable":  2,
///     "coPassengers":    [ { id, name, rating, trips, gender }, ... ],
///     "fare":            { baseFare, sharedDiscount, perRider, currency },
///     "youHaveJoined":   true              // true if caller is in participants
///   }
///
/// `coPassengers` MUST exclude the host AND the authenticated viewer.
/// `youHaveJoined` lets the viewRequest CTA decide between "Confirm
/// Ride" (not yet joined) and "Leave Ride" (already joined). Missing
/// field defaults to false on the client.
class RideDetails {
  final String id;
  final String pickup;
  final String drop;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropLat;
  final double? dropLng;
  final String rideType;
  final RideStatus status;
  final DateTime? createdAt;
  final RideHost host;
  final int seatsTotal;
  final int seatsAvailable;
  final List<RideCoPassenger> coPassengers;
  final RideFareBreakdown? fare;
  final bool youHaveJoined;

  /// The driver assigned to this ride. Null while the ride is still
  /// PENDING (no driver has accepted yet).
  final DriverInfo? driver;

  const RideDetails({
    required this.id,
    required this.pickup,
    required this.drop,
    required this.rideType,
    required this.status,
    required this.host,
    required this.seatsTotal,
    required this.seatsAvailable,
    required this.coPassengers,
    this.pickupLat,
    this.pickupLng,
    this.dropLat,
    this.dropLng,
    this.createdAt,
    this.fare,
    this.youHaveJoined = false,
    this.driver,
  });

  factory RideDetails.fromJson(Map<String, dynamic> json) {
    double? readDouble(String key) {
      final v = json[key];
      return v is num ? v.toDouble() : null;
    }

    DateTime? readDate(String key) {
      final raw = json[key];
      if (raw is! String || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    final hostRaw = json['host'];
    final host = hostRaw is Map<String, dynamic>
        ? RideHost.fromJson(hostRaw)
        : const RideHost(id: '', name: '', trips: 0);

    final coRaw = json['coPassengers'];
    final co = coRaw is List
        ? coRaw
            .whereType<Map<String, dynamic>>()
            .map(RideCoPassenger.fromJson)
            .toList(growable: false)
        : const <RideCoPassenger>[];

    final fareRaw = json['fare'];
    final fare = fareRaw is Map<String, dynamic>
        ? RideFareBreakdown.fromJson(fareRaw)
        : null;

    final driverRaw = json['driver'];
    final driver = driverRaw is Map<String, dynamic>
        ? DriverInfo.fromJson(driverRaw)
        : null;

    return RideDetails(
      id: (json['id'] ?? '').toString(),
      pickup: (json['pickup'] ?? '').toString(),
      drop: (json['drop'] ?? '').toString(),
      pickupLat: readDouble('pickupLat'),
      pickupLng: readDouble('pickupLng'),
      dropLat: readDouble('dropLat'),
      dropLng: readDouble('dropLng'),
      rideType: (json['rideType'] ?? 'ECONOMY').toString(),
      status: RideStatus.fromWire(json['status'] as String?),
      createdAt: readDate('createdAt'),
      host: host,
      seatsTotal: json['seatsTotal'] is num
          ? (json['seatsTotal'] as num).toInt()
          : 1,
      seatsAvailable: json['seatsAvailable'] is num
          ? (json['seatsAvailable'] as num).toInt()
          : 0,
      coPassengers: co,
      fare: fare,
      // Pattern-match so anything that isn't an actual bool — null,
      // missing key, "true"/"false" strings, 0/1 — falls cleanly to
      // `false` instead of slipping a null into a non-nullable slot.
      youHaveJoined: switch (json['youHaveJoined']) {
        bool b => b,
        _ => false,
      },
      driver: driver,
    );
  }
}

/// One row in the "Available Rides" list — a ride that someone else
/// created which the authenticated user could join. Backed by
/// `GET /api/v1/rides/available`.
///
/// Backend contract (one object per ride in the response array):
///   {
///     "id":               "uuid",
///     "hostName":         "Sarah Ahmed",
///     "hostRating":       4.9,            // double 1.0–5.0, null = unrated
///     "hostTrips":        128,            // int, completed-trip count
///     "hostGender":       "FEMALE",       // "MALE" | "FEMALE" | null
///     "etaMinutes":       18,             // int, null if backend can't compute
///     "distanceKm":       1.2,            // double, null when no lat/lng query
///     "fareForRider":     80.0,           // double in PKR, what this user pays
///     "pickup":           "Hostel City, Block B",
///     "drop":             "Taramri Chowk",
///     "pickupLat":        33.6844,
///     "pickupLng":        73.1234,
///     "dropLat":          33.6920,
///     "dropLng":          73.1500,
///     "seatsAvailable":   3              // int, remaining open seats
///   }
class AvailableRide {
  final String id;
  final String hostName;
  final double? hostRating;
  final int hostRatingCount;
  final int hostTrips;
  final String? hostGender;
  final int? etaMinutes;
  final double? distanceKm;
  final double? fareForRider;
  final String pickup;
  final String drop;
  final double pickupLat;
  final double pickupLng;
  final double dropLat;
  final double dropLng;
  final int seatsAvailable;

  /// On the "Your Rides" tab: true if you host this ride, false if you
  /// joined it as a co-passenger. Defaults true (the available-rides feed
  /// doesn't send it). Drives whether the card offers Cancel vs Leave.
  final bool youAreHost;

  const AvailableRide({
    required this.id,
    required this.hostName,
    required this.hostTrips,
    required this.pickup,
    required this.drop,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropLat,
    required this.dropLng,
    required this.seatsAvailable,
    this.hostRating,
    this.hostRatingCount = 0,
    this.hostGender,
    this.etaMinutes,
    this.distanceKm,
    this.fareForRider,
    this.youAreHost = true,
  });

  /// "4.9 (12)" / "New" — host rating with how many it's based on.
  String get hostRatingLabel {
    if (hostRating == null || hostRatingCount == 0) return 'New';
    return '${hostRating!.toStringAsFixed(1)} ($hostRatingCount)';
  }

  factory AvailableRide.fromJson(Map<String, dynamic> json) {
    double? readDouble(String key) {
      final v = json[key];
      return v is num ? v.toDouble() : null;
    }

    int? readInt(String key) {
      final v = json[key];
      return v is num ? v.toInt() : null;
    }

    return AvailableRide(
      id: (json['id'] ?? '').toString(),
      hostName: (json['hostName'] ?? '').toString(),
      hostRating: readDouble('hostRating'),
      hostRatingCount: readInt('hostRatingCount') ?? 0,
      hostTrips: readInt('hostTrips') ?? 0,
      hostGender: json['hostGender'] as String?,
      etaMinutes: readInt('etaMinutes'),
      distanceKm: readDouble('distanceKm'),
      fareForRider: readDouble('fareForRider'),
      pickup: (json['pickup'] ?? '').toString(),
      drop: (json['drop'] ?? '').toString(),
      pickupLat: readDouble('pickupLat') ?? 0,
      pickupLng: readDouble('pickupLng') ?? 0,
      dropLat: readDouble('dropLat') ?? 0,
      dropLng: readDouble('dropLng') ?? 0,
      seatsAvailable: readInt('seatsAvailable') ?? 0,
      youAreHost: switch (json['youAreHost']) {
        bool b => b,
        _ => true,
      },
    );
  }
}

/// One row in the driver ride-history screen. Backed by
/// `GET /api/v1/rides/driver/history` filtered to the authenticated
/// driver's completed + cancelled rides.
///
/// Backend contract (one object per ride in the response array):
///   {
///     "id":            "uuid",
///     "pickup":        "Hostel City, Block B",  // nullable
///     "drop":          "Taramri Chowk",         // nullable
///     "status":        "COMPLETED" | "CANCELLED",
///     "completedAt":   "2026-04-12T09:22:00Z",  // nullable, when ride ended
///     "fare":          450,                     // double — driver earnings
///     "passengerName": "Sarah Ahmed"
///   }
///
/// Unlike the passenger DTO there is no per-ride passenger-count or
/// rating-received field, so the card drops those.
class DriverRideHistory {
  final String id;
  final String pickup;
  final String drop;
  final RideStatus status;
  final DateTime? completedAt;
  final double fare;
  final String passengerName;

  const DriverRideHistory({
    required this.id,
    required this.pickup,
    required this.drop,
    required this.status,
    required this.fare,
    required this.passengerName,
    this.completedAt,
  });

  /// True for rides the driver actually completed (vs cancelled).
  bool get isCompleted => status == RideStatus.completed;

  /// "12 Apr" — short month + day, locale-agnostic (matches
  /// [PassengerRideHistoryItem.dateLabel]).
  String get dateLabel {
    final dt = completedAt;
    if (dt == null) return '—';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  /// "09:22" — 24-hour HH:mm.
  String get timeLabel {
    final dt = completedAt;
    if (dt == null) return '—';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  factory DriverRideHistory.fromJson(Map<String, dynamic> json) {
    double? readDouble(String key) {
      final v = json[key];
      return v is num ? v.toDouble() : null;
    }

    DateTime? readDate(String key) {
      final raw = json[key];
      if (raw is! String || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    return DriverRideHistory(
      id: (json['id'] ?? '').toString(),
      pickup: (json['pickup'] ?? '').toString(),
      drop: (json['drop'] ?? '').toString(),
      status: RideStatus.fromWire(json['status'] as String?),
      completedAt: readDate('completedAt'),
      fare: readDouble('fare') ?? 0.0,
      passengerName: (json['passengerName'] ?? '').toString(),
    );
  }
}

/// Driver earnings summary for the home dashboard. Backed by
/// `GET /api/v1/rides/driver/earnings`.
///
/// Backend contract:
///   {
///     "todayEarnings": 1240,    // double, PKR earned today
///     "todayTrips":    8,       // int, trips completed today
///     "totalEarnings": 84200,   // double, lifetime PKR earned
///     "totalTrips":    312,     // int, lifetime completed trips
///     "currency":      "PKR"
///   }
class DriverEarnings {
  final double todayEarnings;
  final int todayTrips;
  final double totalEarnings;
  final int totalTrips;
  final String currency;

  const DriverEarnings({
    required this.todayEarnings,
    required this.todayTrips,
    required this.totalEarnings,
    required this.totalTrips,
    this.currency = 'PKR',
  });

  factory DriverEarnings.fromJson(Map<String, dynamic> json) {
    double readDouble(String key) {
      final v = json[key];
      return v is num ? v.toDouble() : 0.0;
    }

    int readInt(String key) {
      final v = json[key];
      return v is num ? v.toInt() : 0;
    }

    return DriverEarnings(
      todayEarnings: readDouble('todayEarnings'),
      todayTrips: readInt('todayTrips'),
      totalEarnings: readDouble('totalEarnings'),
      totalTrips: readInt('totalTrips'),
      currency: (json['currency'] as String?) ?? 'PKR',
    );
  }
}
