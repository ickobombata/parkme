import 'package:flutter_sms/flutter_sms.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/zone.dart';
import '../models/parking_ticket.dart';

class SmsService {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  /// Check and request SMS permissions
  Future<bool> checkAndRequestSmsPermissions() async {
    var status = await Permission.sms.status;
    if (status.isDenied) {
      status = await Permission.sms.request();
      if (status.isDenied) {
        return false;
      }
    }

    if (status.isPermanentlyDenied) {
      return false;
    }

    return true;
  }

  /// Format SMS message for parking ticket
  String formatParkingMessage({
    required String zoneCode,
    required String plateNumber,
    required int durationHours,
  }) {
    // Format: "ZoneCode PlateNumber Duration"
    // Example: "CC ABC123 2"
    return '$zoneCode $plateNumber $durationHours';
  }

  /// Send parking SMS
  Future<SmsResult> sendParkingSms({
    required Zone zone,
    required String plateNumber,
    required int durationHours,
  }) async {
    try {
      final hasPermission = await checkAndRequestSmsPermissions();
      if (!hasPermission) {
        return SmsResult(
          success: false,
          message: 'SMS permission not granted',
          errorCode: SmsErrorCode.permissionDenied,
        );
      }

      final smsText = formatParkingMessage(
        zoneCode: zone.code,
        plateNumber: plateNumber,
        durationHours: durationHours,
      );

      print('Sending SMS to ${zone.smsNumber}: $smsText');

      final result = await sendSMS(
        message: smsText,
        recipients: [zone.smsNumber],
        sendDirect: true,
      );

      return SmsResult(
        success: true,
        message: 'SMS sent successfully',
        smsText: smsText,
        recipient: zone.smsNumber,
      );

    } catch (e) {
      print('Error sending SMS: $e');
      return SmsResult(
        success: false,
        message: 'Failed to send SMS: ${e.toString()}',
        errorCode: SmsErrorCode.sendFailed,
      );
    }
  }

  /// Send cancellation SMS
  Future<SmsResult> sendCancellationSms({
    required Zone zone,
    required String plateNumber,
  }) async {
    try {
      final hasPermission = await checkAndRequestSmsPermissions();
      if (!hasPermission) {
        return SmsResult(
          success: false,
          message: 'SMS permission not granted',
          errorCode: SmsErrorCode.permissionDenied,
        );
      }

      // Format cancellation message - this might vary by city
      // Common format: "STOP ZoneCode PlateNumber"
      final smsText = 'STOP ${zone.code} $plateNumber';

      print('Sending cancellation SMS to ${zone.smsNumber}: $smsText');

      final result = await sendSMS(
        message: smsText,
        recipients: [zone.smsNumber],
        sendDirect: true,
      );

      return SmsResult(
        success: true,
        message: 'Cancellation SMS sent successfully',
        smsText: smsText,
        recipient: zone.smsNumber,
      );

    } catch (e) {
      print('Error sending cancellation SMS: $e');
      return SmsResult(
        success: false,
        message: 'Failed to send cancellation SMS: ${e.toString()}',
        errorCode: SmsErrorCode.sendFailed,
      );
    }
  }

  /// Check if SMS was sent successfully (basic verification)
  bool verifySmsDelivery(SmsResult result) {
    // In a real implementation, you might want to:
    // - Check SMS delivery reports
    // - Wait for confirmation SMS from parking service
    // - Validate against known response patterns
    return result.success;
  }

  /// Parse confirmation SMS from parking service
  ParkingConfirmation? parseConfirmationSms(String smsBody, String sender) {
    // This would parse incoming SMS confirmations from the parking service
    // Format might be: "Parking confirmed. Zone: CC, Plate: ABC123, Expires: 14:30"
    try {
      // Basic parsing logic - would need to be customized for your city's format
      if (smsBody.toLowerCase().contains('parking confirmed') ||
          smsBody.toLowerCase().contains('confirmed')) {
        return ParkingConfirmation(
          isConfirmed: true,
          confirmationId: DateTime.now().millisecondsSinceEpoch.toString(),
          message: smsBody,
          receivedAt: DateTime.now(),
        );
      } else if (smsBody.toLowerCase().contains('error') ||
                 smsBody.toLowerCase().contains('invalid')) {
        return ParkingConfirmation(
          isConfirmed: false,
          confirmationId: DateTime.now().millisecondsSinceEpoch.toString(),
          message: smsBody,
          receivedAt: DateTime.now(),
          errorMessage: smsBody,
        );
      }
    } catch (e) {
      print('Error parsing confirmation SMS: $e');
    }
    return null;
  }

  /// Get SMS sending status
  Future<bool> canSendSms() async {
    final hasPermission = await checkAndRequestSmsPermissions();
    return hasPermission;
  }

  /// Open SMS app with pre-filled message
  Future<void> openSmsApp({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      await sendSMS(
        message: message,
        recipients: [phoneNumber],
        sendDirect: false, // This will open the SMS app instead of sending directly
      );
    } catch (e) {
      print('Error opening SMS app: $e');
    }
  }
}

/// Result of SMS sending operation
class SmsResult {
  final bool success;
  final String message;
  final String? smsText;
  final String? recipient;
  final SmsErrorCode? errorCode;

  SmsResult({
    required this.success,
    required this.message,
    this.smsText,
    this.recipient,
    this.errorCode,
  });

  @override
  String toString() => 'SmsResult(success: $success, message: $message)';
}

/// SMS error codes
enum SmsErrorCode {
  permissionDenied,
  sendFailed,
  invalidRecipient,
  networkError,
}

/// Parking confirmation from SMS
class ParkingConfirmation {
  final bool isConfirmed;
  final String confirmationId;
  final String message;
  final DateTime receivedAt;
  final String? errorMessage;

  ParkingConfirmation({
    required this.isConfirmed,
    required this.confirmationId,
    required this.message,
    required this.receivedAt,
    this.errorMessage,
  });

  @override
  String toString() => 'ParkingConfirmation(confirmed: $isConfirmed, id: $confirmationId)';
} 