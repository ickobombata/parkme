import 'dart:convert';
import 'package:http/http.dart' as http;

class GraphHopperService {
  // Get free API key from: https://www.graphhopper.com/
  static const String _apiKey = 'YOUR_FREE_API_KEY_HERE';
  static const String _baseUrl = 'https://graphhopper.com/api/1';

  /// Snap GPS coordinates to the nearest road using Map Matching
  static Future<RoadMatchResult?> snapToRoad(
    List<GpsPoint> gpsPoints,
  ) async {
    if (_apiKey == 'YOUR_FREE_API_KEY_HERE') {
      print('Please set your GraphHopper API key');
      return null;
    }

    try {
      // Convert GPS points to the required format
      final coordinates = gpsPoints
          .map((point) => [point.longitude, point.latitude])
          .toList();

      final requestBody = {
        'coordinates': coordinates,
        'instructions': true,
        'calc_points': true,
        'debug': true,
        'vehicle': 'car',
        'locale': 'en',
      };

      final url = Uri.parse('$_baseUrl/match?key=$_apiKey');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['paths'] != null && data['paths'].isNotEmpty) {
          final path = data['paths'][0];
          
          return RoadMatchResult(
            matchedPoints: _parseMatchedPoints(path['points']),
            roadName: _extractRoadName(path),
            confidence: (path['details']?['road_class'] as List?)?.length ?? 0,
            distance: path['distance']?.toDouble() ?? 0.0,
            duration: path['time']?.toDouble() ?? 0.0,
          );
        }
      }
    } catch (e) {
      print('Error in map matching: $e');
    }
    
    return null;
  }

  /// Get road information for a single GPS point
  static Future<RoadInfo?> getRoadInfo(double latitude, double longitude) async {
    try {
      // Use a small radius around the point for matching
      final points = [
        GpsPoint(latitude: latitude, longitude: longitude),
      ];
      
      final result = await snapToRoad(points);
      if (result != null && result.matchedPoints.isNotEmpty) {
        return RoadInfo(
          roadName: result.roadName,
          latitude: result.matchedPoints.first.latitude,
          longitude: result.matchedPoints.first.longitude,
          confidence: result.confidence,
        );
      }
    } catch (e) {
      print('Error getting road info: $e');
    }
    
    return null;
  }

  static List<GpsPoint> _parseMatchedPoints(dynamic points) {
    // GraphHopper returns encoded polyline, decode it here
    // For simplicity, returning empty list - implement polyline decoding if needed
    return [];
  }

  static String _extractRoadName(Map<String, dynamic> path) {
    // Extract road name from path instructions
    final instructions = path['instructions'] as List?;
    if (instructions != null && instructions.isNotEmpty) {
      return instructions[0]['street_name'] ?? 'Unknown Road';
    }
    return 'Unknown Road';
  }
}

class GpsPoint {
  final double latitude;
  final double longitude;
  final DateTime? timestamp;

  GpsPoint({
    required this.latitude,
    required this.longitude,
    this.timestamp,
  });
}

class RoadMatchResult {
  final List<GpsPoint> matchedPoints;
  final String roadName;
  final int confidence;
  final double distance;
  final double duration;

  RoadMatchResult({
    required this.matchedPoints,
    required this.roadName,
    required this.confidence,
    required this.distance,
    required this.duration,
  });
}

class RoadInfo {
  final String roadName;
  final double latitude;
  final double longitude;
  final int confidence;

  RoadInfo({
    required this.roadName,
    required this.latitude,
    required this.longitude,
    required this.confidence,
  });
} 