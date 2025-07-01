import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/zone.dart';
import '../models/street.dart';

class ZoneService {
  static final ZoneService _instance = ZoneService._internal();
  factory ZoneService() => _instance;
  ZoneService._internal();

  List<Zone> _zones = [];
  List<Street> _streets = [];
  bool _isInitialized = false;

  List<Zone> get zones => List.unmodifiable(_zones);
  List<Street> get streets => List.unmodifiable(_streets);
  bool get isInitialized => _isInitialized;

  /// Initialize the service with zone and street data
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadZones();
      await _loadStreets();
      _isInitialized = true;
    } catch (e) {
      print('Error initializing ZoneService: $e');
      // Fall back to default data if loading fails
      _createDefaultData();
      _isInitialized = true;
    }
  }

  /// Load zones from JSON data
  Future<void> _loadZones() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/data/zones.json');
      final List<dynamic> jsonData = json.decode(jsonString);
      _zones = jsonData.map((json) => Zone.fromJson(json)).toList();
    } catch (e) {
      print('Error loading zones: $e');
      _createDefaultZones();
    }
  }

  /// Load streets from JSON data
  Future<void> _loadStreets() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/data/streets.json');
      final List<dynamic> jsonData = json.decode(jsonString);
      _streets = jsonData.map((json) => Street.fromJson(json)).toList();
    } catch (e) {
      print('Error loading streets: $e');
      _createDefaultStreets();
    }
  }

  /// Find zone by ID
  Zone? getZoneById(String zoneId) {
    try {
      return _zones.firstWhere((zone) => zone.id == zoneId);
    } catch (e) {
      return null;
    }
  }

  /// Find zone by code
  Zone? getZoneByCode(String code) {
    try {
      return _zones.firstWhere((zone) => zone.code == code);
    } catch (e) {
      return null;
    }
  }

  /// Find zone by street name
  Zone? getZoneByStreet(String streetName) {
    try {
      final street = _streets.firstWhere(
        (street) => street.name.toLowerCase().contains(streetName.toLowerCase())
      );
      return getZoneById(street.zoneId);
    } catch (e) {
      return null;
    }
  }

  /// Find all streets in a zone
  List<Street> getStreetsByZone(String zoneId) {
    return _streets.where((street) => street.zoneId == zoneId).toList();
  }

  /// Check if a street belongs to a specific zone
  bool isStreetInZone(String streetName, String zoneId) {
    return _streets.any((street) => 
      street.name.toLowerCase().contains(streetName.toLowerCase()) && 
      street.zoneId == zoneId
    );
  }

  /// Create default zone data for fallback
  void _createDefaultZones() {
    _zones = [
      Zone(
        id: 'zone_1',
        name: 'City Center',
        code: 'CC',
        hourlyRate: 2.50,
        smsNumber: '1234',
        streets: ['Main Street', 'Central Avenue', 'Downtown Boulevard'],
      ),
      Zone(
        id: 'zone_2',
        name: 'Residential Area',
        code: 'RA',
        hourlyRate: 1.50,
        smsNumber: '1234',
        streets: ['Oak Street', 'Pine Avenue', 'Maple Road'],
      ),
      Zone(
        id: 'zone_3',
        name: 'Business District',
        code: 'BD',
        hourlyRate: 3.00,
        smsNumber: '1234',
        streets: ['Business Plaza', 'Corporate Drive', 'Office Street'],
      ),
    ];
  }

  /// Create default street data for fallback
  void _createDefaultStreets() {
    _streets = [
      // City Center streets
      Street(
        name: 'Main Street',
        zoneId: 'zone_1',
        coordinates: [
          StreetCoordinate(latitude: 40.7128, longitude: -74.0060, radius: 100),
          StreetCoordinate(latitude: 40.7130, longitude: -74.0058, radius: 100),
        ],
      ),
      Street(
        name: 'Central Avenue',
        zoneId: 'zone_1',
        coordinates: [
          StreetCoordinate(latitude: 40.7125, longitude: -74.0065, radius: 100),
          StreetCoordinate(latitude: 40.7127, longitude: -74.0063, radius: 100),
        ],
      ),
      // Residential Area streets
      Street(
        name: 'Oak Street',
        zoneId: 'zone_2',
        coordinates: [
          StreetCoordinate(latitude: 40.7140, longitude: -74.0070, radius: 75),
          StreetCoordinate(latitude: 40.7142, longitude: -74.0068, radius: 75),
        ],
      ),
      Street(
        name: 'Pine Avenue',
        zoneId: 'zone_2',
        coordinates: [
          StreetCoordinate(latitude: 40.7145, longitude: -74.0075, radius: 75),
          StreetCoordinate(latitude: 40.7147, longitude: -74.0073, radius: 75),
        ],
      ),
      // Business District streets
      Street(
        name: 'Business Plaza',
        zoneId: 'zone_3',
        coordinates: [
          StreetCoordinate(latitude: 40.7120, longitude: -74.0050, radius: 150),
          StreetCoordinate(latitude: 40.7122, longitude: -74.0048, radius: 150),
        ],
      ),
    ];
  }

  /// Create default data (zones and streets)
  void _createDefaultData() {
    _createDefaultZones();
    _createDefaultStreets();
  }

  /// Refresh data from assets
  Future<void> refresh() async {
    _isInitialized = false;
    _zones.clear();
    _streets.clear();
    await initialize();
  }
} 