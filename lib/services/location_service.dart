import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';
import '../models/zone.dart';
import '../models/street.dart';
import 'zone_service.dart';
import 'nominatim_service.dart';
import 'simple_geocoding_service.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final ZoneService _zoneService = ZoneService();
  Position? _currentPosition;
  Zone? _currentZone;
  Street? _currentStreet;

  Position? get currentPosition => _currentPosition;
  Zone? get currentZone => _currentZone;
  Street? get currentStreet => _currentStreet;

  /// Check and request location permissions
  Future<bool> checkAndRequestPermissions() async {
    // Check app-level permission
    var status = await Permission.location.status;
    if (status.isDenied) {
      status = await Permission.location.request();
      if (status.isDenied) {
        return false;
      }
    }

    if (status.isPermanentlyDenied) {
      return false;
    }

    // Check system-level location service
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // Check precise location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Get current location
  Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) {
        throw Exception('Location permissions not granted');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );

      _currentPosition = position;
      await _updateCurrentZone();
      
      return position;
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  /// Start listening to location changes
  Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Only update if moved 10 meters
      ),
    );
  }

  /// Update current zone based on location
  Future<void> _updateCurrentZone() async {
    if (_currentPosition == null) return;

    await _zoneService.initialize();
    
    // Method 1: Try geofencing first (for manually mapped streets)
    for (final street in _zoneService.streets) {
      for (final coord in street.coordinates) {
        final distance = _calculateDistance(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          coord.latitude,
          coord.longitude,
        );

        if (distance <= coord.radius) {
          _currentStreet = street;
          _currentZone = _zoneService.getZoneById(street.zoneId);
          return;
        }
      }
    }

    // Method 2: Use reverse geocoding to get actual street name
    await _updateZoneUsingReverseGeocoding();
  }

  /// Use reverse geocoding to detect street and zone (tries multiple services)
  Future<void> _updateZoneUsingReverseGeocoding() async {
    if (_currentPosition == null) return;

    String? detectedStreet;

    // Try Method A: Simple Flutter geocoding (most reliable)
    try {
      detectedStreet = await SimpleGeocodingService.getStreetFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      
      if (detectedStreet != null && _trySetZoneFromStreet(detectedStreet)) {
        return;
      }
    } catch (e) {
      print('Error in simple geocoding: $e');
    }

    // Try Method B: Nominatim (OpenStreetMap based - free)
    try {
      final streetInfo = await NominatimService.getStreetFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      if (streetInfo != null && _trySetZoneFromStreet(streetInfo.streetName)) {
        return;
      }
    } catch (e) {
      print('Error in Nominatim geocoding: $e');
    }

    // Method C: Fallback to closest street from predefined list
    _findClosestStreet();
  }

  /// Helper method to try setting zone from a detected street name
  bool _trySetZoneFromStreet(String streetName) {
    if (streetName.isEmpty) return false;

    print('Trying to match street: $streetName');

    // Try exact match first
    final zone = _zoneService.getZoneByStreet(streetName);
    if (zone != null) {
      _setCurrentZoneAndStreet(zone, streetName);
      return true;
    }

    // Try partial matching
    for (final zone in _zoneService.zones) {
      if (zone.streets.any((street) => 
        _isStreetMatch(street, streetName)
      )) {
        _setCurrentZoneAndStreet(zone, streetName);
        return true;
      }
    }

    return false;
  }

  /// Check if two street names match (fuzzy matching)
  bool _isStreetMatch(String configuredStreet, String detectedStreet) {
    final configured = configuredStreet.toLowerCase().trim();
    final detected = detectedStreet.toLowerCase().trim();

    // Exact match
    if (configured == detected) return true;

    // Contains match
    if (configured.contains(detected) || detected.contains(configured)) return true;

    // Remove common words and try again
    final commonWords = ['street', 'avenue', 'road', 'drive', 'boulevard', 'lane', 'way'];
    String cleanConfigured = configured;
    String cleanDetected = detected;

    for (final word in commonWords) {
      cleanConfigured = cleanConfigured.replaceAll(word, '').trim();
      cleanDetected = cleanDetected.replaceAll(word, '').trim();
    }

    return cleanConfigured.isNotEmpty && 
           cleanDetected.isNotEmpty && 
           (cleanConfigured.contains(cleanDetected) || cleanDetected.contains(cleanConfigured));
  }

  /// Set the current zone and street
  void _setCurrentZoneAndStreet(Zone zone, String streetName) {
    _currentZone = zone;
    _currentStreet = Street(
      name: streetName,
      zoneId: zone.id,
      coordinates: [
        StreetCoordinate(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          radius: 50,
        ),
      ],
    );
    print('✅ Zone detected: ${zone.name} ($streetName)');
  }

  /// Find the closest street to current location
  void _findClosestStreet() {
    if (_currentPosition == null) return;

    double minDistance = double.infinity;
    Street? closestStreet;

    for (final street in _zoneService.streets) {
      for (final coord in street.coordinates) {
        final distance = _calculateDistance(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          coord.latitude,
          coord.longitude,
        );

        if (distance < minDistance) {
          minDistance = distance;
          closestStreet = street;
        }
      }
    }

    if (closestStreet != null && minDistance <= 200) { // Within 200 meters
      _currentStreet = closestStreet;
      _currentZone = _zoneService.getZoneById(closestStreet.zoneId);
    } else {
      _currentStreet = null;
      _currentZone = null;
    }
  }

  /// Calculate distance between two GPS coordinates using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    final double lat1Rad = lat1 * (pi / 180);
    final double lat2Rad = lat2 * (pi / 180);
    final double deltaLatRad = (lat2 - lat1) * (pi / 180);
    final double deltaLonRad = (lon2 - lon1) * (pi / 180);

    final double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLonRad / 2) * sin(deltaLonRad / 2);
    
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c; // Distance in meters
  }

  /// Check if current location is in a parking zone
  bool isInParkingZone() {
    return _currentZone != null;
  }

  /// Get distance to nearest parking zone
  Future<double?> getDistanceToNearestZone() async {
    if (_currentPosition == null) return null;

    double? minDistance;

    for (final street in _zoneService.streets) {
      for (final coord in street.coordinates) {
        final distance = _calculateDistance(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          coord.latitude,
          coord.longitude,
        );

        if (minDistance == null || distance < minDistance) {
          minDistance = distance;
        }
      }
    }

    return minDistance;
  }

  /// Open device location settings
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// Open app settings for location permission
  Future<void> openAppSettings() async {
    await openAppSettings();
  }

  /// Refresh current location and zone
  Future<void> refresh() async {
    await getCurrentLocation();
  }

  /// Check if two locations are within the same zone
  bool areLocationsInSameZone(Position pos1, Position pos2) {
    for (final street in _zoneService.streets) {
      bool pos1InStreet = false;
      bool pos2InStreet = false;

      for (final coord in street.coordinates) {
        final distance1 = _calculateDistance(pos1.latitude, pos1.longitude, coord.latitude, coord.longitude);
        final distance2 = _calculateDistance(pos2.latitude, pos2.longitude, coord.latitude, coord.longitude);

        if (distance1 <= coord.radius) pos1InStreet = true;
        if (distance2 <= coord.radius) pos2InStreet = true;
      }

      if (pos1InStreet && pos2InStreet) return true;
    }

    return false;
  }
} 