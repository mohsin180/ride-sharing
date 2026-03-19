class PassengerProfileRequest {
  final String fullName;
  final String phoneNo;
  final String cnic;

  PassengerProfileRequest({
    required this.fullName,
    required this.phoneNo,
    required this.cnic,
  });

  Map<String, dynamic> toJson() {
    return {"fullName": fullName, "phoneNo": phoneNo, "cnic": cnic};
  }
}

class PassengerProfileResponse {
  final String fullName;
  final String phoneNo;
  final String cnic;

  PassengerProfileResponse({
    required this.fullName,
    required this.phoneNo,
    required this.cnic,
  });
  factory PassengerProfileResponse.fromJson(Map<String, dynamic> json) {
    return PassengerProfileResponse(
      fullName: json["fullName"],
      phoneNo: json["phoneNo"],
      cnic: json["cnic"],
    );
  }
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
  Map<String, dynamic> toJson() {
    return {
      "fullName": fullName,
      "phoneNo": phoneNo,
      "cnic": cnic,
      "vehicle": vehicle,
    };
  }
}

class DriverProfileResponse {
  final String fullName;
  final String phoneNo;
  final String cnic;
  final VehicleResponse vehicle;

  DriverProfileResponse({
    required this.vehicle,
    required this.fullName,
    required this.phoneNo,
    required this.cnic,
  });

  factory DriverProfileResponse.fromJson(Map<String, dynamic> json) {
    return DriverProfileResponse(
      fullName: json["fullName"],
      phoneNo: json["phoneNo"],
      cnic: json["cnic"],
      vehicle: json["vehicle"],
    );
  }
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
}
