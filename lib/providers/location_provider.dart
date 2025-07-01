import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../models/zone.dart';
import '../models/street.dart';
import '../services/location_service.dart';
import '../services/zone_service.dart';

class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final ZoneService _zoneService = ZoneService();

  Position? _currentPosition;
  Zone? _currentZone;
  Street? _currentStreet;
  bool _isLoading = false;
  bool _hasLocationPermission = false;
  String? _errorMessage;
  StreamSubscription<Position>? _locationSubscription;

  Position? get currentPosition => _currentPosition;
  Zone? get currentZone => _currentZone;
  Street? get currentStreet => _currentStreet;
  bool get isLoading => _isLoading;
  bool get hasLocationPermission => _hasLocationPermission;
  bool get isInParkingZone => _currentZone != null;
  String? get errorMessage => _errorMessage;

  /// Initialize location provider
  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Initialize zone service first
      await _zoneService.initialize();
      
      // Check permissions and get location
      await getCurrentLocation();
      
      // Start listening to location updates
      _startLocationUpdates();
      
    } catch (e) {
      _errorMessage = 'Failed to initialize location: ${e.toString()}';
      print('Error initializing LocationProvider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get current location
  Future<void> getCurrentLocation() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final position = await _locationService.getCurrentLocation();
      
      if (position != null) {
        _currentPosition = position;
        _currentZone = _locationService.currentZone;
        _currentStreet = _locationService.currentStreet;
        _hasLocationPermission = true;
        _errorMessage = null;
      } else {
        _hasLocationPermission = false;
        _errorMessage = 'Unable to get location. Please check permissions.';
      }
    } catch (e) {
      _hasLocationPermission = false;
      _errorMessage = 'Location error: ${e.toString()}';
      print('Error getting location: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Start listening to location updates
  void _startLocationUpdates() {
    _locationSubscription?.cancel();
    
    try {
      _locationSubscription = _locationService.getLocationStream().listen(
        (Position position) {
          _currentPosition = position;
          _currentZone = _locationService.currentZone;
          _currentStreet = _locationService.currentStreet;
          notifyListeners();
        },
        onError: (error) {
          _errorMessage = 'Location update error: ${error.toString()}';
          print('Location stream error: $error');
          notifyListeners();
        },
      );
    } catch (e) {
      print('Error starting location updates: $e');
    }
  }

  /// Stop location updates
  void stopLocationUpdates() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  /// Refresh location
  Future<void> refresh() async {
    await getCurrentLocation();
  }

  /// Request location permissions
  Future<bool> requestLocationPermission() async {
    try {
      final hasPermission = await _locationService.checkAndRequestPermissions();
      _hasLocationPermission = hasPermission;
      
      if (hasPermission) {
        await getCurrentLocation();
        _startLocationUpdates();
      } else {
        _errorMessage = 'Location permission denied';
      }
      
      notifyListeners();
      return hasPermission;
    } catch (e) {
      _errorMessage = 'Permission request failed: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Open location settings
  Future<void> openLocationSettings() async {
    try {
      await _locationService.openLocationSettings();
    } catch (e) {
      print('Error opening location settings: $e');
    }
  }

  /// Open app settings
  Future<void> openAppSettings() async {
    try {
      await _locationService.openAppSettings();
    } catch (e) {
      print('Error opening app settings: $e');
    }
  }

  /// Get distance to nearest parking zone
  Future<double?> getDistanceToNearestZone() async {
    return await _locationService.getDistanceToNearestZone();
  }

  /// Get formatted distance string
  String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()}m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
    }
  }

  /// Get current location info as string
  String get locationInfo {
    if (_currentPosition == null) return 'Location not available';
    
    if (_currentZone != null) {
      return 'Zone: ${_currentZone!.name} (${_currentZone!.code})';
    }
    
    return 'Outside parking zones';
  }

  /// Get detailed location string
  String get detailedLocationInfo {
    if (_currentPosition == null) return 'Location not available';
    
    final lat = _currentPosition!.latitude.toStringAsFixed(4);
    final lng = _currentPosition!.longitude.toStringAsFixed(4);
    
    if (_currentZone != null && _currentStreet != null) {
      return '${_currentStreet!.name}\n${_currentZone!.name} (${_currentZone!.code})\nLat: $lat, Lng: $lng';
    } else if (_currentZone != null) {
      return '${_currentZone!.name} (${_currentZone!.code})\nLat: $lat, Lng: $lng';
    }
    
    return 'Outside parking zones\nLat: $lat, Lng: $lng';
  }

  /// Check if location services are available
  bool get isLocationServiceAvailable {
    return _hasLocationPermission && _currentPosition != null;
  }

  /// Get zone rate information
  String? get currentZoneRate {
    if (_currentZone == null) return null;
    return '€${_currentZone!.hourlyRate.toStringAsFixed(2)}/hour';
  }

  @override
  void dispose() {
    stopLocationUpdates();
    super.dispose();
  }
} 