import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/car.dart';

class CarProvider extends ChangeNotifier {
  final List<Car> _cars = [];
  Car? _selectedCar;
  bool _isLoading = false;

  List<Car> get cars => List.unmodifiable(_cars);
  Car? get selectedCar => _selectedCar;
  bool get isLoading => _isLoading;
  bool get hasCars => _cars.isNotEmpty;

  /// Initialize provider and load saved cars
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    await _loadCars();
    _setDefaultSelectedCar();

    _isLoading = false;
    notifyListeners();
  }

  /// Add a new car
  Future<void> addCar(Car car) async {
    _cars.add(car);
    
    // If this is the first car or marked as default, set as selected
    if (_selectedCar == null || car.isDefault) {
      _selectedCar = car;
      
      // Make sure only one car is marked as default
      if (car.isDefault) {
        await _updateDefaultCar(car.id);
      }
    }
    
    await _saveCars();
    notifyListeners();
  }

  /// Remove a car
  Future<void> removeCar(String carId) async {
    final carIndex = _cars.indexWhere((car) => car.id == carId);
    if (carIndex == -1) return;

    final removedCar = _cars[carIndex];
    _cars.removeAt(carIndex);

    // If removed car was selected, select another one
    if (_selectedCar?.id == carId) {
      _selectedCar = _cars.isNotEmpty ? _cars.first : null;
    }

    await _saveCars();
    notifyListeners();
  }

  /// Update an existing car
  Future<void> updateCar(Car updatedCar) async {
    final carIndex = _cars.indexWhere((car) => car.id == updatedCar.id);
    if (carIndex == -1) return;

    _cars[carIndex] = updatedCar;

    // Update selected car if it's the same one
    if (_selectedCar?.id == updatedCar.id) {
      _selectedCar = updatedCar;
    }

    // Handle default car changes
    if (updatedCar.isDefault) {
      await _updateDefaultCar(updatedCar.id);
    }

    await _saveCars();
    notifyListeners();
  }

  /// Select a car
  void selectCar(Car car) {
    _selectedCar = car;
    notifyListeners();
  }

  /// Select car by ID
  void selectCarById(String carId) {
    final car = _cars.where((car) => car.id == carId).firstOrNull;
    if (car != null) {
      _selectedCar = car;
      notifyListeners();
    }
  }

  /// Set default car
  Future<void> setDefaultCar(String carId) async {
    await _updateDefaultCar(carId);
    await _saveCars();
    notifyListeners();
  }

  /// Get car by ID
  Car? getCarById(String carId) {
    try {
      return _cars.firstWhere((car) => car.id == carId);
    } catch (e) {
      return null;
    }
  }

  /// Get car by plate number
  Car? getCarByPlateNumber(String plateNumber) {
    try {
      return _cars.firstWhere(
        (car) => car.plateNumber.toLowerCase() == plateNumber.toLowerCase()
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if plate number already exists
  bool plateNumberExists(String plateNumber, [String? excludeCarId]) {
    return _cars.any((car) => 
      car.plateNumber.toLowerCase() == plateNumber.toLowerCase() &&
      car.id != excludeCarId
    );
  }

  /// Generate unique car ID
  String _generateCarId() {
    return 'car_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Create a sample car for demo purposes
  Car createSampleCar({
    required String plateNumber,
    required String make,
    required String model,
    String? color,
    bool isDefault = false,
  }) {
    return Car(
      id: _generateCarId(),
      plateNumber: plateNumber.toUpperCase(),
      make: make,
      model: model,
      color: color,
      isDefault: isDefault,
    );
  }

  /// Update which car is marked as default
  Future<void> _updateDefaultCar(String defaultCarId) async {
    for (int i = 0; i < _cars.length; i++) {
      _cars[i] = _cars[i].copyWith(
        isDefault: _cars[i].id == defaultCarId,
      );
    }
  }

  /// Set default selected car (first default car or first car)
  void _setDefaultSelectedCar() {
    if (_cars.isEmpty) {
      _selectedCar = null;
      return;
    }

    // Try to find default car
    final defaultCar = _cars.where((car) => car.isDefault).firstOrNull;
    _selectedCar = defaultCar ?? _cars.first;
  }

  /// Load cars from shared preferences
  Future<void> _loadCars() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final carsJson = prefs.getString('user_cars');
      
      if (carsJson != null) {
        final List<dynamic> carsList = json.decode(carsJson);
        _cars.clear();
        _cars.addAll(carsList.map((json) => Car.fromJson(json)).toList());
      } else {
        // Create default demo cars if none exist
        _createDemoCars();
      }
    } catch (e) {
      print('Error loading cars: $e');
      _createDemoCars();
    }
  }

  /// Save cars to shared preferences
  Future<void> _saveCars() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final carsJson = json.encode(_cars.map((car) => car.toJson()).toList());
      await prefs.setString('user_cars', carsJson);
    } catch (e) {
      print('Error saving cars: $e');
    }
  }

  /// Create demo cars for testing
  void _createDemoCars() {
    _cars.addAll([
      Car(
        id: _generateCarId(),
        plateNumber: 'ABC123',
        make: 'Toyota',
        model: 'Camry',
        color: 'Blue',
        isDefault: true,
      ),
      Car(
        id: _generateCarId(),
        plateNumber: 'XYZ789',
        make: 'Honda',
        model: 'Civic',
        color: 'White',
        isDefault: false,
      ),
    ]);
  }

  /// Clear all cars
  Future<void> clearAllCars() async {
    _cars.clear();
    _selectedCar = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_cars');
    
    notifyListeners();
  }
} 