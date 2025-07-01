/// Configuration for street detection methods
class DetectionConfig {
  // Choose your preferred detection method
  static const StreetDetectionMethod primaryMethod = StreetDetectionMethod.flutterGeocoding;
  
  // Enable fallback methods
  static const bool enableNominatim = true;
  static const bool enableGeofencing = true;
  static const bool enableGraphHopper = false; // Requires API key
  
  // GraphHopper API key (get free key from https://www.graphhopper.com/)
  static const String graphHopperApiKey = 'YOUR_API_KEY_HERE';
  
  // Geofencing settings
  static const double defaultRadius = 100.0; // meters
  static const double maxDetectionDistance = 200.0; // meters
  
  // Fuzzy matching settings
  static const bool enableFuzzyMatching = true;
  static const List<String> streetSuffixes = [
    'street', 'avenue', 'road', 'drive', 'boulevard', 
    'lane', 'way', 'place', 'court', 'circle'
  ];
}

enum StreetDetectionMethod {
  /// Use Flutter's built-in geocoding package (most reliable)
  flutterGeocoding,
  
  /// Use OpenStreetMap's Nominatim service (free, good coverage)
  nominatim,
  
  /// Use GraphHopper map matching (precise, requires API key)
  graphHopper,
  
  /// Use manual geofencing with predefined coordinates
  geofencing,
  
  /// Try all methods in order until one succeeds
  hybrid,
}

/// Detection accuracy levels
enum DetectionAccuracy {
  /// Fast but less accurate
  low,
  
  /// Balanced speed and accuracy
  medium,
  
  /// Slow but most accurate
  high,
} 