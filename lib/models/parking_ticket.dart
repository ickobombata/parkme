import 'package:json_annotation/json_annotation.dart';

part 'parking_ticket.g.dart';

@JsonSerializable()
class ParkingTicket {
  final String id;
  final String carPlateNumber;
  final String zoneCode;
  final String zoneName;
  final DateTime startTime;
  final DateTime endTime;
  final int durationHours;
  final double totalCost;
  final String smsNumber;
  final String smsText;
  final ParkingStatus status;
  final DateTime createdAt;

  ParkingTicket({
    required this.id,
    required this.carPlateNumber,
    required this.zoneCode,
    required this.zoneName,
    required this.startTime,
    required this.endTime,
    required this.durationHours,
    required this.totalCost,
    required this.smsNumber,
    required this.smsText,
    this.status = ParkingStatus.active,
    required this.createdAt,
  });

  factory ParkingTicket.fromJson(Map<String, dynamic> json) => 
      _$ParkingTicketFromJson(json);
  Map<String, dynamic> toJson() => _$ParkingTicketToJson(this);

  bool get isExpired => DateTime.now().isAfter(endTime);
  bool get isActive => status == ParkingStatus.active && !isExpired;
  
  Duration get timeRemaining {
    if (isExpired) return Duration.zero;
    return endTime.difference(DateTime.now());
  }

  String get timeRemainingFormatted {
    final remaining = timeRemaining;
    if (remaining == Duration.zero) return "Expired";
    
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    return "${hours}h ${minutes}m";
  }

  ParkingTicket copyWith({
    String? id,
    String? carPlateNumber,
    String? zoneCode,
    String? zoneName,
    DateTime? startTime,
    DateTime? endTime,
    int? durationHours,
    double? totalCost,
    String? smsNumber,
    String? smsText,
    ParkingStatus? status,
    DateTime? createdAt,
  }) {
    return ParkingTicket(
      id: id ?? this.id,
      carPlateNumber: carPlateNumber ?? this.carPlateNumber,
      zoneCode: zoneCode ?? this.zoneCode,
      zoneName: zoneName ?? this.zoneName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationHours: durationHours ?? this.durationHours,
      totalCost: totalCost ?? this.totalCost,
      smsNumber: smsNumber ?? this.smsNumber,
      smsText: smsText ?? this.smsText,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'ParkingTicket(plate: $carPlateNumber, zone: $zoneCode, expires: $endTime)';
}

enum ParkingStatus {
  @JsonValue('active')
  active,
  @JsonValue('expired')
  expired,
  @JsonValue('cancelled')
  cancelled,
} 