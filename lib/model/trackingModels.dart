import 'package:latlong2/latlong.dart';

/// One live position broadcast on a ride's track topic. Mirrors
/// messaging-service's `LocationUpdate`.
class TrackPosition {
  final String userId;
  final String role; // "DRIVER" | "PASSENGER"
  final double lat;
  final double lng;
  final double? bearing;

  const TrackPosition({
    required this.userId,
    required this.role,
    required this.lat,
    required this.lng,
    this.bearing,
  });

  LatLng get latLng => LatLng(lat, lng);
  bool get isDriver => role.toUpperCase() == 'DRIVER';

  factory TrackPosition.fromJson(Map<String, dynamic> json) {
    double readDouble(String key) {
      final v = json[key];
      return v is num ? v.toDouble() : 0.0;
    }

    double? readDoubleN(String key) {
      final v = json[key];
      return v is num ? v.toDouble() : null;
    }

    return TrackPosition(
      userId: (json['userId'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      lat: readDouble('lat'),
      lng: readDouble('lng'),
      bearing: readDoubleN('bearing'),
    );
  }
}
