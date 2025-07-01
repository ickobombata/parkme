import 'package:geocoding/geocoding.dart';

class SimpleGeocodingService {
  /// Get street address from coordinates using Flutter's geocoding package
  static Future<String?> getStreetFromCoordinates(
    double latitude, 
    double longitude
  ) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude, 
        longitude
      );
      
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        
        // Try different street fields
        final street = placemark.street ??
                      placemark.thoroughfare ??
                      placemark.subThoroughfare ??
                      placemark.name;
                      
        print('Detected street: $street');
        print('Full address: ${placemark.street}, ${placemark.locality}, ${placemark.country}');
        
        return street;
      }
    } catch (e) {
      print('Error in geocoding: $e');
    }
    
    return null;
  }
  
  /// Get detailed address information
  static Future<AddressInfo?> getDetailedAddress(
    double latitude, 
    double longitude
  ) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude, 
        longitude
      );
      
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        
        return AddressInfo(
          street: placemark.street ?? placemark.thoroughfare,
          subStreet: placemark.subThoroughfare,
          locality: placemark.locality,
          subLocality: placemark.subLocality,
          administrativeArea: placemark.administrativeArea,
          postalCode: placemark.postalCode,
          country: placemark.country,
          name: placemark.name,
        );
      }
    } catch (e) {
      print('Error getting detailed address: $e');
    }
    
    return null;
  }
}

class AddressInfo {
  final String? street;
  final String? subStreet;
  final String? locality;
  final String? subLocality;
  final String? administrativeArea;
  final String? postalCode;
  final String? country;
  final String? name;
  
  AddressInfo({
    this.street,
    this.subStreet,
    this.locality,
    this.subLocality,
    this.administrativeArea,
    this.postalCode,
    this.country,
    this.name,
  });
  
  String get displayStreet => street ?? name ?? 'Unknown Street';
  
  String get fullAddress {
    final parts = [street, locality, country].where((part) => part != null && part.isNotEmpty);
    return parts.join(', ');
  }
} 