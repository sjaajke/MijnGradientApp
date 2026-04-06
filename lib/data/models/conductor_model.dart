import '../../domain/entities/conductor.dart';

/// JSON-serialisable wrapper for [Conductor].
class ConductorModel extends Conductor {
  const ConductorModel({
    required super.id,
    required super.name,
    required super.positions,
    required super.temperatures,
    required super.current,
  });

  factory ConductorModel.fromDomain(Conductor c) => ConductorModel(
        id: c.id,
        name: c.name,
        positions: c.positions,
        temperatures: c.temperatures,
        current: c.current,
      );

  factory ConductorModel.fromJson(Map<String, dynamic> json) => ConductorModel(
        id: json['id'] as String,
        name: json['name'] as String,
        positions: (json['positions'] as List).map((e) => (e as num).toDouble()).toList(),
        temperatures:
            (json['temperatures'] as List).map((e) => (e as num).toDouble()).toList(),
        current: (json['current'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'positions': positions,
        'temperatures': temperatures,
        'current': current,
      };
}
