import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/parking_ticket.dart';
import '../models/zone.dart';
import '../models/car.dart';
import 'sms_service.dart';

class ParkingService {
  static final ParkingService _instance = ParkingService._internal();
  factory ParkingService() => _instance;
  ParkingService._internal();

  final SmsService _smsService = SmsService();
  final List<ParkingTicket> _activeTickets = [];
  final List<ParkingTicket> _parkingHistory = [];
  
  Timer? _notificationTimer;
  final List<Function(ParkingTicket)> _expirationCallbacks = [];

  List<ParkingTicket> get activeTickets => List.unmodifiable(_activeTickets);
  List<ParkingTicket> get parkingHistory => List.unmodifiable(_parkingHistory);

  /// Initialize the parking service
  Future<void> initialize() async {
    await _loadParkingHistory();
    await _loadActiveTickets();
    _startExpirationMonitoring();
  }

  /// Start parking for a car in a zone
  Future<ParkingResult> startParking({
    required Car car,
    required Zone zone,
    required int durationHours,
  }) async {
    try {
      // Check if car already has active parking
      final existingTicket = _activeTickets.where(
        (ticket) => ticket.carPlateNumber == car.plateNumber && ticket.isActive
      ).firstOrNull;

      if (existingTicket != null) {
        return ParkingResult(
          success: false,
          message: 'Car ${car.plateNumber} already has active parking in ${existingTicket.zoneName}',
          errorCode: ParkingErrorCode.alreadyParked,
        );
      }

      // Calculate cost
      final totalCost = zone.hourlyRate * durationHours;
      final startTime = DateTime.now();
      final endTime = startTime.add(Duration(hours: durationHours));

      // Send SMS
      final smsResult = await _smsService.sendParkingSms(
        zone: zone,
        plateNumber: car.plateNumber,
        durationHours: durationHours,
      );

      if (!smsResult.success) {
        return ParkingResult(
          success: false,
          message: 'Failed to send parking SMS: ${smsResult.message}',
          errorCode: ParkingErrorCode.smsFailed,
        );
      }

      // Create parking ticket
      final ticket = ParkingTicket(
        id: _generateTicketId(),
        carPlateNumber: car.plateNumber,
        zoneCode: zone.code,
        zoneName: zone.name,
        startTime: startTime,
        endTime: endTime,
        durationHours: durationHours,
        totalCost: totalCost,
        smsNumber: zone.smsNumber,
        smsText: smsResult.smsText ?? '',
        status: ParkingStatus.active,
        createdAt: DateTime.now(),
      );

      // Add to active tickets
      _activeTickets.add(ticket);
      _parkingHistory.add(ticket);

      // Save to storage
      await _saveActiveTickets();
      await _saveParkingHistory();

      return ParkingResult(
        success: true,
        message: 'Parking started successfully',
        ticket: ticket,
      );

    } catch (e) {
      print('Error starting parking: $e');
      return ParkingResult(
        success: false,
        message: 'Failed to start parking: ${e.toString()}',
        errorCode: ParkingErrorCode.unknownError,
      );
    }
  }

  /// Cancel active parking
  Future<ParkingResult> cancelParking(String ticketId) async {
    try {
      final ticketIndex = _activeTickets.indexWhere((t) => t.id == ticketId);
      if (ticketIndex == -1) {
        return ParkingResult(
          success: false,
          message: 'Parking ticket not found',
          errorCode: ParkingErrorCode.ticketNotFound,
        );
      }

      final ticket = _activeTickets[ticketIndex];
      if (!ticket.isActive) {
        return ParkingResult(
          success: false,
          message: 'Parking ticket is not active',
          errorCode: ParkingErrorCode.ticketNotActive,
        );
      }

      // Send cancellation SMS (if supported by your city)
      // This is optional - not all cities support SMS cancellation
      // final smsResult = await _smsService.sendCancellationSms(
      //   zone: zone,
      //   plateNumber: ticket.carPlateNumber,
      // );

      // Update ticket status
      final updatedTicket = ticket.copyWith(
        status: ParkingStatus.cancelled,
      );

      _activeTickets[ticketIndex] = updatedTicket;
      
      // Update in history
      final historyIndex = _parkingHistory.indexWhere((t) => t.id == ticketId);
      if (historyIndex != -1) {
        _parkingHistory[historyIndex] = updatedTicket;
      }

      // Save changes
      await _saveActiveTickets();
      await _saveParkingHistory();

      return ParkingResult(
        success: true,
        message: 'Parking cancelled successfully',
        ticket: updatedTicket,
      );

    } catch (e) {
      print('Error cancelling parking: $e');
      return ParkingResult(
        success: false,
        message: 'Failed to cancel parking: ${e.toString()}',
        errorCode: ParkingErrorCode.unknownError,
      );
    }
  }

