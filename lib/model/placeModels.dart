import 'package:latlong2/latlong.dart';

/// One row in the place-search dropdown — what the user picks while
/// typing a pickup or destination.
///
/// Wraps just the fields the UI needs so the rest of the app never
/// touches the raw Geoapify response. Adding a new provider later only
/// requires writing another `fromGeoapify`-style factory.
class PlaceSuggestion {
  /// Geoapify's stable identifier for the place. Useful as a list key
  /// and for de-duping rapid-fire autocomplete responses.
  final String placeId;

  /// Short headline (e.g. "Liberty Market") — usually the first line
  /// of the formatted address, suitable for the dropdown's primary text.
  final String name;

  /// Full one-line address ("Liberty Market, Gulberg III, Lahore, ...").
  final String formatted;

  final LatLng coords;

  /// Optional context the dropdown can show as a secondary line.
  final String? city;
  final String? country;

  const PlaceSuggestion({
    required this.placeId,
    required this.name,
    required this.formatted,
    required this.coords,
    this.city,
    this.country,
  });

  /// Parses one feature out of the Geoapify Autocomplete response.
  /// Returns null if the feature is missing required coordinates —
  /// callers should `.whereType<PlaceSuggestion>()` to drop them.
  static PlaceSuggestion? fromGeoapifyFeature(Map<String, dynamic> feature) {
    final props = feature['properties'];
    if (props is! Map<String, dynamic>) return null;

    final lat = (props['lat'] as num?)?.toDouble();
    final lon = (props['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) return null;

    final formatted = (props['formatted'] as String?) ?? '';
    return PlaceSuggestion(
      placeId: (props['place_id'] as String?) ?? '$lat,$lon',
      name: (props['name'] as String?) ??
          (props['address_line1'] as String?) ??
          formatted.split(',').first,
      formatted: formatted,
      coords: LatLng(lat, lon),
      city: props['city'] as String?,
      country: props['country'] as String?,
    );
  }
}

/// Result of a reverse-geocode (coords → human-readable address). Same
/// shape as [PlaceSuggestion] minus `placeId` since reverse hits often
/// don't return a stable id and we don't need one for display.
class PlaceDetails {
  final String formatted;
  final String? name;
  final String? suburb;
  final String? city;
  final String? country;
  final LatLng coords;

  const PlaceDetails({
    required this.formatted,
    required this.coords,
    this.name,
    this.suburb,
    this.city,
    this.country,
  });

  /// Stitch the most useful address parts into one display line —
  /// mirrors the fallback behaviour the old `pickupAddressProvider`
  /// had over `package:geocoding`'s `Placemark`.
  String get displayLine {
    final parts = <String>[
      if ((name ?? '').isNotEmpty) name!,
      if ((suburb ?? '').isNotEmpty) suburb!,
      if ((city ?? '').isNotEmpty) city!,
    ];
    if (parts.isNotEmpty) return parts.join(', ');
    return formatted;
  }

  static PlaceDetails? fromGeoapifyFeature(Map<String, dynamic> feature) {
    final props = feature['properties'];
    if (props is! Map<String, dynamic>) return null;

    final lat = (props['lat'] as num?)?.toDouble();
    final lon = (props['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) return null;

    return PlaceDetails(
      formatted: (props['formatted'] as String?) ?? '',
      coords: LatLng(lat, lon),
      name: props['name'] as String?,
      suburb: props['suburb'] as String? ?? props['district'] as String?,
      city: props['city'] as String?,
      country: props['country'] as String?,
    );
  }
}
