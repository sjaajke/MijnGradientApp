import 'dart:convert';
import 'dart:io';

/// Result of extracting radiometric data from a FLIR image via the Atlas SDK.
class FlirExtractResult {
  final bool ok;
  final String? error;
  final String? message;
  final int width;
  final int height;
  final FlirCameraInfo? camera;
  final FlirThermalParams? thermalParams;
  final FlirGps? gps;
  final FlirCompass? compass;
  final List<FlirSpot> spots;
  final double? centerTemperature;
  final FlirScale? scale;

  const FlirExtractResult({
    required this.ok,
    this.error,
    this.message,
    this.width = 0,
    this.height = 0,
    this.camera,
    this.thermalParams,
    this.gps,
    this.compass,
    this.spots = const [],
    this.centerTemperature,
    this.scale,
  });

  factory FlirExtractResult.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('error')) {
      return FlirExtractResult(
        ok: false,
        error: json['error'] as String?,
        message: json['message'] as String?,
      );
    }
    return FlirExtractResult(
      ok: json['ok'] as bool? ?? false,
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      camera: json['camera'] != null
          ? FlirCameraInfo.fromJson(json['camera'] as Map<String, dynamic>)
          : null,
      thermalParams: json['thermalParams'] != null
          ? FlirThermalParams.fromJson(
              json['thermalParams'] as Map<String, dynamic>)
          : null,
      gps: json['gps'] != null
          ? FlirGps.fromJson(json['gps'] as Map<String, dynamic>)
          : null,
      compass: json['compass'] != null
          ? FlirCompass.fromJson(json['compass'] as Map<String, dynamic>)
          : null,
      spots: (json['spots'] as List<dynamic>?)
              ?.map((e) => FlirSpot.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      centerTemperature: (json['centerTemperature'] as num?)?.toDouble(),
      scale: json['scale'] != null
          ? FlirScale.fromJson(json['scale'] as Map<String, dynamic>)
          : null,
    );
  }
}

class FlirCameraInfo {
  final String model;
  final String serial;
  final String lens;
  final String filter;
  final String programVersion;
  final double rangeMin;
  final double rangeMax;
  final int horizontalFoV;
  final double focalLength;

  const FlirCameraInfo({
    required this.model,
    required this.serial,
    required this.lens,
    required this.filter,
    required this.programVersion,
    required this.rangeMin,
    required this.rangeMax,
    required this.horizontalFoV,
    required this.focalLength,
  });

  factory FlirCameraInfo.fromJson(Map<String, dynamic> json) => FlirCameraInfo(
        model: json['model'] as String? ?? '',
        serial: json['serial'] as String? ?? '',
        lens: json['lens'] as String? ?? '',
        filter: json['filter'] as String? ?? '',
        programVersion: json['programVersion'] as String? ?? '',
        rangeMin: (json['rangeMin'] as num?)?.toDouble() ?? 0,
        rangeMax: (json['rangeMax'] as num?)?.toDouble() ?? 0,
        horizontalFoV: json['horizontalFoV'] as int? ?? 0,
        focalLength: (json['focalLength'] as num?)?.toDouble() ?? 0,
      );
}

class FlirThermalParams {
  final double emissivity;
  final double objectDistance;
  final double reflectedTemperature;
  final double atmosphericTemperature;
  final double relativeHumidity;
  final double atmosphericTransmission;

  const FlirThermalParams({
    required this.emissivity,
    required this.objectDistance,
    required this.reflectedTemperature,
    required this.atmosphericTemperature,
    required this.relativeHumidity,
    required this.atmosphericTransmission,
  });

  factory FlirThermalParams.fromJson(Map<String, dynamic> json) =>
      FlirThermalParams(
        emissivity: (json['emissivity'] as num?)?.toDouble() ?? 0,
        objectDistance: (json['objectDistance'] as num?)?.toDouble() ?? 0,
        reflectedTemperature:
            (json['reflectedTemperature'] as num?)?.toDouble() ?? 0,
        atmosphericTemperature:
            (json['atmosphericTemperature'] as num?)?.toDouble() ?? 0,
        relativeHumidity:
            (json['relativeHumidity'] as num?)?.toDouble() ?? 0,
        atmosphericTransmission:
            (json['atmosphericTransmission'] as num?)?.toDouble() ?? 0,
      );
}

class FlirGps {
  final double latitude;
  final double longitude;
  final double altitude;

  const FlirGps({
    required this.latitude,
    required this.longitude,
    required this.altitude,
  });

  factory FlirGps.fromJson(Map<String, dynamic> json) => FlirGps(
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        altitude: (json['altitude'] as num?)?.toDouble() ?? 0,
      );
}

class FlirCompass {
  final int degrees;
  final int pitch;
  final int roll;
  final int tilt;

  const FlirCompass({
    required this.degrees,
    required this.pitch,
    required this.roll,
    required this.tilt,
  });

