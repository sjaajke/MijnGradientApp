import 'dart:math' as math;

/// Thermal indicator based on normalized thermal resistance K = ΔT / I².
///
/// Physics background:
///   For a uniform conductor: ΔT = T − T_amb = I² × R_thermal
///   Therefore K = ΔT / I² = R_thermal  [°C/A²]
///
/// A higher K indicates a higher local thermal resistance — a possible bad
/// electrical connection or contact resistance.
///
/// Error propagation (first-order approximation):
///   dK/K = d(ΔT)/ΔT + 2 × dI/I
///   dK   = K × sqrt((d(ΔT)/ΔT)² + (2 × dI/I)²)
///
/// Examples (see static [compare]):
///
/// Normal case — two identical conductors at different currents:
///   meas1: I=100 A, T=45 °C, T_amb=20 °C  → ΔT=25, K=2.5e-3 °C/A²
///   meas2: I=120 A, T=55.2 °C, T_amb=20 °C → ΔT=35.2, K=2.44e-3 °C/A²
///   ΔK ≈ 0  →  SNR < 1  →  "Niet significant"
///
/// Small ΔT case — unreliable measurement:
///   meas1: I=50 A, T=21 °C, T_amb=20 °C → ΔT=1 °C  (near zero)
///   → dK/K is large, uncertainty dominates, SNR < 1
///
/// Bad connection case:
///   meas1: I=100 A, T=55 °C, T_amb=20 °C → K=3.5e-3
///   meas2: I=100 A, T=45 °C, T_amb=20 °C → K=2.5e-3
///   ΔK=1.0e-3, SNR >> 3  →  "Significante afwijking — mogelijke slechte verbinding"
class ThermalMeasurement {
  /// Electrical current through the conductor [A].
  final double current;

  /// Measured temperature at the measurement point [°C].
  final double temperature;

  /// Ambient (reference) temperature [°C].
  final double ambient;

  /// Absolute measurement uncertainty of the current [A].
  /// Default: 1% of current.
  final double currentError;

  /// Absolute measurement uncertainty of the temperature [°C].
  /// Default: 0.5 °C (typical IR camera / thermocouple accuracy).
  final double temperatureError;

  /// Minimum ΔT below which the measurement is considered unreliable.
  static const double _minDeltaT = 0.5; // °C

  /// Minimum current below which division is considered unsafe.
  static const double _minCurrent = 0.1; // A

  const ThermalMeasurement({
    required this.current,
    required this.temperature,
    required this.ambient,
    double? currentError,
    double? temperatureError,
  })  : currentError = currentError ?? current * 0.01,
        temperatureError = temperatureError ?? 0.5;

  // ── Validity ──────────────────────────────────────────────────────────────

  /// True when inputs are physically plausible.
  bool get isValid =>
      current > _minCurrent &&
      temperature.isFinite &&
      ambient.isFinite &&
      currentError >= 0 &&
      temperatureError >= 0;

  // ── Core calculations ─────────────────────────────────────────────────────

  /// Temperature rise above ambient: ΔT = T − T_amb  [°C].
  double deltaT() => temperature - ambient;

  /// Returns whether ΔT is large enough for reliable K computation.
  bool get isDeltaTReliable => deltaT() >= _minDeltaT;

  /// Normalized thermal indicator K = ΔT / I²  [°C/A²].
  ///
  /// Returns null when inputs are invalid or ΔT is too small.
  double? computeK() {
    if (!isValid) return null;
    final dT = deltaT();
    if (dT < _minDeltaT) return null;
    return dT / (current * current);
  }

  /// Absolute uncertainty of K using first-order error propagation:
  ///   dK = K × sqrt((dΔT/ΔT)² + (2 × dI/I)²)
  ///
  /// Returns null when K cannot be computed.
  double? computeKError() {
    final k = computeK();
    if (k == null) return null;
    final dT = deltaT();

    final relDeltaT = temperatureError / dT;
    final relCurrent = 2.0 * currentError / current;

    return k * math.sqrt(relDeltaT * relDeltaT + relCurrent * relCurrent);
  }

  // ── Comparison ────────────────────────────────────────────────────────────

