import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/parking_ticket.dart';
import '../models/car.dart';
import '../models/zone.dart';
import '../services/parking_service.dart';

class ParkingProvider extends ChangeNotifier {
  final ParkingService _parkingService = ParkingService();

  List<ParkingTicket> _activeTickets = [];
  List<ParkingTicket> _parkingHistory = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _refreshTimer;

  List<ParkingTicket> get activeTickets => List.unmodifiable(_activeTickets);
  List<ParkingTicket> get parkingHistory => List.unmodifiable(_parkingHistory);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasActiveParking => _activeTickets.any((ticket) => ticket.isActive);

  /// Initialize parking provider
  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _parkingService.initialize();
      await _loadParkingData();
      _setupExpirationCallbacks();
      _startRefreshTimer();
    } catch (e) {
      _errorMessage = 'Failed to initialize parking: ${e.toString()}';
      print('Error initializing ParkingProvider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Start parking for a car
  Future<bool> startParking({
    required Car car,
    required Zone zone,
    required int durationHours,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _parkingService.startParking(
        car: car,
        zone: zone,
        durationHours: durationHours,
      );

      if (result.success && result.ticket != null) {
        await _loadParkingData();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.message;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Failed to start parking: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Cancel parking
  Future<bool> cancelParking(String ticketId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _parkingService.cancelParking(ticketId);

      if (result.success) {
        await _loadParkingData();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.message;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Failed to cancel parking: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Get active parking for a specific car
  ParkingTicket? getActiveParkingForCar(String plateNumber) {
    return _parkingService.getActiveParkingForCar(plateNumber);
  }

  /// Get parking history for a specific car
  List<ParkingTicket> getParkingHistoryForCar(String plateNumber) {
    return _parkingService.getParkingHistoryForCar(plateNumber);
  }

  /// Get tickets expiring soon
  List<ParkingTicket> get expiringSoonTickets {
    return _parkingService.getExpiringSoonTickets();
  }

  /// Check if a car has active parking
  bool hasActiveParkingForCar(String plateNumber) {
    return _activeTickets.any(
      (ticket) => ticket.carPlateNumber == plateNumber && ticket.isActive
    );
  }

  /// Get next expiring ticket
  ParkingTicket? get nextExpiringTicket {
    final activeTickets = _activeTickets.where((ticket) => ticket.isActive).toList();
    if (activeTickets.isEmpty) return null;

    activeTickets.sort((a, b) => a.endTime.compareTo(b.endTime));
    return activeTickets.first;
  }

  /// Get time until next expiration
  Duration? get timeUntilNextExpiration {
    final nextTicket = nextExpiringTicket;
    if (nextTicket == null) return null;

    final now = DateTime.now();
    if (nextTicket.endTime.isBefore(now)) return Duration.zero;
    
    return nextTicket.endTime.difference(now);
  }

  /// Get formatted time until next expiration
  String? get formattedTimeUntilNextExpiration {
    final duration = timeUntilNextExpiration;
    if (duration == null) return null;

    if (duration == Duration.zero) return "Expired";

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return "${hours}h ${minutes}m";
    } else {
      return "${minutes}m";
    }
  }

  /// Refresh parking data
  Future<void> refresh() async {
    await _loadParkingData();
  }

  /// Load parking data from service
  Future<void> _loadParkingData() async {
    _activeTickets = _parkingService.activeTickets;
    _parkingHistory = _parkingService.parkingHistory;
    notifyListeners();
  }

  /// Setup expiration callbacks
  void _setupExpirationCallbacks() {
    _parkingService.addExpirationCallback((ParkingTicket expiredTicket) {
      // Update our local data when a ticket expires
      _loadParkingData();
      
      // You could also show a notification here
      print('Parking expired for ${expiredTicket.carPlateNumber} in ${expiredTicket.zoneName}');
    });
  }

  /// Start periodic refresh timer
  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(Duration(minutes: 1), (_) {
      _loadParkingData();
    });
  }

  /// Stop refresh timer
  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Calculate total cost for parking duration
  double calculateCost(Zone zone, int durationHours) {
    return zone.hourlyRate * durationHours;
  }

  /// Get parking statistics
  Map<String, dynamic> get parkingStatistics {
    final totalSessions = _parkingHistory.length;
    final totalCost = _parkingHistory.fold<double>(
      0, (sum, ticket) => sum + ticket.totalCost
    );
    final totalHours = _parkingHistory.fold<int>(
      0, (sum, ticket) => sum + ticket.durationHours
    );

    return {
      'totalSessions': totalSessions,
      'totalCost': totalCost,
      'totalHours': totalHours,
      'averageCost': totalSessions > 0 ? totalCost / totalSessions : 0.0,
      'averageDuration': totalSessions > 0 ? totalHours / totalSessions : 0.0,
    };
  }

  /// Get most used zone
  String? get mostUsedZone {
    if (_parkingHistory.isEmpty) return null;

    final zoneUsage = <String, int>{};
    for (final ticket in _parkingHistory) {
      zoneUsage[ticket.zoneName] = (zoneUsage[ticket.zoneName] ?? 0) + 1;
    }

    var mostUsedZoneName = '';
    var maxUsage = 0;
    zoneUsage.forEach((zoneName, usage) {
      if (usage > maxUsage) {
        maxUsage = usage;
        mostUsedZoneName = zoneName;
      }
    });

    return mostUsedZoneName.isNotEmpty ? mostUsedZoneName : null;
  }

  /// Clear all parking data
  Future<void> clearAllData() async {
    await _parkingService.clearAllData();
    _activeTickets.clear();
    _parkingHistory.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _stopRefreshTimer();
    _parkingService.dispose();
    super.dispose();
  }
} 