  factory FlirCompass.fromJson(Map<String, dynamic> json) => FlirCompass(
        degrees: json['degrees'] as int? ?? 0,
        pitch: json['pitch'] as int? ?? 0,
        roll: json['roll'] as int? ?? 0,
        tilt: json['tilt'] as int? ?? 0,
      );

  String get directionLabel {
    const labels = [
      'N', 'NNO', 'NO', 'ONO', 'O', 'OZO', 'ZO', 'ZZO',
      'Z', 'ZZW', 'ZW', 'WZW', 'W', 'WNW', 'NW', 'NNW',
    ];
    return '$degrees° ${labels[((degrees % 360) / 22.5).round() % 16]}';
  }
}

class FlirScale {
  final double min;
  final double max;

  const FlirScale({required this.min, required this.max});

  factory FlirScale.fromJson(Map<String, dynamic> json) => FlirScale(
        min: (json['min'] as num?)?.toDouble() ?? 0,
        max: (json['max'] as num?)?.toDouble() ?? 100,
      );
}

class FlirSpot {
  final int id;
  final String label;
  final int x;
  final int y;
  final double temperature;
  final int state;

  const FlirSpot({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    required this.temperature,
    required this.state,
  });

  factory FlirSpot.fromJson(Map<String, dynamic> json) => FlirSpot(
        id: json['id'] as int? ?? 0,
        label: json['label'] as String? ?? '',
        x: json['x'] as int? ?? 0,
        y: json['y'] as int? ?? 0,
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0,
        state: json['state'] as int? ?? 0,
      );

  bool get isValid => state == 1;
}

/// Available palette presets (matching FLIR Atlas SDK).
enum FlirPalette {
  iron, rainbow, whitehot, blackhot, arctic, lava, rainHC,
  doubleRainbow, hottest, coldest, bw, colorwheel, colorwheel6, colorwheel12;

  String get cliName => switch (this) {
    FlirPalette.iron => 'iron',
    FlirPalette.rainbow => 'rainbow',
    FlirPalette.whitehot => 'whitehot',
    FlirPalette.blackhot => 'blackhot',
    FlirPalette.arctic => 'arctic',
    FlirPalette.lava => 'lava',
    FlirPalette.rainHC => 'rainhc',
    FlirPalette.doubleRainbow => 'doublerainbow',
    FlirPalette.hottest => 'hottest',
    FlirPalette.coldest => 'coldest',
    FlirPalette.bw => 'bw',
    FlirPalette.colorwheel => 'colorwheel',
    FlirPalette.colorwheel6 => 'colorwheel6',
    FlirPalette.colorwheel12 => 'colorwheel12',
  };

  String get displayName => switch (this) {
    FlirPalette.iron => 'Iron',
    FlirPalette.rainbow => 'Rainbow',
    FlirPalette.whitehot => 'White Hot',
    FlirPalette.blackhot => 'Black Hot',
    FlirPalette.arctic => 'Arctic',
    FlirPalette.lava => 'Lava',
    FlirPalette.rainHC => 'Rain HC',
    FlirPalette.doubleRainbow => 'Double Rainbow',
    FlirPalette.hottest => 'Hottest',
    FlirPalette.coldest => 'Coldest',
    FlirPalette.bw => 'Zwart-wit',
    FlirPalette.colorwheel => 'Color Wheel',
    FlirPalette.colorwheel6 => 'Color Wheel 6',
    FlirPalette.colorwheel12 => 'Color Wheel 12',
  };
}

/// Available color distribution modes.
enum FlirColorDist {
  linear, histogram, signal, plateau, dde, entropy, ade, fsx, lce;

  String get cliName => name;

  String get displayName => switch (this) {
    FlirColorDist.linear => 'Lineair (temp.)',
    FlirColorDist.histogram => 'Histogram EQ',
    FlirColorDist.signal => 'Lineair (signaal)',
    FlirColorDist.plateau => 'Plateau Hist. EQ',
    FlirColorDist.dde => 'DDE',
    FlirColorDist.entropy => 'Entropy',
    FlirColorDist.ade => 'ADE',
    FlirColorDist.fsx => 'FSX',
    FlirColorDist.lce => 'LCE',
  };
}

/// Isotherm type for CLI.
enum FlirIsothermType { above, below, interval }

/// Calls the native `flir_extract` CLI tool.
class FlirExtractService {
  static const _toolPath =
      '/Users/sjaaj/Flutter/MijnGradientApp/tools/flir_extract/flir_extract';
  static const _sdkLibPath =
      '/Users/sjaaj/FLIR SDK Atlas-c-sdk-macosx-xcode15-arm64-2.18.0/lib';

  static bool get isAvailable => File(_toolPath).existsSync();

