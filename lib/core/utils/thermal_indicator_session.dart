import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight session-snapshot from the Thermal Indicator screen.
///
/// Stored as JSON in SharedPreferences under [ThermalIndicatorSessionStore.key].
/// Kept independent of the Bloc-backed analysis/comparison session model so
/// that the thermal-indicator screen can be saved/restored without migrating
/// the existing repository layer.
class ThermalIndicatorSession {
  final String id;
  final String name;
  final DateTime createdAt;
  final double ambient;
  final List<ThermalIndicatorMeasurement> measurements;
  final String? imagePath;
  final String? imageFileName;
  final String? note;

  const ThermalIndicatorSession({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.ambient,
    required this.measurements,
    this.imagePath,
    this.imageFileName,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'ambient': ambient,
        'measurements': measurements.map((m) => m.toJson()).toList(),
        if (imagePath != null) 'imagePath': imagePath,
        if (imageFileName != null) 'imageFileName': imageFileName,
        if (note != null) 'note': note,
      };

  factory ThermalIndicatorSession.fromJson(Map<String, dynamic> json) {
    return ThermalIndicatorSession(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      ambient: (json['ambient'] as num).toDouble(),
      measurements: (json['measurements'] as List)
          .map((e) =>
              ThermalIndicatorMeasurement.fromJson(e as Map<String, dynamic>))
          .toList(),
      imagePath: json['imagePath'] as String?,
      imageFileName: json['imageFileName'] as String?,
      note: json['note'] as String?,
    );
  }
}

class ThermalIndicatorMeasurement {
  final int id;
  final String label;
  final String sourceLabel;
  final double current;
  final double temperature;
  final double currentError;
  final double temperatureError;

  const ThermalIndicatorMeasurement({
    required this.id,
    required this.label,
    required this.sourceLabel,
    required this.current,
    required this.temperature,
    required this.currentError,
    required this.temperatureError,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'sourceLabel': sourceLabel,
        'current': current,
        'temperature': temperature,
        'currentError': currentError,
        'temperatureError': temperatureError,
      };

  factory ThermalIndicatorMeasurement.fromJson(Map<String, dynamic> json) {
    return ThermalIndicatorMeasurement(
      id: json['id'] as int,
      label: json['label'] as String,
      sourceLabel: json['sourceLabel'] as String,
      current: (json['current'] as num).toDouble(),
      temperature: (json['temperature'] as num).toDouble(),
      currentError: (json['currentError'] as num).toDouble(),
      temperatureError: (json['temperatureError'] as num).toDouble(),
    );
  }
}

class ThermalIndicatorSessionStore {
  static const String key = 'thermal_indicator_sessions_v1';

  /// Incremented on every save/delete so listeners (e.g. history screen)
  /// can reload after another tab modifies the store.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Signals the Thermal Indicator screen to load a given session. The
  /// history screen sets this after switching tabs; the thermal screen
  /// listens, applies, and then clears it.
  static final ValueNotifier<ThermalIndicatorSession?> pendingLoad =
      ValueNotifier<ThermalIndicatorSession?>(null);

  final SharedPreferences _prefs;
  const ThermalIndicatorSessionStore(this._prefs);

  List<ThermalIndicatorSession> loadAll() {
    final raw = _prefs.getStringList(key) ?? const [];
    final out = <ThermalIndicatorSession>[];
    for (final item in raw) {
      try {
        final map = jsonDecode(item) as Map<String, dynamic>;
        out.add(ThermalIndicatorSession.fromJson(map));
      } catch (_) {
        continue;
      }
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  Future<void> save(ThermalIndicatorSession session) async {
    final existing = loadAll().where((s) => s.id != session.id).toList();
    final updated = [session, ...existing];
    await _prefs.setStringList(
      key,
      updated.map((s) => jsonEncode(s.toJson())).toList(),
    );
    revision.value++;
  }

  Future<void> delete(String id) async {
    final existing = loadAll().where((s) => s.id != id).toList();
    await _prefs.setStringList(
      key,
      existing.map((s) => jsonEncode(s.toJson())).toList(),
    );
    revision.value++;
  }
}
