import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Fallback camera target used until the real GPS fix resolves.
/// (Gulberg, Lahore — matches the mock top-bar label.)
const LatLng kDefaultLatLng = LatLng(31.5204, 74.3587);
const double kDefaultZoom = 15.5;

/// Throws this instead of a bare [Exception] so the UI can distinguish
/// permission problems from transient GPS errors.
class LocationFailure implements Exception {
  final String message;
  const LocationFailure(this.message);

  @override
  String toString() => message;
}

/// Holds the [Completer] that is completed inside [GoogleMap.onMapCreated].
/// Exposed as a [Provider] so multiple widgets can await the controller
/// without rebuilding — the completer reference itself is stable.
final mapControllerCompleterProvider =
    Provider<Completer<GoogleMapController>>((ref) {
  final completer = Completer<GoogleMapController>();
  ref.onDispose(() async {
    if (completer.isCompleted) {
      final controller = await completer.future;
      controller.dispose();
    }
  });
  return completer;
});

/// Resolves the user's current GPS location with permission handling.
///
/// Exposed as [AsyncNotifier] so the UI can render loading / error /
/// data states cleanly and call [refresh] on retry.
class CurrentLocationNotifier extends AsyncNotifier<LatLng> {
  @override
  Future<LatLng> build() => _resolve();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_resolve);
  }

  Future<LatLng> _resolve() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationFailure('Location services are disabled.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationFailure('Location permission denied.');
    }

    final position = await Geolocator.getCurrentPosition();
    return LatLng(position.latitude, position.longitude);
  }
}

final currentLocationProvider =
    AsyncNotifierProvider<CurrentLocationNotifier, LatLng>(
  CurrentLocationNotifier.new,
);

/// The coordinate currently under the fixed center pin. Updated on
/// every [GoogleMap.onCameraMove] so the pickup field stays in sync.
///
/// [update] is a no-op when the new value equals the current one —
/// keeps downstream rebuilds minimal.
class PickupLocationNotifier extends Notifier<LatLng?> {
  @override
  LatLng? build() => null;

  void update(LatLng value) {
    final current = state;
    if (current != null &&
        current.latitude == value.latitude &&
        current.longitude == value.longitude) {
      return;
    }
    state = value;
  }
}

final pickupLocationProvider =
    NotifierProvider<PickupLocationNotifier, LatLng?>(
  PickupLocationNotifier.new,
);

/// Reverse-geocodes the current [pickupLocationProvider] coordinate into
/// a human-readable address ("Block B, Hostel City, Lahore"). Pure
/// derived state — recomputes whenever the pickup pin moves. Uses
/// [package:geocoding] which talks to the platform geocoder (Geocoding
/// API on Android, no separate key needed since the Maps SDK key in
/// AndroidManifest.xml is reused).
///
/// Returns null while the pickup hasn't resolved yet, an empty string on
/// failure (so the UI can fall back to the lat/lng label without blowing
/// up the widget tree on transient geocoder errors).
final pickupAddressProvider = FutureProvider<String?>((ref) async {
  final pickup = ref.watch(pickupLocationProvider);
  if (pickup == null) return null;
  try {
    final placemarks = await geocoding.placemarkFromCoordinates(
      pickup.latitude,
      pickup.longitude,
    );
    if (placemarks.isEmpty) return '';
    final p = placemarks.first;
    // Stitch the most useful fields into one line, skipping any that
    // resolved blank — full street is rarely populated worldwide so we
    // fall back gracefully through name → subLocality → locality.
    final parts = <String>[
      if ((p.name ?? '').isNotEmpty) p.name!,
      if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,
      if ((p.locality ?? '').isNotEmpty) p.locality!,
    ];
    if (parts.isEmpty && (p.administrativeArea ?? '').isNotEmpty) {
      parts.add(p.administrativeArea!);
    }
    return parts.join(', ');
  } catch (_) {
    return '';
  }
});

/// Index of the selected ride option in the booking sheet.
class SelectedRideIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

final selectedRideIndexProvider =
    NotifierProvider<SelectedRideIndexNotifier, int>(
  SelectedRideIndexNotifier.new,
);

/// Minimal Uber-style map style — hides POI, transit, road label icons
/// and softens park greens. Kept as a single const for easy swapping.
const String kMinimalMapStyle = '''
[
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#e8f3e2"}]},
  {"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"road.highway","elementType":"geometry.fill","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road.arterial","elementType":"geometry.fill","stylers":[{"color":"#ffffff"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#d9e7ee"}]}
]
''';
