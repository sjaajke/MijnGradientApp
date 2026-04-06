import 'dart:convert';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/analysis_result.dart';
import '../../domain/entities/comparison_result.dart';
import '../../domain/entities/hotspot.dart';
import '../../domain/entities/measurement_session.dart';
import 'conductor_model.dart';

/// JSON-serialisable [MeasurementSession].
///
/// Note: [AnalysisResult] and [ComparisonResult] are stored in a condensed
/// form (pre-computed metrics only) because re-running the analysis on load
/// is cheap and avoids schema migrations.
class SessionModel extends MeasurementSession {
  const SessionModel({
    required super.id,
    required super.name,
    required super.createdAt,
    required super.conductorA,
    super.conductorB,
    required super.analysisA,
    super.analysisB,
    super.comparison,
  });

  factory SessionModel.fromDomain(MeasurementSession s) => SessionModel(
        id: s.id,
        name: s.name,
        createdAt: s.createdAt,
        conductorA: s.conductorA,
        conductorB: s.conductorB,
        analysisA: s.analysisA,
        analysisB: s.analysisB,
        comparison: s.comparison,
      );

  // ──────────────────────────────────────────────────────────────────────────
  // Serialisation helpers

  static AnalysisResult _analysisFromJson(Map<String, dynamic> j) {
    final conductor = ConductorModel.fromJson(j['conductor'] as Map<String, dynamic>);
    final hotspots = (j['hotspots'] as List)
        .map((h) => Hotspot(
              startPosition: (h['startPosition'] as num).toDouble(),
              endPosition: (h['endPosition'] as num).toDouble(),
              startIndex: h['startIndex'] as int,
              endIndex: h['endIndex'] as int,
              peakGradient: (h['peakGradient'] as num).toDouble(),
              length: (h['length'] as num).toDouble(),
            ))
        .toList();

    final gradients = (j['gradients'] as List)
        .map((e) => (e as num).toDouble())
        .toList();
    final effectiveTemps = (j['effectiveTemps'] as List)
        .map((e) => (e as num).toDouble())
        .toList();

    return AnalysisResult(
      conductor: conductor,
      effectiveTemps: effectiveTemps,
      gradients: gradients,
      deltaT: (j['deltaT'] as num).toDouble(),
      maxTemperature: (j['maxTemperature'] as num).toDouble(),
      minTemperature: (j['minTemperature'] as num).toDouble(),
      maxAbsGradient: (j['maxAbsGradient'] as num).toDouble(),
      meanAbsGradient: (j['meanAbsGradient'] as num).toDouble(),
      normalizedGradient: (j['normalizedGradient'] as num).toDouble(),
      hotspots: hotspots,
      totalHotspotLength: (j['totalHotspotLength'] as num).toDouble(),
      hotspotFactor: (j['hotspotFactor'] as num).toDouble(),
      smoothingMethod: SmoothingMethod.values.firstWhere(
        (e) => e.name == j['smoothingMethod'],
        orElse: () => SmoothingMethod.none,
      ),
    );
  }

  static Map<String, dynamic> _analysisToJson(AnalysisResult a) => {
        'conductor': ConductorModel.fromDomain(a.conductor).toJson(),
        'effectiveTemps': a.effectiveTemps,
        'gradients': a.gradients,
        'deltaT': a.deltaT,
        'maxTemperature': a.maxTemperature,
        'minTemperature': a.minTemperature,
        'maxAbsGradient': a.maxAbsGradient,
        'meanAbsGradient': a.meanAbsGradient,
        'normalizedGradient': a.normalizedGradient,
        'hotspots': a.hotspots
            .map((h) => {
                  'startPosition': h.startPosition,
                  'endPosition': h.endPosition,
                  'startIndex': h.startIndex,
                  'endIndex': h.endIndex,
                  'peakGradient': h.peakGradient,
                  'length': h.length,
                })
            .toList(),
        'totalHotspotLength': a.totalHotspotLength,
        'hotspotFactor': a.hotspotFactor,
        'smoothingMethod': a.smoothingMethod.name,
      };

  static ComparisonResult? _comparisonFromJson(
    Map<String, dynamic>? j,
    AnalysisResult a,
    AnalysisResult? b,
  ) {
    if (j == null || b == null) return null;
    return ComparisonResult(
      conductorA: a,
      conductorB: b,
      gradientDeviation: (j['gradientDeviation'] as num).toDouble(),
      hotspotDeviation: (j['hotspotDeviation'] as num).toDouble(),
      deltaTDeviation: (j['deltaTDeviation'] as num).toDouble(),
      status: ConditionStatus.values.firstWhere(
        (e) => e.name == j['status'],
        orElse: () => ConditionStatus.ok,
      ),
      primaryDiagnosis: j['primaryDiagnosis'] as String,
      flags: (j['flags'] as List).map((e) => e as String).toList(),
      tolerance: (j['tolerance'] as num).toDouble(),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Public JSON API

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    final analysisA = _analysisFromJson(json['analysisA'] as Map<String, dynamic>);
    final analysisB = json['analysisB'] != null
        ? _analysisFromJson(json['analysisB'] as Map<String, dynamic>)
        : null;

    return SessionModel(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      conductorA: ConductorModel.fromJson(
        json['conductorA'] as Map<String, dynamic>,
      ),
      conductorB: json['conductorB'] != null
          ? ConductorModel.fromJson(json['conductorB'] as Map<String, dynamic>)
          : null,
      analysisA: analysisA,
      analysisB: analysisB,
      comparison: _comparisonFromJson(
        json['comparison'] as Map<String, dynamic>?,
        analysisA,
        analysisB,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'conductorA': ConductorModel.fromDomain(conductorA).toJson(),
        'conductorB': conductorB != null
            ? ConductorModel.fromDomain(conductorB!).toJson()
            : null,
        'analysisA': _analysisToJson(analysisA),
        'analysisB': analysisB != null ? _analysisToJson(analysisB!) : null,
        'comparison': comparison != null
            ? {
                'gradientDeviation': comparison!.gradientDeviation,
                'hotspotDeviation': comparison!.hotspotDeviation,
                'deltaTDeviation': comparison!.deltaTDeviation,
                'status': comparison!.status.name,
                'primaryDiagnosis': comparison!.primaryDiagnosis,
                'flags': comparison!.flags,
                'tolerance': comparison!.tolerance,
              }
            : null,
      };

  String toJsonString() => jsonEncode(toJson());
}
