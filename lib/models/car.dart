import 'package:json_annotation/json_annotation.dart';

part 'car.g.dart';

@JsonSerializable()
class Car {
  final String id;
  final String plateNumber;
  final String make;
  final String model;
  final String? color;
  final bool isDefault;

  Car({
    required this.id,
    required this.plateNumber,
    required this.make,
    required this.model,
    this.color,
    this.isDefault = false,
  });

  factory Car.fromJson(Map<String, dynamic> json) => _$CarFromJson(json);
  Map<String, dynamic> toJson() => _$CarToJson(this);

  Car copyWith({
    String? id,
    String? plateNumber,
    String? make,
    String? model,
    String? color,
    bool? isDefault,
  }) {
    return Car(
      id: id ?? this.id,
      plateNumber: plateNumber ?? this.plateNumber,
      make: make ?? this.make,
      model: model ?? this.model,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  String toString() => 'Car(plateNumber: $plateNumber, make: $make, model: $model)';
} 