  /// Compares this measurement against [other] and returns a [ComparisonResult].
  ///
  /// ΔK   = K1 − K2
  /// d(ΔK) = sqrt(dK1² + dK2²)
  /// SNR  = |ΔK| / d(ΔK)
  static ComparisonResult compare(
    ThermalMeasurement meas1,
    ThermalMeasurement meas2,
  ) {
    final k1 = meas1.computeK();
    final k2 = meas2.computeK();
    final dk1 = meas1.computeKError();
    final dk2 = meas2.computeKError();

    // Handle edge cases
    if (!meas1.isValid || !meas2.isValid) {
      return ComparisonResult.invalid('Ongeldige invoer: controleer stroom en temperatuur.');
    }
    if (k1 == null) {
      return ComparisonResult.invalid(
        'ΔT van meting 1 is te klein (${meas1.deltaT().toStringAsFixed(2)} °C). '
        'Verhoog de stroom of controleer de omgevingstemperatuur.',
      );
    }
    if (k2 == null) {
      return ComparisonResult.invalid(
        'ΔT van meting 2 is te klein (${meas2.deltaT().toStringAsFixed(2)} °C). '
        'Verhoog de stroom of controleer de omgevingstemperatuur.',
      );
    }

    final deltaK = k1 - k2;
    final uncertainty = math.sqrt(dk1! * dk1 + dk2! * dk2);

    final double snr;
    if (uncertainty < 1e-12) {
      snr = deltaK.abs() < 1e-12 ? 0.0 : double.infinity;
    } else {
      snr = deltaK.abs() / uncertainty;
    }

    final diagnostic = _buildDiagnostic(
      k1: k1,
      k2: k2,
      deltaK: deltaK,
      uncertainty: uncertainty,
      snr: snr,
      meas1: meas1,
      meas2: meas2,
    );

    return ComparisonResult(
      k1: k1,
      k2: k2,
      dk1: dk1,
      dk2: dk2,
      deltaK: deltaK,
      uncertainty: uncertainty,
      snr: snr,
      diagnostic: diagnostic,
      isValid: true,
    );
  }

  static String _buildDiagnostic({
    required double k1,
    required double k2,
    required double deltaK,
    required double uncertainty,
    required double snr,
    required ThermalMeasurement meas1,
    required ThermalMeasurement meas2,
  }) {
    final buf = StringBuffer();

    if (snr > 3.0) {
      buf.write('Significante afwijking gedetecteerd (SNR ${snr.toStringAsFixed(1)}).');
      if (deltaK > 0) {
        buf.write(' Meting 1 heeft een hogere thermische weerstand — '
            'mogelijke slechte verbinding of contactweerstand bij geleider 1.');
      } else {
        buf.write(' Meting 2 heeft een hogere thermische weerstand — '
            'mogelijke slechte verbinding of contactweerstand bij geleider 2.');
      }
    } else if (snr >= 1.0) {
      buf.write('Onzeker resultaat (SNR ${snr.toStringAsFixed(1)}). '
          'Het verschil is meetbaar maar valt binnen de meetonzekerheid. '
          'Vergroot de stroom of verbeter de meetnauwkeurigheid voor een betrouwbaarder resultaat.');
    } else {
      buf.write('Niet significant (SNR ${snr.toStringAsFixed(1)}). '
          'Het verschil is kleiner dan de meetonzekerheid — '
          'geen uitspraak mogelijk over de verbindingskwaliteit.');
    }

    // Warn about small ΔT
    if (!meas1.isDeltaTReliable || !meas2.isDeltaTReliable) {
      buf.write('\n⚠ Een of beide ΔT-waarden zijn klein — '
          'foutpropagatie vergroot de onzekerheid sterk.');
    }

    return buf.toString();
  }
}

// ── Result types ─────────────────────────────────────────────────────────────

/// Result of comparing two [ThermalMeasurement] instances.
class ComparisonResult {
  /// Thermal indicator of measurement 1  [°C/A²].
  final double? k1;

  /// Thermal indicator of measurement 2  [°C/A²].
  final double? k2;

  /// Absolute uncertainty of K1  [°C/A²].
  final double? dk1;

  /// Absolute uncertainty of K2  [°C/A²].
  final double? dk2;

  /// Difference: ΔK = K1 − K2  [°C/A²].
  final double? deltaK;

  /// Combined uncertainty of ΔK: sqrt(dK1² + dK2²)  [°C/A²].
  final double? uncertainty;

  /// Signal-to-noise ratio: |ΔK| / d(ΔK).
  final double? snr;

  /// Human-readable diagnostic string.
  final String diagnostic;

  /// Whether the comparison could be computed.
  final bool isValid;

  const ComparisonResult({
    this.k1,
    this.k2,
    this.dk1,
    this.dk2,
    this.deltaK,
    this.uncertainty,
    this.snr,
    required this.diagnostic,
    required this.isValid,
  });

  factory ComparisonResult.invalid(String reason) => ComparisonResult(
        diagnostic: reason,
        isValid: false,
      );

  /// SNR interpretation.
  SnrLevel get snrLevel {
    final s = snr;
    if (s == null) return SnrLevel.invalid;
    if (s > 3.0) return SnrLevel.significant;
    if (s >= 1.0) return SnrLevel.uncertain;
    return SnrLevel.notSignificant;
  }
}

enum SnrLevel {
  invalid,
  notSignificant,
  uncertain,
  significant,
}
