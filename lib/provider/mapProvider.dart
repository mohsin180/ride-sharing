import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:ride_sharing/services/maps/geocodingService.dart';

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

/// flutter_map's [MapController] is created synchronously, so unlike
/// the old `Completer<GoogleMapController>` pattern there's no async
/// step before consumers can call `move()`. Exposed via a Provider so
/// the map widget and any external camera-mover share one instance.
final mapControllerProvider = Provider<MapController>((ref) {
  final controller = MapController();
  ref.onDispose(controller.dispose);
  return controller;
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
/// every gestured camera move so the pickup field stays in sync.
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

/// Singleton [GeocodingService]. One HTTP client lives for the app's
/// lifetime; closed automatically on container dispose.
final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  final service = GeocodingService();
  ref.onDispose(service.dispose);
  return service;
});

/// Reverse-geocodes the current [pickupLocationProvider] coordinate
/// into a human-readable address ("Block B, Hostel City, Lahore"),
/// using Geoapify under the hood. Returns null while the pickup hasn't
/// resolved yet, an empty string on failure (so the UI can fall back
/// to a coords label without blowing up the widget tree on transient
/// service errors).
final pickupAddressProvider = FutureProvider<String?>((ref) async {
  final pickup = ref.watch(pickupLocationProvider);
  if (pickup == null) return null;
  try {
    final details =
        await ref.read(geocodingServiceProvider).reverseGeocode(pickup);
    if (details == null) return '';
    return details.displayLine;
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
