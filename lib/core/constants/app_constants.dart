/// Global constants and shared enumerations.
class AppConstants {
  AppConstants._();

  static const double defaultHotspotFactor = 2.0;
  static const double defaultTolerance = 0.15; // 15 %
  static const double warningThreshold = 0.15; // 15 %
  static const double faultThreshold = 0.30; // 30 %
  static const int defaultMovingAverageWindow = 5;

  /// A hotspot is considered "short + steep" when its length is below this (m).
  static const double shortHotspotThreshold = 0.05;

  /// Normalised gradient above which a short hotspot is flagged as a defect.
  static const double steepNormGradientThreshold = 0.5;
}

enum SmoothingMethod {
  none,
  movingAverage,
  savitzkyGolay;

  String get label {
    switch (this) {
      case SmoothingMethod.none:
        return 'None';
      case SmoothingMethod.movingAverage:
        return 'Moving Average';
      case SmoothingMethod.savitzkyGolay:
        return 'Savitzky-Golay';
    }
  }
}

enum ConditionStatus {
  ok,
  warning,
  fault;

  String get label {
    switch (this) {
      case ConditionStatus.ok:
        return 'OK';
      case ConditionStatus.warning:
        return 'WARNING';
      case ConditionStatus.fault:
        return 'FAULT';
    }
  }
}
