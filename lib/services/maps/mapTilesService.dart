/// Single source of truth for the raster tile layer used by every
/// `FlutterMap` in the app. Centralised so swapping providers (CartoDB
/// → Geoapify tiles → MapTiler → ...) is a one-file change.
///
/// Default: CartoDB Voyager — free, no API key, no per-app cap, and a
/// clean minimal aesthetic close to the previous Uber-style Google Maps
/// theme. Subdomains a–d let `flutter_map` round-robin tile requests.
class MapTilesService {
  MapTilesService._();

  /// Tile URL template. The `{s}`, `{x}`, `{y}`, `{z}`, and `{r}`
  /// placeholders are filled by `flutter_map`'s `TileLayer`.
  /// `{r}` resolves to "@2x" on hi-DPI displays for crisper tiles.
  static const String tileUrl =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

  /// Round-robin subdomains. CartoDB exposes a, b, c, d.
  static const List<String> subdomains = ['a', 'b', 'c', 'd'];

  /// Required per OSM/CARTO attribution policy. Render this somewhere
  /// visible on screens that show the map.
  static const String attribution =
      '© OpenStreetMap contributors © CARTO';

  /// flutter_map asks for a `userAgentPackageName` so providers can
  /// trace heavy usage back to specific apps. Should match the bundle
  /// id / application id for production accuracy.
  static const String userAgentPackageName = 'com.example.ride_sharing';
}
