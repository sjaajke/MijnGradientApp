import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

/// Invoergegevens voor één meting die geëxporteerd wordt naar Excel.
class MeasurementExportRow {
  final String label;
  final String source;
  final double current;
  final double currentError;
  final double temperature;
  final double temperatureError;

  const MeasurementExportRow({
    required this.label,
    required this.source,
    required this.current,
    required this.currentError,
    required this.temperature,
    required this.temperatureError,
  });
}

/// Bouwt en slaat het thermische indicator Excel-rapport op.
///
/// Het rapport bevat twee bladen:
/// - **Berekeningen**: invoertabel + werkende Excel-formules voor K, dK, SNR en
///   paarsgewijze en kruis-vergelijking.
/// - **Uitleg**: toelichting op alle formules + NPR 8040-1 referentietabellen.
class ThermalExcelExportService {
  // ── Rij-layout (0-gebaseerde dart-indices) ─────────────────────────────────
  //
  // 0  : Titel
  // 1  : Datum
  // 2  : (leeg)
  // 3  : "1. INVOER METINGEN"
  // 4  : Kolomkoppen invoer
  // 5-10: Meting 1-6 data  →  Excel rijen 6-11
  // 11 : (leeg)
  // 12 : "2. BEREKENDE K-WAARDEN"
  // 13 : Kolomkoppen K
  // 14-19: K-formules meting 1-6  →  Excel rijen 15-20
  // 20 : (leeg)
  // 21 : "3. PAARSGEWIJZE VERGELIJKING"
  // 22 : Kolomkoppen paarsgewijs
  // 23-25: Paren 1↔2, 3↔4, 5↔6  →  Excel rijen 24-26
  // 26 : (leeg)
  // 27 : "4. KRUIS-VERGELIJKING"
  // 28 : Referentie-K rij  →  Excel rij 29
  // 29 : Kolomkoppen kruis
  // 30-35: Meting 1-6 kruis  →  Excel rijen 31-36

