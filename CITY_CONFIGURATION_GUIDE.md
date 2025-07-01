# 🏙️ City Configuration Guide

## How to Configure Your City's Streets

The geocoding libraries **do not know** about your `zones.json` configuration. You need to **discover what street names the libraries return** and then **configure your zones** to match those names.

---

## 🔍 **Step 1: Discover Street Names**

### Method A: Use the Built-in Discovery Tool
1. **Run your app**
2. **Tap the map icon** (🗺️) in the top right of the home screen
3. **Visit different streets** in your city and use the "Current Location" button
4. **See what names the geocoding services return**
5. **Copy the exact names** to use in your configuration

### Method B: Manual Coordinates
1. Find coordinates using Google Maps:
   - Right-click on a street → "What's here?"
   - Copy the coordinates (e.g., `40.7128, -74.0060`)
2. Enter coordinates in the discovery tool
3. See what street names are returned

---

## 📍 **Step 2: Test Different Locations**

Visit **every street** where people can park in your city:

```dart
// Example: Testing your city
TestCoordinate(latitude: 40.7128, longitude: -74.0060, knownName: "Main Street"),
TestCoordinate(latitude: 40.7129, longitude: -74.0061, knownName: "Broadway"),
TestCoordinate(latitude: 40.7130, longitude: -74.0062, knownName: "Park Avenue"),
```

**💡 Tip**: Walk around your city with the app and use the "Current Location" button at different streets.

---

## 🗺️ **Step 3: What You'll See**

The tool will show you **different names** from different services:

```
📍 Coordinates: 40.7128, -74.0060
🤔 You think this is: Main Street
─────────────────────────────────────────────────
📱 Flutter Geocoding: Main St
🌍 Nominatim: Main Street
📋 Detailed: Main Street
─────────────────────────────────────────────────
✅ Use in zones.json: "Main Street"
```

**The geocoding service might return**:
- `"Main St"` (abbreviated)
- `"Main Street"` (full name)
- `"Main Street, Downtown"` (with area)
- `"State Highway 123"` (official name)

---

## ⚙️ **Step 4: Configure Your Zones**

Use the **exact names** returned by the geocoding service:

```json
[
  {
    "id": "zone_1",
    "name": "Downtown",
    "code": "DT",
    "hourlyRate": 2.00,
    "smsNumber": "1234",
    "streets": [
      "Main Street",           ← Exact name from geocoding
      "Broadway",              ← Exact name from geocoding
      "Park Avenue"            ← Exact name from geocoding
    ]
  },
  {
    "id": "zone_2", 
    "name": "Hospital Area",
    "code": "HA",
    "hourlyRate": 1.50,
    "smsNumber": "1234",
    "streets": [
      "Hospital Drive",        ← Exact name from geocoding
      "Medical Center Blvd"    ← Exact name from geocoding  
    ]
  }
]
```

---

## 🤔 **Handling Different Names**

### If services return different names:
```json
"streets": [
  "Main Street",     ← Nominatim returns this
  "Main St",         ← Flutter geocoding returns this  
  "Main Street NW"   ← Sometimes includes direction
]
```

### If no street name is detected:
Use **manual geofencing** in `assets/data/streets.json`:

```json
[
  {
    "name": "Unknown Street",
    "coordinates": [
      {"lat": 40.7128, "lng": -74.0060},
      {"lat": 40.7129, "lng": -74.0061}
    ],
    "zone": "zone_1"
  }
]
```

---

## 📱 **Step 5: Real-World Example**

Let's say you want to configure parking for your downtown area:

### 1. Drive to each street and test coordinates:
- **Main Street**: Geocoding returns `"Main Street"`
- **2nd Avenue**: Geocoding returns `"2nd Ave"`  
- **City Hall Plaza**: Geocoding returns `"City Hall Plaza"`

### 2. Create your `zones.json`:
```json
[
  {
    "id": "downtown_zone",
    "name": "Downtown Parking",
    "code": "DT", 
    "hourlyRate": 2.50,
    "smsNumber": "12345",
    "streets": [
      "Main Street",
      "2nd Ave", 
      "City Hall Plaza"
    ]
  }
]
```

### 3. Test the app:
- Stand on Main Street → App detects "Downtown Parking" zone
- Stand on 2nd Avenue → App detects "Downtown Parking" zone
- Send SMS: `"DT ABC123 2"` (Zone Code + Plate + Hours)

---

## 🚀 **Quick Start Workflow**

1. **Launch the app**
2. **Tap the map icon** 🗺️ 
3. **Walk to a parking street**
4. **Tap "Use Current Location"**
5. **Tap "Discover Street Names"**
6. **Copy the result to zones.json**
7. **Repeat for all parking streets**
8. **Generate the full config**
9. **Replace your `assets/data/zones.json`**
10. **Test parking on those streets**

---

## ⚠️ **Important Notes**

- **Street names must match exactly** what the geocoding service returns
- **Different services may return different names** - include multiple variations
- **Some streets may not be detected** - use manual geofencing for those
- **Test thoroughly** before going live in your city
- **SMS codes should match** your city's official parking SMS system

---

## 🔧 **Troubleshooting**

### "No street detected"
- The geocoding service doesn't recognize this location
- Add manual coordinates to `streets.json` instead
- Try different coordinate points on the same street

### "Wrong zone detected"  
- Check if street name is in multiple zones
- Make sure street names are exact matches
- Verify coordinate accuracy

### "SMS not working"
- Check SMS number is correct for your city
- Verify zone codes match your city's system
- Test SMS format: `"ZONE_CODE PLATE_NUMBER HOURS"`

---

**🎉 Once configured, your app will automatically detect parking zones and send the correct SMS for any street in your city!** 