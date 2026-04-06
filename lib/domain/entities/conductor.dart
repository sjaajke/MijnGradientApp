import 'package:equatable/equatable.dart';

/// A single conductor measurement set.
class Conductor extends Equatable {
  final String id;
  final String name;

  /// Positions along the conductor (metres).
  final List<double> positions;

  /// Emissivity-corrected, calibrated temperatures (°C) matching [positions].
  final List<double> temperatures;

  /// Electrical current through the conductor (Amperes).
  final double current;

  const Conductor({
    required this.id,
    required this.name,
    required this.positions,
    required this.temperatures,
    required this.current,
  });

  int get pointCount => positions.length;

  bool get isValid =>
      positions.length == temperatures.length && positions.length >= 3;

  double get conductorLength =>
      positions.isEmpty ? 0 : positions.last - positions.first;

  Conductor copyWith({
    String? id,
    String? name,
    List<double>? positions,
    List<double>? temperatures,
    double? current,
  }) {
    return Conductor(
      id: id ?? this.id,
      name: name ?? this.name,
      positions: positions ?? this.positions,
      temperatures: temperatures ?? this.temperatures,
      current: current ?? this.current,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, positions, temperatures, current];
}
