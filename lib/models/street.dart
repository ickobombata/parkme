import 'package:json_annotation/json_annotation.dart';

part 'street.g.dart';

@JsonSerializable()
class Street {
  final String name;
  final String zoneId;
  final List<StreetCoordinate> coordinates;

  Street({
    required this.name,
    required this.zoneId,
    required this.coordinates,
  });

  factory Street.fromJson(Map<String, dynamic> json) => _$StreetFromJson(json);
  Map<String, dynamic> toJson() => _$StreetToJson(this);

  @override
  String toString() => 'Street(name: $name, zoneId: $zoneId)';
}

@JsonSerializable()
class StreetCoordinate {
  final double latitude;
  final double longitude;
  final double radius; // radius in meters for geofencing

  StreetCoordinate({
    required this.latitude,
    required this.longitude,
    this.radius = 50.0, // default 50 meters
  });

  factory StreetCoordinate.fromJson(Map<String, dynamic> json) => 
      _$StreetCoordinateFromJson(json);
  Map<String, dynamic> toJson() => _$StreetCoordinateToJson(this);

  @override
  String toString() => 'StreetCoordinate(lat: $latitude, lng: $longitude)';
} 