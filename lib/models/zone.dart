import 'package:json_annotation/json_annotation.dart';

part 'zone.g.dart';

@JsonSerializable()
class Zone {
  final String id;
  final String name;
  final String code;
  final double hourlyRate;
  final String smsNumber;
  final List<String> streets;

  Zone({
    required this.id,
    required this.name,
    required this.code,
    required this.hourlyRate,
    required this.smsNumber,
    required this.streets,
  });

  factory Zone.fromJson(Map<String, dynamic> json) => _$ZoneFromJson(json);
  Map<String, dynamic> toJson() => _$ZoneToJson(this);

  @override
  String toString() => 'Zone(id: $id, name: $name, code: $code)';
} 