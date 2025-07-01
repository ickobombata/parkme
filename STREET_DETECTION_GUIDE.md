# Street Detection Methods Guide

This guide explains how the parking app determines which street/zone you're in based on your GPS coordinates (X,Y).

## Detection Methods Available

### 1. 🏃‍♂️ **Flutter Geocoding Package** (Recommended)
**File**: `lib/services/simple_geocoding_service.dart`

```dart
// Example usage
final streetName = await SimpleGeocodingService.getStreetFromCoordinates(
  latitude, longitude
);
```

**Pros:**
- ✅ Free and unlimited
- ✅ Easy to implement
- ✅ Built into Flutter ecosystem
- ✅ Works offline (uses device's geocoding)
- ✅ High accuracy in populated areas

**Cons:**
- ❌ Accuracy depends on device/platform
- ❌ May not work well in rural areas
- ❌ Limited street name details

**Best for:** Most apps, especially if you want simple setup

---

### 2. 🌍 **Nominatim (OpenStreetMap)** - FREE
**File**: `lib/services/nominatim_service.dart`

```dart
// Example usage
final streetInfo = await NominatimService.getStreetFromCoordinates(
  latitude, longitude
);
```

**Pros:**
- ✅ Completely free
- ✅ Open source
- ✅ Global coverage
- ✅ Detailed address information
- ✅ No API key required
- ✅ Very accurate street names

**Cons:**
- ❌ Requires internet connection
- ❌ Rate limited (1 request/second)
- ❌ Slower than other methods

**Best for:** Apps that need detailed address info and can handle slower responses

**Setup:**
```yaml
# Add to pubspec.yaml
dependencies:
  http: ^1.1.0
```

---

### 3. 🎯 **GraphHopper Map Matching** - FREE (with limits)
**File**: `lib/services/graphhopper_service.dart`

```dart
// Example usage (requires API key)
final roadInfo = await GraphHopperService.getRoadInfo(latitude, longitude);
```

**Pros:**
- ✅ Very accurate road snapping
- ✅ Free tier available (1000 requests/day)
- ✅ Professional-grade map matching
- ✅ Works well for moving vehicles
- ✅ Confidence scores

**Cons:**
- ❌ Requires API key (free tier)
- ❌ Limited free requests
- ❌ More complex setup

**Best for:** Apps that need precise road matching (e.g., delivery apps)

**Setup:**
1. Get free API key: https://www.graphhopper.com/
2. Update `lib/services/graphhopper_service.dart`:
```dart
static const String _apiKey = 'YOUR_ACTUAL_API_KEY';
```

---

### 4. 📍 **Manual Geofencing** (Current Implementation)
**File**: `lib/services/location_service.dart`

```dart
// Define zones manually in assets/data/streets.json
{
  "name": "Main Street",
  "zoneId": "zone_1", 
  "coordinates": [
    {"latitude": 40.7128, "longitude": -74.0060, "radius": 100}
  ]
}
```

**Pros:**
- ✅ No internet required
- ✅ Complete control over zones
- ✅ Very fast
- ✅ No API dependencies

**Cons:**
- ❌ Manual setup required for each street
- ❌ Not scalable to large cities
- ❌ Maintenance overhead

**Best for:** Small cities or specific parking areas

---

## Implementation Comparison

| Method | Free | Setup Difficulty | Accuracy | Speed | Internet Required |
|--------|------|-----------------|----------|--------|------------------|
| Flutter Geocoding | ✅ | Easy | Good | Fast | No |
| Nominatim | ✅ | Easy | Excellent | Slow | Yes |
| GraphHopper | 🟡 Limited | Medium | Excellent | Fast | Yes |
| Geofencing | ✅ | Hard | Good* | Very Fast | No |

*Accuracy depends on manual configuration

---

## Current App Implementation

The app uses a **hybrid approach** that tries multiple methods:

1. **Flutter Geocoding** (fastest, most reliable)
2. **Nominatim** (fallback for detailed info)
3. **Manual Geofencing** (fallback for predefined areas)

```dart
// In location_service.dart
Future<void> _updateZoneUsingReverseGeocoding() async {
  // Try Method A: Simple Flutter geocoding
  detectedStreet = await SimpleGeocodingService.getStreetFromCoordinates(...);
  if (detectedStreet != null && _trySetZoneFromStreet(detectedStreet)) return;
  
  // Try Method B: Nominatim
  streetInfo = await NominatimService.getStreetFromCoordinates(...);
  if (streetInfo != null && _trySetZoneFromStreet(streetInfo.streetName)) return;
  
  // Try Method C: Geofencing fallback
  _findClosestStreet();
}
```

---

## Configuration

Edit `lib/config/detection_config.dart` to choose your preferred method:

```dart
class DetectionConfig {
  // Choose primary method
  static const StreetDetectionMethod primaryMethod = 
    StreetDetectionMethod.flutterGeocoding;  // or nominatim, graphHopper
  
  // Enable fallbacks
  static const bool enableNominatim = true;
  static const bool enableGeofencing = true;
}
```

---

## For Your City Setup

### Option 1: Use Reverse Geocoding (Recommended)
1. Keep current hybrid implementation
2. Add your city's parking zones to `assets/data/zones.json`
3. The app will automatically detect streets and match them to zones

### Option 2: Manual Geofencing
1. Map all parking streets in your city
2. Add GPS coordinates to `assets/data/streets.json`
3. Disable reverse geocoding in config

### Option 3: GraphHopper (Most Accurate)
1. Get free API key from GraphHopper
2. Update API key in `graphhopper_service.dart`
3. Set as primary method in config

---

## Testing

### Test with Mock Locations
```dart
// For testing, you can simulate coordinates
await locationService.updateCurrentZone(
  testLatitude: 40.7128,  // NYC coordinates
  testLongitude: -74.0060
);
```

### Test Different Methods
```dart
// Test Flutter geocoding
final street1 = await SimpleGeocodingService.getStreetFromCoordinates(lat, lng);

// Test Nominatim
final street2 = await NominatimService.getStreetFromCoordinates(lat, lng);

print('Flutter detected: $street1');
print('Nominatim detected: ${street2?.streetName}');
```

---

## Troubleshooting

### "No street detected"
1. Check internet connection (for Nominatim/GraphHopper)
2. Verify GPS permissions are granted
3. Test with known coordinates first
4. Check if you're in a mapped area

### "Wrong zone detected"
1. Update your zone configuration in `assets/data/zones.json`
2. Add more street name variations
3. Enable fuzzy matching in config

### "Too slow"
1. Switch to Flutter geocoding only
2. Disable Nominatim fallback
3. Use geofencing for critical areas

---

## Free Alternatives to Consider

1. **MapBox** - Free tier: 100,000 requests/month
2. **Here API** - Free tier: 1,000 requests/day  
3. **OpenRouteService** - Free but rate limited
4. **Google Geocoding** - Not free but very accurate

---

## Recommendation

**For most parking apps:**
Use the current hybrid approach with Flutter geocoding as primary and Nominatim as fallback. This gives you:
- No API keys needed
- Good accuracy
- Reliable fallback
- Works globally

**For high-precision apps:**
Add GraphHopper with a free API key for map matching. 