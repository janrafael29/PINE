/// Shared map tile URLs for flutter_map.
///
/// [esriWorldImagery] — Esri World Imagery (RGB aerial / satellite). Tiles are
/// refreshed on Esri’s schedule; there is no single “live” public tile URL.
/// For provider-specific freshness, you’d need your own keyed service (Mapbox,
/// Google Maps Platform, etc.).
library;

abstract final class MapTiles {
  /// Global satellite / aerial imagery (no API key; suitable for field drawing).
  static const String esriWorldImagery =
      'https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  static const String openStreetMap =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// World Topo Map — high zoom; World_Physical_Map only serves ~z0–8 (blank at app zooms).
  static const String esriTerrain =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}';

  /// Native zoom cap for Esri topo tiles (matches typical ArcGIS Online limits).
  static const int maxNativeZoomTerrain = 19;

  /// Maximum **map** zoom for satellite (pinch / fit). Can exceed native: tiles
  /// are **digitally upscaled** beyond [maxNativeZoomSatellite] for a closer view
  /// without requesting Esri’s “not available” placeholders.
  static const int maxZoomSatellite = 19;

  /// Highest zoom **requested from the tile server**. Esri often serves placeholder
  /// “Map data not yet available” tiles above ~z17 in many areas — keep downloads here.
  /// Cached tiles still load crisply at higher [maxZoomSatellite] when upscaled.
  static const int maxNativeZoomSatellite = 17;

  /// OpenStreetMap.org tiles are typically available through z19.
  static const int maxNativeZoomOpenStreetMap = 19;
}
