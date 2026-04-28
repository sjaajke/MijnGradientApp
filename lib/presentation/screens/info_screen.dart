import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'flir_sdk_info_screen.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Hoe werken de berekeningen?')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thermische indicator K = ΔT / I²',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'De app berekent de genormaliseerde thermische weerstand K uit FLIR-meetpunten. '
                  'Daarbovenop toont de app stroomgecorrigeerde ΔT-formules, een K-vergelijking '
                  'tegen een referentiemeting, regressie van reeksen A/B en een NPR 8040-1 beoordeling.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Stap 1: Invoer ────────────────────────────────────────────────
          const _StepCard(
            step: '1',
            title: 'Invoer — FLIR-afbeelding & meetpunten',
            icon: Icons.thermostat_rounded,
            color: AppTheme.chartA,
            paragraphs: [
              'Open een FLIR radiometrische afbeelding (JPEG met ingebedde thermische data).',
              'De app leest de meetpunten (spots) uit de afbeelding en kent ze automatisch toe aan 6 metingen, gegroepeerd in 3 paren: 1↔2, 3↔4, 5↔6.',
              'Temperatuur T (°C) wordt per meting ingevuld; de overige invoer is gedeeld: T_amb, exponent n, I₁ voor metingen 1/3/5, I₂ voor metingen 2/4/6, plus δI en δT.',
              'De foutpropagatie gebruikt dus één gedeelde stroomfout δI en één gedeelde temperatuurfout δT voor alle 6 metingen.',
              'Via de FLIR Editor kun je spots verplaatsen, toevoegen en de afbeelding opslaan. De temperatuurwaarden worden automatisch bijgewerkt.',
            ],
          ),

          // ── Stap 2: K berekenen ───────────────────────────────────────────
          const _StepCard(
            step: '2',
            title: 'Berekening van K',
            icon: Icons.functions_rounded,
            color: AppTheme.chartExpected,
            paragraphs: [
              'Voor een uniforme geleider geldt: ΔT = T − T_amb = I² × R_thermisch.',
              'Daaruit volgt: K = ΔT / I² = R_thermisch  [°C/A²].',
              'K is de genormaliseerde thermische weerstand — onafhankelijk van de stroomsterkte.',
              'Een hogere K betekent een hogere lokale thermische weerstand, wat kan wijzen op een slechte verbinding of contactweerstand.',
              'De berekening is alleen betrouwbaar als ΔT groot genoeg is (≥ 0,5 °C). Bij een klein ΔT domineert de meetonzekerheid.',
            ],
          ),

          // ── Formules K ────────────────────────────────────────────────────
          _FormulaCard(
            title: 'Formules — K-indicator',
            rows: const [
              ('ΔT', 'ΔT = T − T_amb  [°C]'),
              ('K', 'K = ΔT / I²  [°C/A²]'),
            ],
          ),

          // ── Stap 3: Foutpropagatie ────────────────────────────────────────
          const _StepCard(
            step: '3',
            title: 'Foutpropagatie',
            icon: Icons.error_outline_rounded,
            color: AppTheme.chartGradient,
            paragraphs: [
              'De meetonzekerheid van K wordt berekend via eerste-orde foutpropagatie.',
              'De relatieve fout in K hangt af van de relatieve fout in ΔT en de relatieve fout in de stroom.',
              'Omdat K afhankelijk is van I², wordt de stroomfout met factor 2 vermenigvuldigd.',
              'Bij klein ΔT (dicht bij de omgevingstemperatuur) wordt de relatieve fout δΔT/ΔT groot, waardoor de onzekerheid in K sterk toeneemt.',
            ],
          ),

          // ── Formules foutpropagatie ────────────────────────────────────────
          _FormulaCard(
            title: 'Formules — foutpropagatie',
            rows: const [
              ('δK', 'δK = K × √( (δΔT/ΔT)² + (2×δI/I)² )'),
              ('δΔT', 'δΔT = δT  (meetfout temperatuur)'),
              ('δI', 'δI = opgegeven meetfout stroom'),
            ],
          ),

          // ── Stap 4: SNR vergelijking ──────────────────────────────────────
          const _StepCard(
            step: '4',
            title: 'Vergelijking via SNR',
            icon: Icons.compare_arrows_rounded,
            color: AppTheme.chartB,
            paragraphs: [
              'Twee metingen worden vergeleken door het verschil ΔK = K₁ − K₂ te berekenen.',
              'De gecombineerde onzekerheid is: δ(ΔK) = √(δK₁² + δK₂²).',
              'De signaal-ruisverhouding SNR = |ΔK| / δ(ΔK) bepaalt of het verschil significant is.',
              'SNR > 3: significante afwijking — mogelijke slechte verbinding.',
              'SNR 1–3: onzeker resultaat — het verschil is meetbaar maar valt binnen de onzekerheid.',
              'SNR < 1: niet significant — geen uitspraak mogelijk.',
            ],
          ),

          // ── Formules SNR ──────────────────────────────────────────────────
          _FormulaCard(
            title: 'Formules — vergelijking',
            rows: const [
              ('ΔK', 'ΔK = K₁ − K₂  [°C/A²]'),
              ('δ(ΔK)', 'δ(ΔK) = √( δK₁² + δK₂² )'),
              ('SNR', 'SNR = |ΔK| / δ(ΔK)'),
            ],
          ),

          // ── Stap 5: ΔT-gecorrigeerde formules ─────────────────────────────
          const _StepCard(
            step: '5',
            title: 'ΔT-gecorrigeerde vergelijking',
            icon: Icons.bolt_rounded,
            color: AppTheme.accent,
            paragraphs: [
              'Naast de K-vergelijking toont het scherm meerdere aanvullende formules die het temperatuurverschil corrigeren voor stroom.',
              'Deze formules zijn vooral nuttig wanneer de stromen door beide geleiders verschillen (I_A ≠ I_B).',
              'Alle formules gebruiken ΔT_A = T_A − T_amb en ΔT_B = T_B − T_amb als temperatuurverschillen boven omgeving.',
              'Er zijn twee families: formules met I²-correctie en formules met een instelbare exponent n. Standaard staat n = 2.',
              'Een uitkomst dicht bij nul, of een bijna gelijke waarde van ΔT_A/I_Aⁿ en ΔT_B/I_Bⁿ, duidt op thermisch vergelijkbaar gedrag.',
            ],
          ),

          // ── Formules ΔT-correctie ─────────────────────────────────────────
          _FormulaCard(
            title: 'Formules — ΔT-gecorrigeerd',
            rows: const [
              (
                'ΔT%',
                '[ΔT_A − (I_A/I_B)ⁿ × ΔT_B] / ΔT_A × 100%\nRelatieve afwijking met instelbare exponent n',
              ),
              (
                'ΔT_n',
                'ΔT_A − (I_A/I_B)ⁿ × ΔT_B\nAbsolute afwijking met instelbare exponent n',
              ),
              (
                'ΔT/Iⁿ',
                'ΔT_A/I_Aⁿ  versus  ΔT_B/I_Bⁿ\nDe kaart markeert of beide vrijwel gelijk zijn',
              ),
              (
                'ΔT_corr',
                'ΔT_A − (I_A²/I_B²) × ΔT_B\nStroomgewogen temperatuurverschil per punt',
              ),
              (
                'Δ(I²/ΔT)',
                'I_A²/ΔT_A − I_B²/ΔT_B\nVerschil in omgekeerde thermische verhouding',
              ),
              (
                'Δ(I²-ratio)',
                '(I_A²/I_B²) − (ΔT_A/ΔT_B)\nVerschil tussen stroomverhouding en temperatuurverhouding',
              ),
              (
                'Δ(ΔT/I²)',
                'ΔT_A/I_A² − ΔT_B/I_B²  [°C/A²]\nDirect verschil in thermische weerstand',
              ),
            ],
          ),

          // ── Stap 6: Meetparen ─────────────────────────────────────────────
          const _StepCard(
            step: '6',
            title: '3 meetparen (paarsgewijze vergelijking)',
            icon: Icons.grid_view_rounded,
            color: AppTheme.chartHotspot,
            paragraphs: [
              'De app vergelijkt 3 onafhankelijke meetparen: Meting 1↔2, Meting 3↔4 en Meting 5↔6.',
              'Elk paar vergelijkt typisch twee vergelijkbare punten — bijvoorbeeld dezelfde verbinding aan fase A en fase B.',
              'Per paar worden ΔK, de gecombineerde onzekerheid δ(ΔK) en de SNR berekend.',
              'Door meerdere paren te vergelijken kun je patronen herkennen: is de afwijking lokaal (één paar) of systematisch (alle paren)?',
              'Meetpunten worden automatisch toegewezen vanuit de FLIR-spots, maar kunnen handmatig worden aangepast via de dropdowns.',
            ],
          ),

          // ── Stap 7: K-rangschikking ───────────────────────────────────────
          const _StepCard(
            step: '7',
            title: 'Vergelijking alle metingen — K-rangschikking',
            icon: Icons.leaderboard_rounded,
            color: AppTheme.chartB,
            paragraphs: [
              'Na het drukken op "Bereken" verschijnt een overzichtskaart met alle bruikbare K-waarden, gesorteerd van hoog naar laag.',
              'Voor de referentievergelijking gebruikt het huidige scherm standaard Meting 1 als referentie. Als die ontbreekt, wordt de eerste beschikbare meting gebruikt.',
              'Per meting wordt K/K_ref getoond: hoe de K-waarde zich verhoudt tot die referentiemeting.',
              'De SNR per meting ten opzichte van de referentie is een getekende vergelijking: (K_n − K_ref) / √(δK_n² + δK_ref²). Vooral positieve waarden boven 3 tellen als significante verhoging.',
              'De balklengte in de tabel is alleen een visuele schaal ten opzichte van de hoogste K in de lijst.',
              'Gebruik de K-rangschikking samen met de paarsgewijze vergelijking voor een volledig beeld van alle meetpunten.',
            ],
          ),

          // ── Formules K-rangschikking ──────────────────────────────────────
          _FormulaCard(
            title: 'Formules — K-rangschikking (actuele schermlogica)',
            rows: const [
              (
                'K_ref',
                'K_ref = K₁  [°C/A²]\nAls meting 1 ontbreekt: eerste beschikbare meting',
              ),
              (
                'K/K_ref',
                'verhouding = K_n / K_ref  [dimensieloos]\nVergelijking met de gekozen referentie',
              ),
              (
                'SNR_n',
                'SNR_n = (K_n − K_ref) / √(δK_n² + δK_ref²)\nPositief en ≥ 3: significant hoger dan referentie',
              ),
            ],
          ),

          // ── Stap 8: NPR 8040-1 ────────────────────────────────────────────
          const _StepCard(
            step: '8',
            title: 'NPR 8040-1 beoordeling (methoden 1, 2, 3)',
            icon: Icons.rule_rounded,
            color: Color(0xFF388E3C),
            paragraphs: [
              'De NPR 8040-1 beoordeling vergelijkt de gemeten temperaturen rechtstreeks met de maximale toelaatbare grenswaarden uit de norm.',
              'Methode 1 — isolatiemateriaal geleider: de gemeten temperatuur mag de maximale toelaatbare temperatuur van het isolatiemateriaal niet overschrijden '
                  '(bijv. PVC 70 °C, XLPE 90 °C). Meting op de isolatie van een ader: T_max − 5 K.',
              'Methode 2 — temperatuurklasse component (IEC 60085): de temperatuur mag de T_max van de gekozen klasse niet overschrijden '
                  '(klasse Y: 105 °C t/m klasse H: 200 °C).',
              'Methode 3 — temperatuurstijging onderdeel: ΔT_mc = T_mc − T_amb mag de maximale toelaatbare stijging ΔT_s,max van het onderdeel niet overschrijden '
                  '(bijv. behuizing 70 K, spoel klasse F 135 K). Geldig bij 5 °C ≤ T_amb ≤ 40 °C.',
              'Per meting verschijnt direct: "Directe actie vereist" bij overschrijding, of "Binnen grenswaarde".',
              'De beoordeling werkt live: waarden worden bijgewerkt zodra temperaturen of T_amb worden gewijzigd.',
            ],
          ),

          // ── Formules NPR 8040-1 ────────────────────────────────────────────
          _FormulaCard(
            title: 'Formules — NPR 8040-1',
            rows: const [
              (
                'Methode 1',
                'T_mc ≤ T_max (isolatiemateriaal)  [°C]\nBijv. PVC: T_max = 70 °C  |  op isolatie: T_max − 5 K',
              ),
              (
                'Methode 2',
                'T_mc ≤ T_max (IEC 60085 klasse)  [°C]\nKlasse A: T_max = 120 °C  |  Klasse F: T_max = 180 °C',
              ),
              (
                'Methode 3',
                'ΔT_mc = T_mc − T_amb ≤ ΔT_s,max  [K]\nGeldig voor 5 °C ≤ T_amb ≤ 40 °C',
              ),
            ],
          ),

          // ── Stap 9: Regressie ────────────────────────────────────────────
          const _StepCard(
            step: '9',
            title: 'Regressieanalyse — stroomnormalisatie & diagnose',
            icon: Icons.show_chart_rounded,
            color: AppTheme.primaryDark,
            paragraphs: [
              'Het regressiescherm vergelijkt twee reeksen: Reeks A = metingen 1/3/5 en Reeks B = metingen 2/4/6.',
              'Optioneel wordt eerst stroomnormalisatie toegepast naar een referentiestroom I_ref. Daardoor worden temperatuurverschillen herleid naar gelijke belasting.',
              'Daarna wordt per reeks een lineaire regressie over 3 equidistante punten berekend: helling m, intercept b, fit-kwaliteit R² en residu van het middelpunt.',
              'De diagnose vergelijkt vooral Δm = |m_A − m_B| met de ingestelde tolerantie. Kleine Δm betekent vergelijkbaar warmteverloop.',
              'Bij gelijke hellingen maar duidelijk verschillende starttemperaturen meldt het scherm een vermoedelijke stroomonbalans. Bij grotere afwijkingen volgt een thermografische diagnose, zoals lokale hotspot of overgangsweerstand nabij aansluiting.',
            ],
          ),

          _FormulaCard(
            title: 'Formules — regressie & normalisatie',
            rows: const [
              (
                'ΔT_norm',
                'ΔT_norm = (T − T_amb) × (I_ref/I)²\nStroomnormalisatie naar één referentiestroom',
              ),
              ('T_norm', 'T_norm = T_amb + ΔT_norm'),
              (
                'm',
                'm = (T₃ − T₁) / 2  [°C/positie]\nHelling van de lineaire regressie',
              ),
              (
                'Δm',
                'Δm = |m_A − m_B|  [°C/positie]\nVergelijking van Reeks A en B',
              ),
              ('R²', 'R² < 0,50 laag  |  R² < 0,80 matig  |  R² ≥ 0,80 goed'),
            ],
          ),

          // ── FLIR SDK handleiding ──────────────────────────────────────────
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x221A237E),
                child: Icon(Icons.camera_outlined, color: Color(0xFF1A237E)),
              ),
              title: const Text(
                'FLIR Atlas SDK — handleiding',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Commando\'s, compileren, paletten, parameters en problemen oplossen.',
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FlirSdkInfoScreen()),
              ),
            ),
          ),
          const SizedBox(height: 4),

          // ── Stap 10: Sessies ───────────────────────────────────────────────
          const _StepCard(
            step: '10',
            title: 'Sessies opslaan en herladen',
            icon: Icons.save_outlined,
            color: AppTheme.primary,
            paragraphs: [
              'Via het opslaan-icoon (rechts boven in het K-scherm) wordt de huidige sessie opgeslagen: alle 6 metingen, T_amb, het gekoppelde FLIR-bestand en een optionele notitie.',
              'Opgeslagen sessies verschijnen in het tabblad "Historie" onder het kopje "Thermische indicator sessies".',
              'Via het drie-puntjes-menu op een sessie kun je de sessie bekijken, opnieuw laden in het K-scherm, of verwijderen.',
              '"Laden in K-scherm" vult alle invoervelden automatisch in en schakelt naar het K-tabblad.',
              'Sessies blijven bewaard na het sluiten van de app (opgeslagen via SharedPreferences).',
            ],
          ),

          // ── Interpretatie ─────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Interpretatie',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Paarsgewijze vergelijking (1↔2, 3↔4, 5↔6)',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const _HintRow(
                    label: 'SNR < 1',
                    description:
                        'verschil kleiner dan meetruis — geen uitspraak mogelijk over verbindingskwaliteit.',
                  ),
                  const _HintRow(
                    label: 'SNR 1–3',
                    description:
                        'meetbaar verschil, maar binnen onzekerheid. Verhoog stroom of verbeter meetnauwkeurigheid.',
                  ),
                  const _HintRow(
                    label: 'SNR > 3',
                    description:
                        'significant verschil — mogelijke slechte verbinding of contactweerstand.',
                  ),
                  const _HintRow(
                    label: 'Klein ΔT (< 1 °C)',
                    description:
                        'meting is onbetrouwbaar door grote relatieve fout. Verhoog de stroom.',
                  ),
                  const _HintRow(
                    label: 'Δ(ΔT/I²) ≈ 0',
                    description:
                        'geleiders zijn thermisch identiek, ongeacht stroomverschil.',
                  ),
                  const _HintRow(
                    label: 'Δ(ΔT/I²) > 0',
                    description:
                        'meting 1 heeft hogere thermische weerstand op dat punt.',
                  ),
                  const _HintRow(
                    label: 'Δ(ΔT/I²) < 0',
                    description:
                        'meting 2 heeft hogere thermische weerstand op dat punt.',
                  ),
                  const _HintRow(
                    label: 'Alle paren afwijkend',
                    description:
                        'systematisch probleem — verschil in materiaal, doorsnede of isolatie.',
                  ),
                  const _HintRow(
                    label: 'Eén paar afwijkend',
                    description:
                        'lokaal defect — contactweerstand of degradatie bij die specifieke verbinding.',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'K-rangschikking (alle 6 metingen)',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const _HintRow(
                    label: 'K/K_ref ≈ 1',
                    description:
                        'thermische weerstand vergelijkbaar met de gekozen referentiemeting.',
                  ),
                  const _HintRow(
                    label: 'SNR_n ≥ 3',
                    description:
                        'de meting ligt significant hoger dan de referentie en wijst op verhoogde thermische weerstand.',
                  ),
                  const _HintRow(
                    label: 'Negatieve SNR_n',
                    description:
                        'de meting ligt lager dan de referentie; in deze kaart telt dat niet als afwijking naar boven.',
                  ),
                  const _HintRow(
                    label: 'Meerdere hoge K-waarden',
                    description:
                        'systematisch patroon — mogelijk verschil in doorsnede, materiaal of belasting.',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Regressie & stroomnormalisatie',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const _HintRow(
                    label: 'Δm ≤ tolerantie',
                    description:
                        'Reeks A en B hebben vergelijkbaar thermisch verloop.',
                  ),
                  const _HintRow(
                    label: 'Gelijke helling, ander niveau',
                    description:
                        'mogelijke stroomonbalans: vergelijkbaar verloop maar verschoven temperatuurprofiel.',
                  ),
                  const _HintRow(
                    label: 'R² < 0,80',
                    description:
                        'het verloop is minder lineair; een lokale hotspot of verstoring is waarschijnlijker.',
                  ),
                  const _HintRow(
                    label: 'Sterke dalende helling',
                    description:
                        'kan duiden op overgangsweerstand nabij de aansluiting.',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'NPR 8040-1',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const _HintRow(
                    label: 'Binnen grenswaarde',
                    description:
                        'de gemeten temperatuur valt onder de maximale toelaatbare waarde van de gekozen methode.',
                  ),
                  const _HintRow(
                    label: 'Directe actie vereist',
                    description:
                        'de gemeten temperatuur overschrijdt de grenswaarde — onmiddellijke inspectie of vervanging noodzakelijk.',
                  ),
                  const _HintRow(
                    label: 'Methode 3 buiten bereik',
                    description:
                        'methode 3 is niet geldig als T_amb < 5 °C of T_amb > 40 °C. Gebruik methode 1 of 2 als alternatief.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String step;
  final String title;
  final IconData icon;
  final Color color;
  final List<String> paragraphs;

  const _StepCard({
    required this.step,
    required this.title,
    required this.icon,
    required this.color,
    required this.paragraphs,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: 0.14),
                  child: Text(
                    step,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(icon, color: color),
              ],
            ),
            const SizedBox(height: 12),
            ...paragraphs.map(
              (text) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormulaCard extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;

  const _FormulaCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: const Color(0xFFF6F8FC),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.$1,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppTheme.primaryDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      row.$2,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintRow extends StatelessWidget {
  final String label;
  final String description;

  const _HintRow({required this.label, required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 8, color: AppTheme.accent),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style.copyWith(height: 1.4),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
