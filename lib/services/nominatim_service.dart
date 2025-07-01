import 'dart:convert';
import 'package:http/http.dart' as http;

class NominatimService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';
  
  /// Get street name from GPS coordinates using Nominatim (free)
  static Future<StreetInfo?> getStreetFromCoordinates(
    double latitude, 
    double longitude
  ) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/reverse?format=json&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1'
      );
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'ParkMe-App/1.0', // Required by Nominatim
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['address'] != null) {
          final address = data['address'];
          
          return StreetInfo(
            streetName: address['road'] ?? 
                      address['pedestrian'] ?? 
                      address['footway'] ?? 
                      'Unknown Street',
            neighborhood: address['neighbourhood'] ?? address['suburb'],
            city: address['city'] ?? address['town'] ?? address['village'],
            district: address['district'],
            country: address['country'],
            fullAddress: data['display_name'],
          );
        }
      }
    } catch (e) {
      print('Error getting street info: $e');
    }
    
    return null;
  }
  
  /// Get multiple street suggestions around a coordinate
  static Future<List<StreetInfo>> getStreetsNearby(
    double latitude, 
    double longitude,
    {double radiusMeters = 100}
  ) async {
    try {
      // Search for nearby streets
      final url = Uri.parse(
        '$_baseUrl/search?format=json&q=street&lat=$latitude&lon=$longitude'
        '&bounded=1&limit=10&extratags=1&namedetails=1'
      );
      
      final response = await http.get(
        url,
        headers: {'User-Agent': 'ParkMe-App/1.0'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        
        return results.map((item) {
          return StreetInfo(
            streetName: item['display_name']?.split(',')[0] ?? 'Unknown',
            fullAddress: item['display_name'],
            latitude: double.tryParse(item['lat']),
            longitude: double.tryParse(item['lon']),
          );
        }).toList();
      }
    } catch (e) {
      print('Error getting nearby streets: $e');
    }
    
    return [];
  }
}

class StreetInfo {
  final String streetName;
  final String? neighborhood;
  final String? city;
  final String? district;
  final String? country;
  final String? fullAddress;
  final double? latitude;
  final double? longitude;
  
  StreetInfo({
    required this.streetName,
    this.neighborhood,
    this.city,
    this.district,
    this.country,
    this.fullAddress,
    this.latitude,
    this.longitude,
  });
  
  @override
  String toString() => streetName;
} 