import 'package:equatable/equatable.dart';

/// A continuous region where the absolute gradient exceeds the detection threshold.
class Hotspot extends Equatable {
  final double startPosition; // metres
  final double endPosition; // metres
  final int startIndex;
  final int endIndex;
  final double peakGradient; // °C/m (absolute)
  final double length; // metres

  const Hotspot({
    required this.startPosition,
    required this.endPosition,
    required this.startIndex,
    required this.endIndex,
    required this.peakGradient,
    required this.length,
  });

  bool get isShort => length < 0.05; // < 5 cm

  @override
  List<Object?> get props =>
      [startPosition, endPosition, startIndex, endIndex, peakGradient, length];
}