  /// Get active parking for a specific car
  ParkingTicket? getActiveParkingForCar(String plateNumber) {
    try {
      return _activeTickets.firstWhere(
        (ticket) => ticket.carPlateNumber == plateNumber && ticket.isActive
      );
    } catch (e) {
      return null;
    }
  }

  /// Get parking history for a specific car
  List<ParkingTicket> getParkingHistoryForCar(String plateNumber) {
    return _parkingHistory
        .where((ticket) => ticket.carPlateNumber == plateNumber)
        .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Add expiration callback
  void addExpirationCallback(Function(ParkingTicket) callback) {
    _expirationCallbacks.add(callback);
  }

  /// Remove expiration callback
  void removeExpirationCallback(Function(ParkingTicket) callback) {
    _expirationCallbacks.remove(callback);
  }

  /// Start monitoring for expiring tickets
  void _startExpirationMonitoring() {
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(Duration(minutes: 1), (_) {
      _checkExpiredTickets();
    });
  }

  /// Check for expired tickets and notify
  void _checkExpiredTickets() {
    final now = DateTime.now();
    
    for (int i = 0; i < _activeTickets.length; i++) {
      final ticket = _activeTickets[i];
      
      if (ticket.isActive && ticket.endTime.isBefore(now)) {
        // Mark as expired
        final expiredTicket = ticket.copyWith(status: ParkingStatus.expired);
        _activeTickets[i] = expiredTicket;
        
        // Update in history
        final historyIndex = _parkingHistory.indexWhere((t) => t.id == ticket.id);
        if (historyIndex != -1) {
          _parkingHistory[historyIndex] = expiredTicket;
        }
        
        // Notify callbacks
        for (final callback in _expirationCallbacks) {
          callback(expiredTicket);
        }
        
        // Save changes
        _saveActiveTickets();
        _saveParkingHistory();
      }
    }
  }

  /// Get tickets expiring soon (within next 15 minutes)
  List<ParkingTicket> getExpiringSoonTickets() {
    final threshold = DateTime.now().add(Duration(minutes: 15));
    return _activeTickets
        .where((ticket) => 
          ticket.isActive && 
          ticket.endTime.isBefore(threshold) &&
          ticket.endTime.isAfter(DateTime.now())
        )
        .toList();
  }

  /// Generate unique ticket ID
  String _generateTicketId() {
    return 'ticket_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Load active tickets from storage
  Future<void> _loadActiveTickets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ticketsJson = prefs.getString('active_tickets');
      if (ticketsJson != null) {
        final List<dynamic> ticketList = json.decode(ticketsJson);
        _activeTickets.clear();
        _activeTickets.addAll(
          ticketList.map((json) => ParkingTicket.fromJson(json)).toList()
        );
      }
    } catch (e) {
      print('Error loading active tickets: $e');
    }
  }

  /// Save active tickets to storage
  Future<void> _saveActiveTickets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ticketsJson = json.encode(
        _activeTickets.map((ticket) => ticket.toJson()).toList()
      );
      await prefs.setString('active_tickets', ticketsJson);
    } catch (e) {
      print('Error saving active tickets: $e');
    }
  }

  /// Load parking history from storage
  Future<void> _loadParkingHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('parking_history');
      if (historyJson != null) {
        final List<dynamic> historyList = json.decode(historyJson);
        _parkingHistory.clear();
        _parkingHistory.addAll(
          historyList.map((json) => ParkingTicket.fromJson(json)).toList()
        );
      }
    } catch (e) {
      print('Error loading parking history: $e');
    }
  }

  /// Save parking history to storage
  Future<void> _saveParkingHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = json.encode(
        _parkingHistory.map((ticket) => ticket.toJson()).toList()
      );
      await prefs.setString('parking_history', historyJson);
    } catch (e) {
      print('Error saving parking history: $e');
    }
  }

  /// Clear all data
  Future<void> clearAllData() async {
    _activeTickets.clear();
    _parkingHistory.clear();
    _notificationTimer?.cancel();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_tickets');
    await prefs.remove('parking_history');
  }

  /// Dispose resources
  void dispose() {
    _notificationTimer?.cancel();
    _expirationCallbacks.clear();
  }
}

/// Result of parking operations
class ParkingResult {
  final bool success;
  final String message;
  final ParkingTicket? ticket;
  final ParkingErrorCode? errorCode;

  ParkingResult({
    required this.success,
    required this.message,
    this.ticket,
    this.errorCode,
  });

  @override
  String toString() => 'ParkingResult(success: $success, message: $message)';
}

/// Parking error codes
enum ParkingErrorCode {
  alreadyParked,
  smsFailed,
  ticketNotFound,
  ticketNotActive,
  unknownError,
} 