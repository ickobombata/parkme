import '../services/simple_geocoding_service.dart';
import '../services/nominatim_service.dart';

/// Tool to discover what street names geocoding services return
/// Use this to find the exact street names for your city configuration
class StreetDiscoveryTool {
  
  /// Test what street names are returned for a specific coordinate
  static Future<StreetDiscoveryResult> discoverStreetAt({
    required double latitude,
    required double longitude,
    String? yourKnownStreetName, // What you think the street is called
  }) async {
    print('\n🔍 DISCOVERING STREET NAMES FOR:');
    print('📍 Coordinates: $latitude, $longitude');
    if (yourKnownStreetName != null) {
      print('🤔 You think this is: $yourKnownStreetName');
    }
    print('─' * 50);

    final result = StreetDiscoveryResult(
      latitude: latitude,
      longitude: longitude,
      yourKnownName: yourKnownStreetName,
    );

    // Test Flutter Geocoding
    try {
      final flutterResult = await SimpleGeocodingService.getStreetFromCoordinates(
        latitude, longitude
      );
      result.flutterGeocodingName = flutterResult;
      print('📱 Flutter Geocoding: ${flutterResult ?? "Not found"}');
    } catch (e) {
      print('❌ Flutter Geocoding error: $e');
    }

    // Test Nominatim
    try {
      final nominatimResult = await NominatimService.getStreetFromCoordinates(
        latitude, longitude
      );
      result.nominatimName = nominatimResult?.streetName;
      result.nominatimFullAddress = nominatimResult?.fullAddress;
      print('🌍 Nominatim: ${nominatimResult?.streetName ?? "Not found"}');
      if (nominatimResult?.fullAddress != null) {
        print('   Full: ${nominatimResult!.fullAddress}');
      }
    } catch (e) {
      print('❌ Nominatim error: $e');
    }

    // Test detailed address
    try {
      final detailedAddress = await SimpleGeocodingService.getDetailedAddress(
        latitude, longitude
      );
      if (detailedAddress != null) {
        result.detailedStreet = detailedAddress.street;
        result.detailedLocality = detailedAddress.locality;
        print('📋 Detailed - Street: ${detailedAddress.street}');
        print('📋 Detailed - Area: ${detailedAddress.locality}');
      }
    } catch (e) {
      print('❌ Detailed address error: $e');
    }

    print('─' * 50);
    print('💡 RECOMMENDATIONS:');
    result.generateRecommendations();
    
    return result;
  }

  /// Test multiple coordinates to map your entire city
  static Future<List<StreetDiscoveryResult>> discoverMultipleStreets(
    List<TestCoordinate> coordinates
  ) async {
    print('\n🗺️  DISCOVERING MULTIPLE STREETS');
    print('═' * 60);

    final results = <StreetDiscoveryResult>[];

    for (int i = 0; i < coordinates.length; i++) {
      final coord = coordinates[i];
      print('\n📍 Location ${i + 1}/${coordinates.length}');
      
      final result = await discoverStreetAt(
        latitude: coord.latitude,
        longitude: coord.longitude,
        yourKnownStreetName: coord.knownName,
      );
      
      results.add(result);
      
      // Be nice to APIs - don't spam requests
      if (i < coordinates.length - 1) {
        await Future.delayed(Duration(seconds: 2));
      }
    }

    print('\n📊 SUMMARY OF ALL DISCOVERED STREETS:');
    print('═' * 60);
    _printSummary(results);

    return results;
  }

  /// Generate zones.json configuration from discovery results
  static String generateZonesConfig(List<StreetDiscoveryResult> results) {
    print('\n🔧 GENERATING ZONES CONFIG:');
    
    // Group streets by area/locality
    final groupedResults = <String, List<StreetDiscoveryResult>>{};
    
    for (final result in results) {
      final area = result.detailedLocality ?? 
                   result.yourKnownName?.split(' ').first ?? 
                   'Unknown Area';
      
      groupedResults.putIfAbsent(area, () => []).add(result);
    }

    final buffer = StringBuffer();
    buffer.writeln('// GENERATED ZONES CONFIG - Copy to assets/data/zones.json');
    buffer.writeln('[');
    
    int zoneIndex = 1;
    groupedResults.forEach((area, streetResults) {
      buffer.writeln('  {');
      buffer.writeln('    "id": "zone_$zoneIndex",');
      buffer.writeln('    "name": "$area",');
      buffer.writeln('    "code": "${area.substring(0, 2).toUpperCase()}",');
      buffer.writeln('    "hourlyRate": 2.00,  // TODO: Set actual rate');
      buffer.writeln('    "smsNumber": "1234", // TODO: Set actual SMS number');
      buffer.writeln('    "streets": [');
      
      for (int i = 0; i < streetResults.length; i++) {
        final result = streetResults[i];
        final bestName = result.getBestStreetName();
        if (bestName != null) {
          buffer.write('      "$bestName"');
          if (i < streetResults.length - 1) buffer.write(',');
          buffer.writeln();
        }
      }
      
      buffer.writeln('    ]');
      buffer.write('  }');
      if (zoneIndex < groupedResults.length) buffer.write(',');
      buffer.writeln();
      
      zoneIndex++;
    });
    
    buffer.writeln(']');
    
    final config = buffer.toString();
    print(config);
    return config;
  }

  static void _printSummary(List<StreetDiscoveryResult> results) {
    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      final bestName = result.getBestStreetName();
      print('${i + 1}. ${result.yourKnownName ?? "Unknown"} → $bestName');
    }
  }
}

class TestCoordinate {
  final double latitude;
  final double longitude;
  final String? knownName;  // What you call this street
  
  TestCoordinate({
    required this.latitude,
    required this.longitude,
    this.knownName,
  });
}

class StreetDiscoveryResult {
  final double latitude;
  final double longitude;
  final String? yourKnownName;
  
  String? flutterGeocodingName;
  String? nominatimName;
  String? nominatimFullAddress;
  String? detailedStreet;
  String? detailedLocality;
  
  StreetDiscoveryResult({
    required this.latitude,
    required this.longitude,
    this.yourKnownName,
  });

  /// Get the best street name to use in configuration
  String? getBestStreetName() {
    // Prefer Nominatim (most accurate), then Flutter geocoding
    return nominatimName ?? flutterGeocodingName ?? detailedStreet;
  }

  void generateRecommendations() {
    final bestName = getBestStreetName();
    
    if (bestName != null) {
      print('✅ Use in zones.json: "$bestName"');
      
      if (yourKnownName != null && yourKnownName != bestName) {
        print('⚠️  Your name "$yourKnownName" differs from detected "$bestName"');
        print('   Consider adding both names to the streets array:');
        print('   "streets": ["$bestName", "$yourKnownName"]');
      }
    } else {
      print('❌ No street name detected - you may need manual geofencing');
      print('   Add coordinates to assets/data/streets.json instead');
    }
    
    if (flutterGeocodingName != nominatimName && 
        flutterGeocodingName != null && 
        nominatimName != null) {
      print('📝 Multiple names detected - consider adding both:');
      print('   "$flutterGeocodingName" and "$nominatimName"');
    }
  }
} 