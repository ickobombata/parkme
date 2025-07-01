import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/car_provider.dart';
import '../providers/location_provider.dart';
import '../providers/parking_provider.dart';
import '../models/car.dart';
import '../models/zone.dart';
import '../models/parking_ticket.dart';
import 'street_discovery_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedDuration = 1; // Default 1 hour

  @override
  void initState() {
    super.initState();
    _initializeProviders();
  }

  Future<void> _initializeProviders() async {
    final carProvider = Provider.of<CarProvider>(context, listen: false);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);

    await Future.wait([
      carProvider.initialize(),
      locationProvider.initialize(),
      parkingProvider.initialize(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ParkMe'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.map),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => StreetDiscoveryScreen()),
            ),
            tooltip: 'Street Discovery Tool',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshAll,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLocationCard(),
              SizedBox(height: 16),
              _buildCarSelectionCard(),
              SizedBox(height: 16),
              _buildActiveParkingCard(),
              SizedBox(height: 16),
              _buildParkingControlCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Consumer<LocationProvider>(
      builder: (context, locationProvider, child) {
        return Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Current Location',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                if (locationProvider.isLoading)
                  Row(
                    children: [
                      SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Getting location...'),
                    ],
                  )
                else if (locationProvider.errorMessage != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        locationProvider.errorMessage!,
                        style: TextStyle(color: Colors.red),
                      ),
                      SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => locationProvider.requestLocationPermission(),
                        icon: Icon(Icons.location_on),
                        label: Text('Enable Location'),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        locationProvider.locationInfo,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (locationProvider.currentZoneRate != null) ...[
                        SizedBox(height: 4),
                        Text(
                          locationProvider.currentZoneRate!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (!locationProvider.isInParkingZone) ...[
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Text(
                            'You are outside parking zones',
                            style: TextStyle(
                              color: Colors.orange[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCarSelectionCard() {
    return Consumer<CarProvider>(
      builder: (context, carProvider, child) {
        if (carProvider.isLoading) {
          return Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (!carProvider.hasCars) {
          return Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.directions_car, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('No cars added yet'),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _addCar,
                    child: Text('Add Car'),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.directions_car, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Select Car',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(),
                    TextButton.icon(
                      onPressed: _addCar,
                      icon: Icon(Icons.add),
                      label: Text('Add'),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Car>(
                      value: carProvider.selectedCar,
                      isExpanded: true,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      items: carProvider.cars.map((car) {
                        return DropdownMenuItem<Car>(
                          value: car,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: car.color != null 
                                    ? _getColorFromString(car.color!)
                                    : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      car.plateNumber,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      '${car.make} ${car.model}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (car.isDefault)
                                Icon(Icons.star, color: Colors.amber, size: 16),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (Car? car) {
                        if (car != null) {
                          carProvider.selectCar(car);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveParkingCard() {
    return Consumer2<CarProvider, ParkingProvider>(
      builder: (context, carProvider, parkingProvider, child) {
        if (carProvider.selectedCar == null) return SizedBox.shrink();

        final activeParkingTicket = parkingProvider.getActiveParkingForCar(
          carProvider.selectedCar!.plateNumber,
        );

        if (activeParkingTicket == null) return SizedBox.shrink();

        return Card(
          color: activeParkingTicket.isExpired ? Colors.red.shade50 : Colors.green.shade50,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      activeParkingTicket.isExpired ? Icons.warning : Icons.local_parking,
                      color: activeParkingTicket.isExpired ? Colors.red : Colors.green,
                    ),
                    SizedBox(width: 8),
                    Text(
                      activeParkingTicket.isExpired ? 'Parking Expired' : 'Active Parking',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: activeParkingTicket.isExpired ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Zone: ${activeParkingTicket.zoneName}'),
                          Text('Car: ${activeParkingTicket.carPlateNumber}'),
                          Text('Duration: ${activeParkingTicket.durationHours}h'),
                          Text('Cost: €${activeParkingTicket.totalCost.toStringAsFixed(2)}'),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          activeParkingTicket.timeRemainingFormatted,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: activeParkingTicket.isExpired ? Colors.red : Colors.green,
                          ),
                        ),
                        Text(
                          'Expires: ${_formatTime(activeParkingTicket.endTime)}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _cancelParking(activeParkingTicket.id),
                    icon: Icon(Icons.stop),
                    label: Text('Cancel Parking'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildParkingControlCard() {
    return Consumer3<CarProvider, LocationProvider, ParkingProvider>(
      builder: (context, carProvider, locationProvider, parkingProvider, child) {
        final selectedCar = carProvider.selectedCar;
        final currentZone = locationProvider.currentZone;
        final isInParkingZone = locationProvider.isInParkingZone;
        final hasActiveParking = selectedCar != null 
          ? parkingProvider.hasActiveParkingForCar(selectedCar.plateNumber)
          : false;

        if (selectedCar == null) {
          return Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Please select a car to start parking',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          );
        }

        if (hasActiveParking) {
          return SizedBox.shrink(); // Active parking card is shown above
        }

        return Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Start Parking',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                
                // Duration selection
                Text(
                  'Select Duration:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [1, 2, 3].map((hours) {
                    final isSelected = _selectedDuration == hours;
                    final cost = currentZone != null 
                      ? parkingProvider.calculateCost(currentZone, hours)
                      : 0.0;
                    
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: hours < 3 ? 8 : 0,
                        ),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDuration = hours;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected 
                                ? Theme.of(context).primaryColor
                                : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected 
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey.shade300,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${hours}h',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: isSelected ? Colors.white : Colors.black,
                                  ),
                                ),
                                if (currentZone != null) ...[
                                  SizedBox(height: 4),
                                  Text(
                                    '€${cost.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isSelected 
                                        ? Colors.white.withOpacity(0.9)
                                        : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                
                SizedBox(height: 20),
                
                // Start parking button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (!isInParkingZone || currentZone == null)
                      ? null
                      : () => _startParking(selectedCar, currentZone, _selectedDuration),
                    icon: parkingProvider.isLoading 
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(Icons.local_parking),
                    label: Text(
                      parkingProvider.isLoading 
                        ? 'Starting Parking...'
                        : 'Start Parking',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                
                if (!isInParkingZone) ...[
                  SizedBox(height: 8),
                  Text(
                    'You need to be in a parking zone to start parking',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                
                if (parkingProvider.errorMessage != null) ...[
                  SizedBox(height: 8),
                  Text(
                    parkingProvider.errorMessage!,
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _refreshAll() async {
    final carProvider = Provider.of<CarProvider>(context, listen: false);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);

    await Future.wait([
      locationProvider.refresh(),
      parkingProvider.refresh(),
    ]);
  }

  void _addCar() {
    // This would open an add car dialog/screen
    // For now, we'll just add a demo car
    final carProvider = Provider.of<CarProvider>(context, listen: false);
    final newCar = carProvider.createSampleCar(
      plateNumber: 'DEF456',
      make: 'BMW',
      model: 'X3',
      color: 'Black',
    );
    carProvider.addCar(newCar);
  }

  Future<void> _startParking(Car car, Zone zone, int duration) async {
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
    
    final success = await parkingProvider.startParking(
      car: car,
      zone: zone,
      durationHours: duration,
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Parking started successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(parkingProvider.errorMessage ?? 'Failed to start parking'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelParking(String ticketId) async {
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
    
    final success = await parkingProvider.cancelParking(ticketId);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Parking cancelled successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(parkingProvider.errorMessage ?? 'Failed to cancel parking'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getColorFromString(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'red': return Colors.red;
      case 'blue': return Colors.blue;
      case 'green': return Colors.green;
      case 'yellow': return Colors.yellow;
      case 'orange': return Colors.orange;
      case 'purple': return Colors.purple;
      case 'pink': return Colors.pink;
      case 'black': return Colors.black;
      case 'white': return Colors.grey.shade300;
      case 'grey': case 'gray': return Colors.grey;
      default: return Colors.grey;
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
} 