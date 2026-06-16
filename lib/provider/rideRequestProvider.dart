import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Captures the ride request a passenger is composing on the rides
/// screen — the pickup / destination they entered, plus seats wanted.
/// Lives at app scope so values survive tab switches and feed
/// downstream screens (e.g. View Request).
///
/// [pickupLatLng] / [dropLatLng] hold the geocoded coordinates picked
/// from Places autocomplete (or null when the user only typed free
/// text). Real coords let downstream screens call the Directions API
/// for accurate ETA + km without re-geocoding.
class RideRequestState {
  final String pickup;
  final String drop;
  final int seats;
  final LatLng? pickupLatLng;
  final LatLng? dropLatLng;

  const RideRequestState({
    this.pickup = '',
    this.drop = '',
    this.seats = 1,
    this.pickupLatLng,
    this.dropLatLng,
  });

  RideRequestState copyWith({
    String? pickup,
    String? drop,
    int? seats,
    LatLng? pickupLatLng,
    LatLng? dropLatLng,
    bool clearPickupLatLng = false,
    bool clearDropLatLng = false,
  }) {
    return RideRequestState(
      pickup: pickup ?? this.pickup,
      drop: drop ?? this.drop,
      seats: seats ?? this.seats,
      pickupLatLng:
          clearPickupLatLng ? null : (pickupLatLng ?? this.pickupLatLng),
      dropLatLng: clearDropLatLng ? null : (dropLatLng ?? this.dropLatLng),
    );
  }

  bool get hasRoute => pickup.isNotEmpty && drop.isNotEmpty;
  bool get hasCoords => pickupLatLng != null && dropLatLng != null;
}

class RideRequestNotifier extends Notifier<RideRequestState> {
  @override
  RideRequestState build() => const RideRequestState();

  void setPickup(String value, {LatLng? latLng}) {
    state = state.copyWith(
      pickup: value.trim(),
      pickupLatLng: latLng,
      // Free text without coords invalidates any previously-picked coord.
      clearPickupLatLng: latLng == null,
    );
  }

  void setDrop(String value, {LatLng? latLng}) {
    state = state.copyWith(
      drop: value.trim(),
      dropLatLng: latLng,
      clearDropLatLng: latLng == null,
    );
  }

  void setSeats(int value) {
    final clamped = value < 1 ? 1 : (value > 4 ? 4 : value);
    state = state.copyWith(seats: clamped);
  }

  /// Persists the entire form in one shot — used by the Save button.
  void save({
    required String pickup,
    required String drop,
    required int seats,
    LatLng? pickupLatLng,
    LatLng? dropLatLng,
  }) {
    state = RideRequestState(
      pickup: pickup.trim(),
      drop: drop.trim(),
      seats: seats < 1 ? 1 : (seats > 4 ? 4 : seats),
      pickupLatLng: pickupLatLng,
      dropLatLng: dropLatLng,
    );
  }

  void clear() {
    state = const RideRequestState();
  }
}

final rideRequestProvider =
    NotifierProvider<RideRequestNotifier, RideRequestState>(
  RideRequestNotifier.new,
);
