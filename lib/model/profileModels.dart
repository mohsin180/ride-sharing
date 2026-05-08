class PassengerProfileRequest {
  final String fullName;
  final String phoneNo;
  final String cnic;

  PassengerProfileRequest({
    required this.fullName,
    required this.phoneNo,
    required this.cnic,
  });

  Map<String, dynamic> toJson() => {
    "fullName": fullName,
    "phoneNo": phoneNo,
    "cnic": cnic,
  };
}

class PassengerProfileResponse {
  final String fullName;
  final String phoneNo;
  final String cnic;

  /// Optional fields the backend may include when joining with the
  /// user record (auth service). Kept nullable so the model still
  /// parses cleanly when the create-profile endpoint returns only
  /// the bare minimum.
  final String? email;
  final String? gender;
  final String? id;

  /// Account-creation timestamp from the user record. Backend should
  /// return ISO-8601 (e.g. `"2024-03-15T10:23:45Z"`); we parse the
  /// year off it for the "Member Since" stat.
  final DateTime? createdAt;

  PassengerProfileResponse({
    required this.fullName,
    required this.phoneNo,
    required this.cnic,
    this.email,
    this.gender,
    this.id,
    this.createdAt,
  });

  factory PassengerProfileResponse.fromJson(Map<String, dynamic> json) {
    String? readString(String key) {
      final v = json[key];
      if (v == null) return null;
      final s = v.toString();
      return s.isEmpty ? null : s;
    }

    DateTime? readDate(String key) {
      final raw = readString(key);
      if (raw == null) return null;
      return DateTime.tryParse(raw);
    }

    return PassengerProfileResponse(
      fullName: (json["fullName"] ?? '').toString(),
      phoneNo: (json["phoneNo"] ?? '').toString(),
      cnic: (json["cnic"] ?? '').toString(),
      email: readString("email"),
      gender: readString("gender"),
      id: readString("id"),
      createdAt: readDate("createdAt"),
    );
  }

  Map<String, dynamic> toJson() => {
    "fullName": fullName,
    "phoneNo": phoneNo,
    "cnic": cnic,
    if (email != null) "email": email,
    if (gender != null) "gender": gender,
    if (id != null) "id": id,
    if (createdAt != null) "createdAt": createdAt!.toIso8601String(),
  };
}

class DriverProfileRequest {
  final String fullName;
  final String phoneNo;
  final String cnic;
  final VehicleRequest vehicle;

  DriverProfileRequest({
    required this.fullName,
    required this.phoneNo,
    required this.cnic,
    required this.vehicle,
  });

  Map<String, dynamic> toJson() => {
    "fullName": fullName,
    "phoneNo": phoneNo,
    "cnic": cnic,
    "vehicle": vehicle.toJson(),
  };
}

class DriverProfileResponse {
  final String fullName;
  final String phoneNo;
  final String cnic;
  final VehicleResponse vehicle;

  /// Optional fields the backend may include when joining with the
  /// user record (auth service). Mirrors [PassengerProfileResponse].
  final String? email;
  final String? gender;
  final String? id;
  final DateTime? createdAt;

  DriverProfileResponse({
    required this.vehicle,
    required this.fullName,
    required this.phoneNo,
    required this.cnic,
    this.email,
    this.gender,
    this.id,
    this.createdAt,
  });

  factory DriverProfileResponse.fromJson(Map<String, dynamic> json) {
    String? readString(String key) {
      final v = json[key];
      if (v == null) return null;
      final s = v.toString();
      return s.isEmpty ? null : s;
    }

    DateTime? readDate(String key) {
      final raw = readString(key);
      if (raw == null) return null;
      return DateTime.tryParse(raw);
    }

    final rawVehicle = json["vehicle"];
    final vehicle = rawVehicle is Map<String, dynamic>
        ? VehicleResponse.fromJson(rawVehicle)
        : VehicleResponse.empty();

    return DriverProfileResponse(
      fullName: (json["fullName"] ?? '').toString(),
      phoneNo: (json["phoneNo"] ?? '').toString(),
      cnic: (json["cnic"] ?? '').toString(),
      vehicle: vehicle,
      email: readString("email"),
      gender: readString("gender"),
      id: readString("id"),
      createdAt: readDate("createdAt"),
    );
  }

  Map<String, dynamic> toJson() => {
    "fullName": fullName,
    "phoneNo": phoneNo,
    "cnic": cnic,
    "vehicle": vehicle.toJson(),
    if (email != null) "email": email,
    if (gender != null) "gender": gender,
    if (id != null) "id": id,
    if (createdAt != null) "createdAt": createdAt!.toIso8601String(),
  };
}

class VehicleRequest {
  final String make;
  final String model;
  final String number;
  final String color;
  final int seats;
  final int year;

  VehicleRequest({
    required this.make,
    required this.model,
    required this.number,
    required this.color,
    required this.seats,
    required this.year,
  });

  Map<String, dynamic> toJson() => {
    "make": make,
    "model": model,
    "number": number,
    "color": color,
    "seats": seats,
    "year": year,
  };
}

class VehicleResponse {
  final String make;
  final String model;
  final String number;
  final String color;
  final int seats;
  final int year;

  VehicleResponse({
    required this.make,
    required this.model,
    required this.number,
    required this.color,
    required this.seats,
    required this.year,
  });

  /// Fallback used when the backend omits the vehicle block on a
  /// driver-profile response — keeps the screen renderable rather
  /// than crashing on a hard cast.
  factory VehicleResponse.empty() => VehicleResponse(
    make: '',
    model: '',
    number: '',
    color: '',
    seats: 0,
    year: 0,
  );

  factory VehicleResponse.fromJson(Map<String, dynamic> json) {
    return VehicleResponse(
      make: (json["make"] ?? '').toString(),
      model: (json["model"] ?? '').toString(),
      number: (json["number"] ?? '').toString(),
      color: (json["color"] ?? '').toString(),
      seats: json["seats"] is num ? (json["seats"] as num).toInt() : 0,
      year: json["year"] is num ? (json["year"] as num).toInt() : 0,
    );
  }

  Map<String, dynamic> toJson() => {
    "make": make,
    "model": model,
    "number": number,
    "color": color,
    "seats": seats,
    "year": year,
  };
}
