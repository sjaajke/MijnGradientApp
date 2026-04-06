import 'dart:io';
import 'package:csv/csv.dart';
import '../entities/conductor.dart';

/// Parses a CSV file into position/temperature arrays.
///
/// Accepted formats:
///   • Header row `position,temperature` (or `pos,temp` etc.) — auto-detected.
///   • Two numeric columns separated by comma, semicolon, or tab.
///   • Both columns may carry a unit suffix (e.g. "1.25m", "42.3°C") — stripped.
class ImportCsvUseCase {
  Future<Conductor> call({
    required String filePath,
    required String conductorName,
    required double current,
    required String conductorId,
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw FileSystemException('File not found', filePath);
    }

    final content = await file.readAsString();
    final rows = _parse(content);

    final positions = <double>[];
    final temperatures = <double>[];
    bool headerSkipped = false;

    for (final row in rows) {
      if (row.length < 2) continue;

      final rawA = row[0].toString().trim();
      final rawB = row[1].toString().trim();

      // Skip header row
      if (!headerSkipped && _isHeader(rawA)) {
        headerSkipped = true;
        continue;
      }
      headerSkipped = true;

      final a = _parseDouble(rawA);
      final b = _parseDouble(rawB);

      if (a == null || b == null) continue;
      positions.add(a);
      temperatures.add(b);
    }

    if (positions.length < 3) {
      throw FormatException(
        'CSV must contain at least 3 valid (position, temperature) rows. '
        'Got ${positions.length}.',
      );
    }

    return Conductor(
      id: conductorId,
      name: conductorName,
      positions: positions,
      temperatures: temperatures,
      current: current,
    );
  }

  List<List<dynamic>> _parse(String content) {
    // Detect delimiter
    final delimiter = _detectDelimiter(content);
    const converter = CsvToListConverter(shouldParseNumbers: false);
    return converter.convert(content, fieldDelimiter: delimiter);
  }

  String _detectDelimiter(String content) {
    final firstLine = content.split('\n').first;
    if (firstLine.contains(';')) return ';';
    if (firstLine.contains('\t')) return '\t';
    return ',';
  }

  bool _isHeader(String value) {
    final lower = value.toLowerCase();
    return lower.contains('pos') ||
        lower.contains('dist') ||
        lower.contains('x') ||
        lower.contains('loc');
  }

  double? _parseDouble(String raw) {
    // Strip common unit suffixes
    final cleaned = raw.replaceAll(RegExp(r'[°Cm/A\s]'), '').trim();
    return double.tryParse(cleaned);
  }
}