  /// Genereert het Excel-bestand en geeft het tijdelijke bestandspad terug.
  static Future<String> export({
    required List<MeasurementExportRow> measurements,
    required double tamb,
  }) async {
    assert(measurements.length == 6, 'Exact 6 metingen vereist');

    final excel = Excel.createExcel();

    // Verwijder het standaard blad
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final calcSheet = excel['Berekeningen'];
    final uitlegSheet = excel['Uitleg'];

    _buildCalcSheet(calcSheet, measurements, tamb);
    _buildUitlegSheet(uitlegSheet);

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Excel-codering mislukt');

    final dir = await getTemporaryDirectory();
    await dir.create(recursive: true);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/thermische_K_$ts.xlsx');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  // ── Hulpfuncties ──────────────────────────────────────────────────────────

  // Standaard stijl (General format) – vereist voor DoubleCellValue/IntCellValue.
  // Zonder expliciete CellStyle geeft de package een crash tijdens encode().
  static final _defaultStyle = CellStyle();

  static void _c(Sheet sheet, int row, int col, CellValue value,
      {CellStyle? style}) {
    final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = value;
    // Altijd een stijl instellen zodat numberFormat aanwezig is tijdens encode.
    cell.cellStyle = style ?? _defaultStyle;
  }

  // ── Blad 1: Berekeningen ──────────────────────────────────────────────────

  static void _buildCalcSheet(
    Sheet sheet,
    List<MeasurementExportRow> measurements,
    double tamb,
  ) {
    // Stijlen
    final titleStyle = CellStyle(bold: true, fontSize: 14);
    final sectionStyle = CellStyle(bold: true, fontSize: 12);
    final headerStyle = CellStyle(bold: true);

    // ─── Titel ───────────────────────────────────────────────────────────────
    _c(sheet, 0, 0,
        TextCellValue('Thermische indicator K = ΔT / I²  [°C/A²]'),
        style: titleStyle);
    _c(sheet, 1, 0,
        TextCellValue(
            'Gegenereerd op: ${DateTime.now().toString().substring(0, 16)}'));

    // ─── 1. Invoer ────────────────────────────────────────────────────────────
    _c(sheet, 3, 0, TextCellValue('1. INVOER METINGEN'), style: sectionStyle);

    // Kolomkoppen (dart rij 4 = Excel rij 5)
    _c(sheet, 4, 0, TextCellValue('Meting'), style: headerStyle);
    _c(sheet, 4, 1, TextCellValue('Bron'), style: headerStyle);
    _c(sheet, 4, 2, TextCellValue('I  [A]'), style: headerStyle);
    _c(sheet, 4, 3, TextCellValue('dI  [A]'), style: headerStyle);
    _c(sheet, 4, 4, TextCellValue('T  [°C]'), style: headerStyle);
    _c(sheet, 4, 5, TextCellValue('dT  [°C]'), style: headerStyle);
    _c(sheet, 4, 6, TextCellValue('T_amb  [°C]'), style: headerStyle);

    // Data (dart rijen 5-10 = Excel rijen 6-11)
    for (int i = 0; i < 6; i++) {
      final m = measurements[i];
      final row = 5 + i;
      _c(sheet, row, 0, TextCellValue(m.label));
      _c(sheet, row, 1, TextCellValue(m.source));
      _c(sheet, row, 2, DoubleCellValue(m.current));
      _c(sheet, row, 3, DoubleCellValue(m.currentError));
      _c(sheet, row, 4, DoubleCellValue(m.temperature));
      _c(sheet, row, 5, DoubleCellValue(m.temperatureError));
      _c(sheet, row, 6, DoubleCellValue(tamb));
    }

    // ─── 2. K-waarden ─────────────────────────────────────────────────────────
    _c(sheet, 12, 0, TextCellValue('2. BEREKENDE K-WAARDEN'),
        style: sectionStyle);

    // Kolomkoppen (dart rij 13 = Excel rij 14)
    _c(sheet, 13, 0, TextCellValue('Meting'), style: headerStyle);
    _c(sheet, 13, 1, TextCellValue('ΔT  [°C]'), style: headerStyle);
    _c(sheet, 13, 2, TextCellValue('K  [°C/A²]'), style: headerStyle);
    _c(sheet, 13, 3, TextCellValue('dK  [°C/A²]'), style: headerStyle);
    _c(sheet, 13, 4, TextCellValue('dK/K  [%]'), style: headerStyle);
    // Kolom H (index 7): interne hulpwaarde voor MIN-berekening in kruis-vergelijking
    _c(sheet, 13, 7, TextCellValue('K_intern (hulp)'), style: headerStyle);

    // K-formules per meting (dart rijen 14-19 = Excel rijen 15-20)
    //
    // Invoer meting i zit op:  Excel-rij = 5 + i  (i is 1-gebaseerd)
    // K-rij meting i zit op:   Excel-rij = 14 + i
    for (int i = 1; i <= 6; i++) {
      final iE = 5 + i; // invoer Excel-rij
      final kE = 14 + i; // K Excel-rij
      final dr = kE - 1; // dart rij

      _c(sheet, dr, 0, TextCellValue('Meting $i'));

      // ΔT = T − T_amb
      _c(sheet, dr, 1, FormulaCellValue('E$iE-G$iE'));

      // K = IF(AND(ΔT≥0,5 ; I>0,1) ; ΔT/I² ; "—")
      _c(sheet, dr, 2, FormulaCellValue(
          'IF(AND(B$kE>=0.5,C$iE>0.1),B$kE/C$iE^2,"--")'));

      // dK = K × √((dT/ΔT)² + (2·dI/I)²)
      _c(sheet, dr, 3, FormulaCellValue(
          'IF(ISNUMBER(C$kE),'
          'C$kE*SQRT((F$iE/B$kE)^2+(2*D$iE/C$iE)^2),'
          '"--")'));

      // dK/K  [%]
      _c(sheet, dr, 4, FormulaCellValue(
          'IF(ISNUMBER(C$kE),D$kE/C$kE*100,"--")'));

      // K_intern: K indien geldig, anders 1E+30 (t.b.v. MIN in kruis-vergelijking)
      _c(sheet, dr, 7, FormulaCellValue(
          'IF(ISNUMBER(C$kE),C$kE,1E+30)'));
    }

    // ─── 3. Paarsgewijze vergelijking ─────────────────────────────────────────
    _c(sheet, 21, 0, TextCellValue('3. PAARSGEWIJZE VERGELIJKING'),
        style: sectionStyle);

    // Kolomkoppen (dart rij 22 = Excel rij 23)
    _c(sheet, 22, 0, TextCellValue('Vergelijking'), style: headerStyle);
    _c(sheet, 22, 1, TextCellValue('K₁  [°C/A²]'), style: headerStyle);
    _c(sheet, 22, 2, TextCellValue('K₂  [°C/A²]'), style: headerStyle);
    _c(sheet, 22, 3, TextCellValue('ΔK  [°C/A²]'), style: headerStyle);
    _c(sheet, 22, 4, TextCellValue('Onzekerheid  [°C/A²]'),
        style: headerStyle);
    _c(sheet, 22, 5, TextCellValue('SNR'), style: headerStyle);
    _c(sheet, 22, 6, TextCellValue('Oordeel'), style: headerStyle);

    // Paren (dart rijen 23-25 = Excel rijen 24-26)
    //   Paar j (0-gebaseerd): metingen a = 2j+1, b = 2j+2
    for (int j = 0; j < 3; j++) {
      final a = 2 * j + 1; // meting a (1-gebaseerd)
      final b = 2 * j + 2; // meting b
      final pE = 24 + j; // paar Excel-rij (24, 25, 26)
      final dr = pE - 1; // dart rij
      final kEA = 14 + a; // K Excel-rij meting a
      final kEB = 14 + b; // K Excel-rij meting b

      _c(sheet, dr, 0, TextCellValue('Meting $a \u2194 Meting $b'));

      // K₁ en K₂ (verwijzing naar K-tabel)
      _c(sheet, dr, 1, FormulaCellValue('C$kEA'));
      _c(sheet, dr, 2, FormulaCellValue('C$kEB'));

      // ΔK = K₁ − K₂
      _c(sheet, dr, 3, FormulaCellValue(
          'IF(AND(ISNUMBER(B$pE),ISNUMBER(C$pE)),B$pE-C$pE,"--")'));

      // Onzekerheid = √(dK₁² + dK₂²)
      _c(sheet, dr, 4, FormulaCellValue(
          'IF(AND(ISNUMBER(D$kEA),ISNUMBER(D$kEB)),'
          'SQRT(D$kEA^2+D$kEB^2),"--")'));

      // SNR = |ΔK| / Onzekerheid
      _c(sheet, dr, 5, FormulaCellValue(
          'IF(AND(ISNUMBER(D$pE),ISNUMBER(E$pE),E$pE>0),'
          'ABS(D$pE)/E$pE,"--")'));

      // Oordeel op basis van SNR-drempelwaarden
      _c(sheet, dr, 6, FormulaCellValue(
          'IF(ISNUMBER(F$pE),'
          'IF(F$pE>=3,"Significant",'
          'IF(F$pE>=1,"Onzeker","Niet significant")),"--")'));
    }

    // ─── 4. Kruis-vergelijking ────────────────────────────────────────────────
    _c(sheet, 27, 0,
        TextCellValue(
            '4. KRUIS-VERGELIJKING  (alle metingen t.o.v. laagste K)'),
        style: sectionStyle);

    // Referentie-K rij (dart rij 28 = Excel rij 29)
    _c(sheet, 28, 0,
        TextCellValue('Referentie K  (minimale geldige K van alle metingen):'),
        style: headerStyle);
    // K_ref = MIN van alle K_intern waarden (kolom H, rijen 15-20)
    _c(sheet, 28, 1, FormulaCellValue('MIN(H15:H20)')); // B29
    _c(sheet, 28, 3, TextCellValue('Bijbehorende dK_ref:'),
        style: headerStyle);
    // dK_ref via INDEX/MATCH op dezelfde kolom H
    _c(sheet, 28, 4,
        FormulaCellValue(
            'INDEX(D15:D20,MATCH(MIN(H15:H20),H15:H20,0))')); // E29

    // Kolomkoppen (dart rij 29 = Excel rij 30)
    _c(sheet, 29, 0, TextCellValue('Meting'), style: headerStyle);
    _c(sheet, 29, 1, TextCellValue('Bron'), style: headerStyle);
    _c(sheet, 29, 2, TextCellValue('K  [°C/A²]'), style: headerStyle);
    _c(sheet, 29, 3, TextCellValue('dK  [°C/A²]'), style: headerStyle);
    _c(sheet, 29, 4, TextCellValue('ΔK vs ref  [°C/A²]'), style: headerStyle);
    _c(sheet, 29, 5, TextCellValue('Onzekerheid  [°C/A²]'),
        style: headerStyle);
    _c(sheet, 29, 6, TextCellValue('SNR'), style: headerStyle);
    _c(sheet, 29, 7, TextCellValue('Oordeel'), style: headerStyle);

    // Kruis-data (dart rijen 30-35 = Excel rijen 31-36)
    //
    // K_ref staat in $B$29, dK_ref in $E$29 (absolute verwijzingen).
    for (int i = 1; i <= 6; i++) {
      final m = measurements[i - 1];
      final dr = 29 + i; // dart rij 30..35
      final cE = dr + 1; // kruis Excel-rij 31..36
      final kE = 14 + i; // K-tabel Excel-rij

      _c(sheet, dr, 0, TextCellValue(m.label));
      _c(sheet, dr, 1, TextCellValue(m.source));

      // K_i en dK_i (verwijzing naar K-tabel)
      _c(sheet, dr, 2, FormulaCellValue('C$kE'));
      _c(sheet, dr, 3, FormulaCellValue('D$kE'));

      // ΔK vs referentie  (K_ref = \$B\$29)
      _c(sheet, dr, 4, FormulaCellValue(
          'IF(ISNUMBER(C$cE),C$cE-\$B\$29,"--")'));

      // Onzekerheid = √(dK_i² + dK_ref²)  (dK_ref = \$E\$29)
      _c(sheet, dr, 5, FormulaCellValue(
          'IF(AND(ISNUMBER(D$cE),ISNUMBER(\$E\$29)),'
          'SQRT(D$cE^2+\$E\$29^2),"--")'));

      // SNR vs referentie
      _c(sheet, dr, 6, FormulaCellValue(
          'IF(AND(ISNUMBER(E$cE),ISNUMBER(F$cE),F$cE>0),'
          'ABS(E$cE)/F$cE,"--")'));

      // Oordeel  (SNR < 0,001 → dit IS de referentie)
      _c(sheet, dr, 7, FormulaCellValue(
          'IF(ISNUMBER(G$cE),'
          'IF(G$cE<0.001,"Referentie (laagste K)",'
          'IF(G$cE>=3,"Significant",'
          'IF(G$cE>=1,"Onzeker","Niet significant"))),"--")'));
    }
  }

  // ── Blad 2: Uitleg ────────────────────────────────────────────────────────

  static void _buildUitlegSheet(Sheet sheet) {
    final titleStyle = CellStyle(bold: true, fontSize: 14);
    final sectionStyle = CellStyle(bold: true, fontSize: 12);
    final headerStyle = CellStyle(bold: true);

    int row = 0;

    void add(int col, CellValue value, {CellStyle? style}) {
      _c(sheet, row, col, value, style: style);
    }

    void skip([int n = 1]) => row += n;
    void nl() => row++;

    // ─── Titel ───────────────────────────────────────────────────────────────
    add(0,
        TextCellValue(
            'Uitleg — Thermische indicator K = ΔT / I²  [°C/A²]'),
        style: titleStyle);
    skip(2);

    // ─── 1. Fysisch model ─────────────────────────────────────────────────────
    add(0, TextCellValue('1. FYSISCH MODEL'), style: sectionStyle);
    nl();
    add(0, TextCellValue('Formule:'), style: headerStyle);
    add(1, TextCellValue('K  =  ΔT / I²   [°C/A²]'));
    nl();
    add(0, TextCellValue('K'), style: headerStyle);
    add(1, TextCellValue('Genormaliseerde thermische weerstand van de verbinding.'));
    nl();
    add(0, TextCellValue('ΔT'), style: headerStyle);
    add(1, TextCellValue(
        'T_gemeten − T_omgeving  [°C]  — minimaal 0,5 °C voor betrouwbare meting.'));
    nl();
    add(0, TextCellValue('I'), style: headerStyle);
    add(1, TextCellValue('Elektrische stroom  [A]  — minimaal 0,1 A.'));
    nl();
    add(0, TextCellValue('Interpretatie:'), style: headerStyle);
    add(1, TextCellValue(
        'Een hogere K-waarde betekent meer opwarming per A² — wijst op verhoogde '
        'thermische weerstand (slechte verbinding of contactweerstand).'));
    skip(2);

    // ─── 2. Foutpropagatie ────────────────────────────────────────────────────
    add(0, TextCellValue('2. FOUTPROPAGATIE (eerste-orde benadering)'),
        style: sectionStyle);
    nl();
    add(0, TextCellValue('Formule:'), style: headerStyle);
    add(1, TextCellValue('dK  =  K × √( (dT / ΔT)² + (2 · dI / I)² )'));
    nl();
    add(0, TextCellValue('dT'), style: headerStyle);
    add(1, TextCellValue('Absolute onzekerheid temperatuurmeting  [°C]'));
    nl();
    add(0, TextCellValue('dI'), style: headerStyle);
    add(1, TextCellValue('Absolute onzekerheid stroommeting  [A]'));
    nl();
    add(0, TextCellValue('dK'), style: headerStyle);
    add(1, TextCellValue('Absolute onzekerheid K  [°C/A²]'));
    nl();
    add(0, TextCellValue('Let op:'), style: headerStyle);
    add(1, TextCellValue(
        'Bij kleine ΔT domineert de meetonzekerheid — relatieve fout dK/K wordt groot.'));
    skip(2);

    // ─── 3. SNR ───────────────────────────────────────────────────────────────
    add(0, TextCellValue('3. SIGNAAL-RUISVERHOUDING (SNR)'),
        style: sectionStyle);
    nl();
    add(0, TextCellValue('Formule:'), style: headerStyle);
    add(1, TextCellValue('SNR  =  |ΔK|  /  √( dK₁² + dK₂² )'));
    nl();
    add(0, TextCellValue('ΔK'), style: headerStyle);
    add(1, TextCellValue('K₁ − K₂  (verschil in thermische indicator)'));
    nl();
    add(0, TextCellValue('√(dK₁²+dK₂²)'), style: headerStyle);
    add(1, TextCellValue('Gecombineerde meetonzekerheid  [°C/A²]'));
    skip(1);
    add(0, TextCellValue('SNR-drempelwaarden:'), style: headerStyle);
    nl();
    add(0, TextCellValue('SNR ≥ 3,0'), style: headerStyle);
    add(1, TextCellValue(
        'Significant — meetbare afwijking; mogelijke slechte verbinding.'));
    nl();
    add(0, TextCellValue('1,0 ≤ SNR < 3,0'), style: headerStyle);
    add(1, TextCellValue(
        'Onzeker — verschil meetbaar maar deels binnen meetonzekerheid. '
        'Aanvullend onderzoek aanbevolen.'));
    nl();
    add(0, TextCellValue('SNR < 1,0'), style: headerStyle);
    add(1, TextCellValue(
        'Niet significant — verschil kleiner dan meetonzekerheid; '
        'geen uitspraak over verbindingskwaliteit.'));
    skip(2);

    // ─── 4. Kruis-vergelijking ────────────────────────────────────────────────
    add(0, TextCellValue('4. KRUIS-VERGELIJKING'), style: sectionStyle);
    nl();
    add(0, TextCellValue('Stap 1:'), style: headerStyle);
    add(1, TextCellValue('Bereken K en dK voor alle metingen.'));
    nl();
    add(0, TextCellValue('Stap 2:'), style: headerStyle);
    add(1, TextCellValue(
        'De meting met de LAAGSTE K is de referentie (minste thermische weerstand = beste verbinding).'));
    nl();
    add(0, TextCellValue('Stap 3:'), style: headerStyle);
    add(1, TextCellValue(
        'Bereken per meting: SNR = |K_i − K_ref| / √(dK_i² + dK_ref²).'));
    nl();
    add(0, TextCellValue('Stap 4:'), style: headerStyle);
    add(1, TextCellValue('Interpreteer SNR met de drempelwaarden hierboven.'));
    nl();
    add(0, TextCellValue('Opmerking:'), style: headerStyle);
    add(1, TextCellValue(
        'In het blad "Berekeningen" is de referentie herkenbaar aan '
        'SNR ≈ 0 of "Referentie (laagste K)" in de Oordeel-kolom.'));
    skip(2);

    // ─── 5. Gebruik Excel-blad ────────────────────────────────────────────────
    add(0, TextCellValue('5. GEBRUIK VAN HET EXCEL-BLAD'), style: sectionStyle);
    nl();
    add(0, TextCellValue('Invoer aanpassen:'), style: headerStyle);
    add(1, TextCellValue(
        'Pas I, dI, T, dT of T_amb aan in sectie 1 — alle resultaten herberekenen automatisch.'));
    nl();
    add(0, TextCellValue('Kolom H (K_intern):'), style: headerStyle);
    add(1, TextCellValue(
        'Hulpkolom voor de MIN-berekening in de kruis-vergelijking. '
        'Verberg of verwijder deze kolom NIET.'));
    nl();
    add(0, TextCellValue('Ongeldige meting (--):'), style: headerStyle);
    add(1, TextCellValue(
        '"--" verschijnt als ΔT < 0,5 °C of I ≤ 0,1 A. '
        'Vergroot de stroom of controleer T_amb.'));
    nl();
    add(0, TextCellValue('NPR 8040-1:'), style: headerStyle);
    add(1, TextCellValue(
        'Gebruik de referentietabellen hieronder voor handmatige NPR-beoordeling.'));
    skip(2);

    // ─── 6. NPR 8040-1 tabellen ──────────────────────────────────────────────
    add(0, TextCellValue('6. NPR 8040-1 — REFERENTIETABELLEN'),
        style: sectionStyle);
    nl();
    add(0, TextCellValue(
        'NPR 8040-1 beschrijft drie methoden voor beoordeling van '
        'thermografische metingen in elektrotechnische installaties.'));
    skip(2);

    // Methode 1
    add(0, TextCellValue(
        'Methode 1: Max. toelaatbare temperatuur isolatiemateriaal geleider'),
        style: headerStyle);
    nl();
    add(0, TextCellValue('Materiaal'), style: headerStyle);
    add(1, TextCellValue('Tmax  [°C]'), style: headerStyle);
    add(2, TextCellValue('Correctie op isolatie  [°C]'), style: headerStyle);
    add(3, TextCellValue('Voorbeeld'), style: headerStyle);
    nl();
    for (final r in [
      ['PVC', '70', '−5  (= 65)', 'VD / H05VV-F / H07V-K'],
      ['QWPK', '75', '−5  (= 70)', 'H05BQ-F / H07BQ-F'],
      ['XLPE', '90', '−5  (= 85)', 'YMvK / XMvK'],
      ['EVA', '90', '−5  (= 85)', 'H05G-U / H07G-U'],
      ['Siliconenrubber', '180', '−5  (= 175)', 'NEN-EN-IEC 60204-1'],
    ]) {
      for (int c = 0; c < r.length; c++) {
        add(c, TextCellValue(r[c]));
      }
      nl();
    }
    skip(1);

    // Methode 2
    add(0, TextCellValue(
        'Methode 2: Max. toelaatbare temp. elektr. isolatiemateriaal component (IEC 60085)'),
        style: headerStyle);
    nl();
    add(0, TextCellValue('Klasse'), style: headerStyle);
    add(1, TextCellValue('Klassetemperatuur  [°C]'), style: headerStyle);
    add(2, TextCellValue('Tmax  [°C]'), style: headerStyle);
    nl();
    for (final r in [
      ['Y', '90', '105'],
      ['A', '105', '120'],
      ['E', '120', '130'],
      ['B', '130', '155'],
      ['F', '155', '180'],
      ['H', '180', '200'],
    ]) {
      for (int c = 0; c < r.length; c++) {
        add(c, TextCellValue(r[c]));
      }
      nl();
    }
    skip(1);

    // Methode 3
    add(0, TextCellValue(
        'Methode 3: Max. toelaatbare temperatuurstijging per component (T_amb 5–40 °C)'),
        style: headerStyle);
    nl();
    add(0, TextCellValue('Component'), style: headerStyle);
    add(1, TextCellValue('Onderdeel'), style: headerStyle);
    add(2, TextCellValue('Max. stijging  [K]'), style: headerStyle);
    add(3, TextCellValue('Norm'), style: headerStyle);
    nl();
    for (final r in [
      ['Installatieautomaat', 'Behuizing', '70', 'NEN-EN-IEC 61439'],
      ['Schakelaar/scheider', 'Behuizing', '70', 'NEN-EN-IEC 61439'],
      ['Motorbeveiliging spoel', 'Klasse A', '85', 'NEN-EN-IEC 60947-4-1'],
      ['Motorbeveiliging spoel', 'Klasse E', '100', 'NEN-EN-IEC 60947-4-1'],
      ['Motorbeveiliging spoel', 'Klasse B', '110', 'NEN-EN-IEC 60947-4-1'],
      ['Motorbeveiliging spoel', 'Klasse F', '135', 'NEN-EN-IEC 60947-4-1'],
      ['Motorbeveiliging spoel', 'Klasse H', '160', 'NEN-EN-IEC 60947-4-1'],
      ['Magneetschakelaar spoel', 'Klasse A', '85', 'NEN-EN-IEC 61095'],
      ['Magneetschakelaar spoel', 'Klasse E', '100', 'NEN-EN-IEC 61095'],
      ['Magneetschakelaar spoel', 'Klasse B', '110', 'NEN-EN-IEC 61095'],
      ['Magneetschakelaar spoel', 'Klasse F', '135', 'NEN-EN-IEC 61095'],
      ['Magneetschakelaar spoel', 'Klasse H', '160', 'NEN-EN-IEC 61095'],
      ['Bedieningsknop', 'Kunststof', '25', 'NEN-EN-IEC 60947-1'],
      ['Schakel-/verdeelinrichting', 'Kunststof', '40', 'NEN-EN-IEC 61439-1'],
    ]) {
      for (int c = 0; c < r.length; c++) {
        add(c, TextCellValue(r[c]));
      }
      nl();
    }
  }
}
