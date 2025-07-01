# ParkMe - Smart Parking Ticket App

A Flutter mobile application for managing parking tickets via SMS in cities with zone-based parking systems.

## Features

### Core Functionality
- **Car Management**: Add and manage multiple vehicles with plate numbers
- **Location Detection**: GPS-based automatic zone detection
- **Zone-Based Parking**: Different parking zones with unique tariffs and codes
- **SMS Integration**: Automatic SMS sending for parking ticket activation
- **Time Tracking**: Real-time countdown until parking expiration
- **Parking History**: Track all parking sessions and costs

### Smart Features
- **Auto Zone Detection**: Uses GPS to automatically detect which parking zone you're in
- **Multiple Duration Options**: Quick selection of 1, 2, or 3-hour parking
- **Real-time Notifications**: Get notified when parking is about to expire
- **Cost Calculation**: Automatic calculation of parking costs based on zone rates
- **Parking Status**: Visual indicators for active, expired, and cancelled parking

## Architecture

The app is built with a modular architecture consisting of:

### 1. Zone Management Module (`lib/services/zone_service.dart`)
- Manages parking zones and street mappings
- Loads zone configuration from JSON files
- Maps streets to their respective parking zones
- Handles zone lookup by location, name, or code

### 2. Location Service Module (`lib/services/location_service.dart`)
- GPS location tracking with high accuracy
- Automatic zone detection based on coordinates
- Geofencing for parking zone boundaries
- Permission handling for location access

### 3. SMS Service Module (`lib/services/sms_service.dart`)
- Formats SMS messages according to city requirements
- Sends parking activation/cancellation SMS
- Handles SMS permissions
- Provides SMS delivery verification

### 4. Parking Management Module (`lib/services/parking_service.dart`)
- Manages active parking tickets
- Tracks parking duration and expiration
- Provides notifications for expiring tickets
- Stores parking history locally

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── models/                      # Data models
│   ├── car.dart                # Car model
│   ├── zone.dart               # Parking zone model
│   ├── street.dart             # Street with coordinates
│   └── parking_ticket.dart     # Parking session model
├── services/                    # Business logic services
│   ├── zone_service.dart       # Zone management
│   ├── location_service.dart   # GPS and location
│   ├── sms_service.dart        # SMS functionality
│   └── parking_service.dart    # Parking operations
├── providers/                   # State management
│   ├── car_provider.dart       # Car state
│   ├── location_provider.dart  # Location state
│   └── parking_provider.dart   # Parking state
└── screens/                     # UI screens
    └── home_screen.dart        # Main application screen

assets/
└── data/                       # Sample data files
    ├── zones.json             # Parking zones configuration
    └── streets.json           # Streets with GPS coordinates
```

## Setup Instructions

### Prerequisites
- Flutter SDK (>=3.10.0)
- Android Studio / Xcode for platform-specific development
- Physical device for testing (location and SMS features)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd parkme
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate model files**
   ```bash
   dart run build_runner build
   ```

4. **Configure for your city**
   - Edit `assets/data/zones.json` with your city's parking zones
   - Edit `assets/data/streets.json` with actual GPS coordinates
   - Update SMS number in zone configurations

5. **Run the app**
   ```bash
   flutter run
   ```

## Configuration

### Zone Configuration (`assets/data/zones.json`)
```json
{
  "id": "zone_1",
  "name": "City Center",
  "code": "CC",
  "hourlyRate": 2.50,
  "smsNumber": "1234",
  "streets": ["Main Street", "Central Avenue"]
}
```

### Street Configuration (`assets/data/streets.json`)
```json
{
  "name": "Main Street",
  "zoneId": "zone_1",
  "coordinates": [
    {"latitude": 40.7128, "longitude": -74.0060, "radius": 100}
  ]
}
```

## SMS Message Format

The app formats SMS messages according to the standard format:
```
[ZoneCode] [PlateNumber] [Duration]
```

Example: `CC ABC123 2` (Park in City Center zone, plate ABC123, for 2 hours)

## Permissions

### Android
- `ACCESS_FINE_LOCATION` - GPS location access
- `ACCESS_COARSE_LOCATION` - Network location access
- `SEND_SMS` - Send parking SMS messages
- `READ_SMS` - Read confirmation messages
- `RECEIVE_SMS` - Receive parking confirmations

### iOS
- `NSLocationWhenInUseUsageDescription` - Location access while using app
- `NSLocationAlwaysAndWhenInUseUsageDescription` - Background location access

## Usage

1. **Add Your Car**: Add your vehicle details including plate number
2. **Enable Location**: Grant location permissions for zone detection
3. **Select Car**: Choose which car you're driving
4. **Choose Duration**: Select parking duration (1, 2, or 3 hours)
5. **Start Parking**: Tap "Start Parking" to send SMS and activate ticket
6. **Monitor Time**: Track remaining time and get expiration alerts

## Customization

### Adding New Zones
1. Update `assets/data/zones.json` with new zone information
2. Add corresponding streets in `assets/data/streets.json`
3. Include GPS coordinates for accurate zone detection

### Changing SMS Format
Edit the `formatParkingMessage` method in `lib/services/sms_service.dart` to match your city's SMS format requirements.

### UI Customization
The app uses Material Design 3. Customize colors and themes in `lib/main.dart`.

## Development Notes

### State Management
The app uses Provider pattern for state management with three main providers:
- `CarProvider` - Manages user's vehicles
- `LocationProvider` - Handles GPS and zone detection
- `ParkingProvider` - Manages parking sessions

### Data Persistence
- Car data: Stored in SharedPreferences
- Parking history: Stored in SharedPreferences
- Zone/street data: Loaded from JSON assets

### Testing
- Use Android/iOS simulators for UI testing
- Use physical devices for location and SMS testing
- Mock location can be used for zone detection testing

## Known Limitations

1. **SMS Verification**: Basic SMS sending without delivery confirmation
2. **Offline Mode**: Requires internet connection for some features
3. **iOS SMS**: Limited SMS capabilities on iOS compared to Android
4. **Location Accuracy**: Depends on device GPS accuracy

## Future Enhancements

- [ ] Push notifications for parking expiration
- [ ] Payment integration for automatic billing
- [ ] Parking history analytics
- [ ] Multi-language support
- [ ] Apple Watch / Android Wear integration
- [ ] Parking spot availability information

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Create an issue in the repository
- Check existing issues for solutions
- Review the documentation above

---

**Note**: This app is designed for cities with SMS-based parking systems. Ensure you have the correct SMS numbers and message formats for your specific city before deployment.