  // ── Raw runner ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> _run(List<String> args) async {
    if (!File(_toolPath).existsSync()) return null;
    try {
      final result = await Process.run(
        _toolPath,
        args,
        environment: {'DYLD_LIBRARY_PATH': _sdkLibPath},
      );
      if (result.exitCode != 0) return {'ok': false, 'error': 'process', 'message': result.stderr.toString().trim()};
      return jsonDecode(result.stdout as String) as Map<String, dynamic>;
    } catch (e) {
      return {'ok': false, 'error': 'exception', 'message': e.toString()};
    }
  }

  // ── info (legacy + new) ──────────────────────────────────────────────

  static Future<FlirExtractResult?> extract(String imagePath) async {
    final json = await _run(['info', imagePath]);
    if (json == null) return null;
    return FlirExtractResult.fromJson(json);
  }

  // ── render ───────────────────────────────────────────────────────────

  static Future<String?> render(
    String imagePath,
    String outPath, {
    FlirPalette palette = FlirPalette.iron,
    FlirColorDist colorDist = FlirColorDist.linear,
    double? scaleMin,
    double? scaleMax,
  }) async {
    final args = ['render', imagePath, outPath, palette.cliName, colorDist.cliName];
    if (scaleMin != null && scaleMax != null) {
      args.addAll([scaleMin.toStringAsFixed(1), scaleMax.toStringAsFixed(1)]);
    }
    final json = await _run(args);
    if (json == null || json['ok'] != true) return null;
    return outPath;
  }

  // ── set-palette ──────────────────────────────────────────────────────

  static Future<bool> setPalette(String imagePath, String outPath, FlirPalette palette) async {
    final json = await _run(['set-palette', imagePath, outPath, palette.cliName]);
    return json?['ok'] == true;
  }

  // ── set-scale ────────────────────────────────────────────────────────

  static Future<bool> setScale(String imagePath, String outPath, double min, double max, {FlirPalette? palette}) async {
    final args = ['set-scale', imagePath, outPath, min.toStringAsFixed(1), max.toStringAsFixed(1)];
    if (palette != null) args.add(palette.cliName);
    final json = await _run(args);
    return json?['ok'] == true;
  }

  // ── set-colordist ────────────────────────────────────────────────────

  static Future<bool> setColorDist(String imagePath, String outPath, FlirColorDist mode, {FlirPalette? palette}) async {
    final args = ['set-colordist', imagePath, outPath, mode.cliName];
    if (palette != null) args.add(palette.cliName);
    final json = await _run(args);
    return json?['ok'] == true;
  }

  // ── move-spot ────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> moveSpot(String imagePath, String outPath, int id, int newX, int newY) async {
    return _run(['move-spot', imagePath, outPath, '$id', '$newX', '$newY']);
  }

  // ── remove-spot ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> removeSpot(String imagePath, String outPath, int id) async {
    return _run(['remove-spot', imagePath, outPath, '$id']);
  }

  // ── add-spot ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> addSpot(String imagePath, String outPath, int x, int y) async {
    return _run(['add-spot', imagePath, outPath, '$x', '$y']);
  }

  // ── add-rect ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> addRect(String imagePath, String outPath, int x, int y, int w, int h) async {
    return _run(['add-rect', imagePath, outPath, '$x', '$y', '$w', '$h']);
  }

  // ── add-ellipse ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> addEllipse(String imagePath, String outPath, int cx, int cy, int rx, int ry) async {
    return _run(['add-ellipse', imagePath, outPath, '$cx', '$cy', '$rx', '$ry']);
  }

  // ── add-line ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> addLine(String imagePath, String outPath, int x1, int y1, int x2, int y2) async {
    return _run(['add-line', imagePath, outPath, '$x1', '$y1', '$x2', '$y2']);
  }

  // ── add-isotherm ─────────────────────────────────────────────────────

  static Future<bool> addIsotherm(String imagePath, String outPath, FlirIsothermType type, double temp1, {double? temp2, FlirPalette? palette}) async {
    final args = ['add-isotherm', imagePath, outPath, type.name, temp1.toStringAsFixed(1)];
    if (temp2 != null) args.add(temp2.toStringAsFixed(1));
    if (palette != null) args.add(palette.cliName);
    final json = await _run(args);
    return json?['ok'] == true;
  }

  // ── set-params ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> setParams(
    String imagePath, String outPath, {
    required double emissivity,
    required double distance,
    required double reflectedTemp,
    required double humidity,
    FlirPalette? palette,
  }) async {
    final args = [
      'set-params', imagePath, outPath,
      emissivity.toStringAsFixed(4),
      distance.toStringAsFixed(2),
      reflectedTemp.toStringAsFixed(1),
      humidity.toStringAsFixed(1),
    ];
    if (palette != null) args.add(palette.cliName);
    return _run(args);
  }

  // ── get-temp ─────────────────────────────────────────────────────────

  static Future<double?> getTemperatureAt(String imagePath, int x, int y) async {
    final json = await _run(['get-temp', imagePath, '$x', '$y']);
    if (json == null || json['ok'] != true) return null;
    return (json['temperature'] as num?)?.toDouble();
  }

  // ── save ─────────────────────────────────────────────────────────────

  static Future<bool> save(String imagePath, String outPath, {String format = 'jpeg'}) async {
    final json = await _run(['save', imagePath, outPath, format]);
    return json?['ok'] == true;
  }
}
