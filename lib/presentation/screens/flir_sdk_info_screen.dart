import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/flir_extract_service.dart';

/// Informatiepagina over het gebruik van de FLIR Atlas C SDK en de
/// `flir_extract` CLI-tool die de Flutter-app gebruikt voor radiometrische
/// data-extractie en beeldmanipulatie.
class FlirSdkInfoScreen extends StatelessWidget {
  const FlirSdkInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sdkAvailable = FlirExtractService.isAvailable;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FLIR Atlas SDK — handleiding'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF283593)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.camera_outlined,
                        color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Teledyne FLIR Atlas C SDK',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'De app gebruikt de Teledyne FLIR Atlas C SDK via een native '
                  'commandoregelprogramma (flir_extract) om radiometrische FLIR-afbeeldingen '
                  'te lezen, temperatuurdata per pixel op te halen en meetpunten te beheren.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sdkAvailable
                        ? Colors.green.withValues(alpha: 0.25)
                        : Colors.red.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        sdkAvailable
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        sdkAvailable
                            ? 'flir_extract is beschikbaar'
                            : 'flir_extract niet gevonden — SDK vereist',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Vereisten ────────────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.checklist_rounded,
            color: AppTheme.primary,
            title: 'Vereisten',
            children: [
              _InfoRow(
                label: 'SDK',
                value: 'Teledyne FLIR Atlas C SDK (arm64, macOS, Xcode 15)',
              ),
              _InfoRow(
                label: 'SDK-pad',
                value:
                    '/Users/sjaaj/FLIR SDK Atlas-c-sdk-macosx-xcode15-arm64-2.18.0/',
                mono: true,
              ),
              _InfoRow(
                label: 'Tool-pad',
                value:
                    'tools/flir_extract/flir_extract  (gecompileerd binair)',
                mono: true,
              ),
              _InfoRow(
                label: 'Compiler',
                value: 'clang (Xcode Command Line Tools) — arm64 target',
              ),
              _InfoRow(
                label: 'Licentie',
                value:
                    'De SDK vereist een geldige Teledyne FLIR licentie. '
                    'Zonder licentie kunnen radiometrische bestanden niet worden geopend.',
              ),
            ],
          ),

          // ── Compileren ───────────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.build_outlined,
            color: const Color(0xFF6A1B9A),
            title: 'Tool compileren (build.sh)',
            children: [
              const _Paragraph(
                'Het bestand tools/flir_extract/build.sh compileert de C-broncode '
                'flir_extract.c met de Atlas C SDK. Voer dit eenmalig uit na het '
                'installeren of updaten van de SDK.',
              ),
              _CodeBlock('''#!/bin/bash
SDK_DIR="/Users/sjaaj/FLIR SDK Atlas-c-sdk-macosx-xcode15-arm64-2.18.0"

clang -O2 -arch arm64 \\
  -I"\$SDK_DIR/include" \\
  -L"\$SDK_DIR/lib" \\
  -latlas_c_sdk \\
  -Wl,-rpath,"\$SDK_DIR/lib" \\
  -o tools/flir_extract/flir_extract \\
  tools/flir_extract/flir_extract.c'''),
              const _Paragraph(
                'Na het compileren staat het uitvoerbare bestand op '
                'tools/flir_extract/flir_extract. '
                'De app zoekt het op dit vaste pad en roept het aan via Process.run().',
              ),
            ],
          ),

          // ── Architectuur ────────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.account_tree_outlined,
            color: AppTheme.chartA,
            title: 'Hoe de app de SDK gebruikt',
            children: [
              const _Paragraph(
                'De Flutter-app communiceert NIET direct met de SDK — alle SDK-aanroepen '
                'verlopen via het native CLI-programma flir_extract.',
              ),
              _CodeBlock(
                'Flutter (Dart)  →  Process.run(flir_extract, args)\n'
                '             ←  JSON op stdout\n\n'
                'flir_extract.c  →  ACS_ThermalImage_*()  (Atlas C SDK)\n'
                '               ←  radiometrische pixeldata / metadata',
              ),
              const _Paragraph(
                'De klasse FlirExtractService in lib/core/utils/flir_extract_service.dart '
                'biedt typed Dart-methoden voor elk commando. '
                'De DYLD_LIBRARY_PATH wordt automatisch ingesteld op het SDK lib-pad '
                'zodat de dynamische bibliotheek wordt gevonden.',
              ),
            ],
          ),

          // ── Commando's ──────────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.terminal_rounded,
            color: const Color(0xFF00695C),
            title: 'Commando\'s',
            children: [
              const _SubHeader('info'),
              const _Paragraph(
                  'Laadt een radiometrisch FLIR-bestand en geeft metadata + alle '
                  'meetpunten terug als JSON. Controleert eerst of het bestand '
                  'daadwerkelijk thermische data bevat.'),
              _CodeBlock(
                  'flir_extract info <afbeelding.jpg>\n\n'
                  '→ JSON: ok, width, height, camera, thermalParams,\n'
                  '        gps, compass, colorDistribution, scale, spots[]'),
              const _SubHeader('render'),
              const _Paragraph(
                  'Rendert de thermische afbeelding naar PPM-formaat met optionele '
                  'palette, kleurverdeling en temperatuurschaal.'),
              _CodeBlock(
                  'flir_extract render <in.jpg> <out.ppm> [palette] [colorDist] [scaleMin] [scaleMax]\n\n'
                  '→ JSON: ok, width, height, file'),
              const _SubHeader('set-palette'),
              const _Paragraph('Wijzigt het kleurenpalet en rendert opnieuw.'),
              _CodeBlock(
                  'flir_extract set-palette <in.jpg> <out.ppm> <preset>\n\n'
                  'Presets: iron, rainbow, whitehot, blackhot, arctic, lava,\n'
                  '         rainhc, doublerainbow, hottest, coldest, bw,\n'
                  '         colorwheel, colorwheel6, colorwheel12'),
              const _SubHeader('set-scale'),
              const _Paragraph(
                  'Stelt de temperatuurschaal (min/max °C) in en rendert opnieuw.'),
              _CodeBlock(
                  'flir_extract set-scale <in.jpg> <out.ppm> <min> <max> [palette]'),
              const _SubHeader('set-colordist'),
              const _Paragraph('Wijzigt de kleurverdeling (dynamisch bereik).'),
              _CodeBlock(
                  'flir_extract set-colordist <in.jpg> <out.ppm> <mode> [palette]\n\n'
                  'Modes: linear, histogram, signal, plateau, dde, entropy, ade, fsx, lce'),
              const _SubHeader('add-spot / move-spot / remove-spot'),
              const _Paragraph(
                  'Beheert meetpunten (spots). Elke spot heeft een ID, label, '
                  'positie (x,y) en temperatuurwaarde. '
                  'De wijzigingen worden opgeslagen in het FLIR-bestand (JPEG+radiometrisch).'),
              _CodeBlock(
                  'flir_extract add-spot    <in.jpg> <out.jpg> <x> <y>\n'
                  'flir_extract move-spot   <in.jpg> <out.jpg> <id> <newX> <newY>\n'
                  'flir_extract remove-spot <in.jpg> <out.jpg> <id>'),
              const _SubHeader('add-rect / add-ellipse / add-line'),
              const _Paragraph(
                  'Voegt meetgebieden toe: rechthoek, ellips of lijn. '
                  'Geeft min, max en gemiddelde temperatuur terug voor het gebied.'),
              _CodeBlock(
                  'flir_extract add-rect    <in.jpg> <out.jpg> <x> <y> <w> <h>\n'
                  'flir_extract add-ellipse <in.jpg> <out.jpg> <cx> <cy> <rx> <ry>\n'
                  'flir_extract add-line    <in.jpg> <out.jpg> <x1> <y1> <x2> <y2>'),
              const _SubHeader('add-isotherm'),
              const _Paragraph(
                  'Voegt een isotherm toe: alles boven, onder of tussen twee temperaturen '
                  'wordt gemarkeerd met een kleur.'),
              _CodeBlock(
                  'flir_extract add-isotherm <in.jpg> <out.jpg> <type> <temp1> [temp2]\n\n'
                  'Types: above  (alles boven temp1)\n'
                  '       below  (alles onder temp1)\n'
                  '       interval (tussen temp1 en temp2)'),
              const _SubHeader('set-params'),
              const _Paragraph(
                  'Wijzigt de thermische meetparameters die invloed hebben op de '
                  'berekende temperatuurwaarden (emissiviteit, afstand, '
                  'gereflecteerde temperatuur, luchtvochtigheid).'),
              _CodeBlock(
                  'flir_extract set-params <in.jpg> <out.jpg> \\\n'
                  '  <emissivity> <distance_m> <reflectedT_C> <humidity_0-1>'),
              const _SubHeader('get-temp'),
              const _Paragraph(
                  'Geeft de gecalibreerde temperatuur terug op een specifiek pixel (x,y).'),
              _CodeBlock(
                  'flir_extract get-temp <in.jpg> <x> <y>\n\n'
                  '→ JSON: ok, temperature (°C), x, y'),
            ],
          ),

          // ── Palettes ────────────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.palette_outlined,
            color: AppTheme.chartB,
            title: 'Kleurenpaletten',
            children: [
              const _Paragraph(
                'Het palet bepaalt hoe temperatuurwaarden worden omgezet naar kleuren. '
                'Standaard: iron (koud = blauw/paars → warm = rood/wit).',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: FlirPalette.values
                    .map((p) => _PaletteChip(palette: p))
                    .toList(),
              ),
            ],
          ),

          // ── Kleurverdeling ──────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.gradient_outlined,
            color: AppTheme.chartGradient,
            title: 'Kleurverdeling (Color Distribution)',
            children: [
              const _Paragraph(
                'De kleurverdeling bepaalt hoe het palet over het temperatuurbereik '
                'wordt verdeeld — dit beïnvloedt het contrast en de zichtbaarheid '
                'van kleine temperatuurverschillen.',
              ),
              const SizedBox(height: 8),
              for (final mode in FlirColorDist.values)
                _InfoRow(
                  label: mode.cliName,
                  value: mode.displayName,
                  mono: true,
                ),
            ],
          ),

          // ── Thermische parameters ────────────────────────────────────────────
          _SectionCard(
            icon: Icons.tune_rounded,
            color: AppTheme.statusWarning,
            title: 'Thermische meetparameters',
            children: [
              const _Paragraph(
                'De juiste instelling van deze parameters is kritisch voor '
                'nauwkeurige temperatuurmetingen. Standaardwaarden uit de camera '
                'worden gebruikt als de parameters niet expliciet worden ingesteld.',
              ),
              const SizedBox(height: 4),
              const _InfoRow(
                label: 'Emissiviteit (ε)',
                value:
                    '0,0 – 1,0  |  geleidende metalen ≈ 0,1–0,3, geoxideerd metaal ≈ 0,6–0,9, '
                    'isolatie ≈ 0,9–0,95  |  onjuiste ε geeft systematische temperatuurfout',
              ),
              const _InfoRow(
                label: 'Afstand',
                value:
                    'Afstand van camera tot object in meters. '
                    'Beïnvloedt atmosferische correctie.',
              ),
              const _InfoRow(
                label: 'Gereflecteerde temperatuur',
                value:
                    'Temperatuur van omgevingsobjecten die door het meetobject worden '
                    'gereflecteerd (°C). Gebruik de omgevingstemperatuur als benadering.',
              ),
              const _InfoRow(
                label: 'Relatieve luchtvochtigheid',
                value:
                    '0,0 – 1,0  |  beïnvloedt atmosferische absorptie bij grote afstanden. '
                    'Gebruik 0,50 als standaard.',
              ),
            ],
          ),

          // ── JSON-structuur spots ─────────────────────────────────────────────
          _SectionCard(
            icon: Icons.data_object_rounded,
            color: AppTheme.chartExpected,
            title: 'JSON-uitvoer: spots',
            children: [
              const _Paragraph(
                'Het info-commando geeft een array met alle meetpunten (spots) terug. '
                'De app gebruikt deze data om meetpunten automatisch toe te wijzen '
                'aan de 6 meetingvelden.',
              ),
              _CodeBlock(
                '"spots": [\n'
                '  {\n'
                '    "id": 1,\n'
                '    "label": "Sp1",\n'
                '    "x": 320,\n'
                '    "y": 240,\n'
                '    "temperature": 41.0,\n'
                '    "state": 1\n'
                '  },\n'
                '  ...\n'
                ']\n\n'
                '"state": 1 = geldige meting  |  0 = buiten bereik / ongeldig',
              ),
              const _InfoRow(
                label: 'Automatische toewijzing',
                value:
                    'De eerste 6 spots uit het bestand worden automatisch gekoppeld '
                    'aan Meting 1–6. Dit kan handmatig worden aangepast via de '
                    'FLIR Editor of de dropdowns in het K-scherm.',
              ),
            ],
          ),

          // ── FLIR Editor ──────────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.edit_outlined,
            color: AppTheme.chartHotspot,
            title: 'FLIR Editor (in-app)',
            children: [
              const _Paragraph(
                'Via de knop "Bewerken" in het FLIR-beeldvenster opent de FLIR Editor. '
                'Hiermee kun je spots direct op de thermische afbeelding verplaatsen '
                'door erop te tikken of te slepen.',
              ),
              const _InfoRow(
                label: 'Spot verplaatsen',
                value:
                    'Tik op een spot en sleep hem naar de gewenste positie. '
                    'De temperatuurwaarde wordt automatisch bijgewerkt na het loslaten.',
              ),
              const _InfoRow(
                label: 'Spot toevoegen',
                value:
                    'Tik op een leeg gebied in de afbeelding. '
                    'De SDK leest de temperatuur op dat pixel en voegt een nieuwe spot toe.',
              ),
              const _InfoRow(
                label: 'Spot verwijderen',
                value:
                    'Tik op een spot en kies "Verwijderen" in het pop-upmenu.',
              ),
              const _InfoRow(
                label: 'Opslaan',
                value:
                    'Wijzigingen worden opgeslagen in het originele FLIR-bestand '
                    '(JPEG + ingebedde radiometrische data blijft intact). '
                    'Na opslaan worden de spots in het K-scherm automatisch bijgewerkt.',
              ),
            ],
          ),

          // ── Problemen oplossen ───────────────────────────────────────────────
          _SectionCard(
            icon: Icons.bug_report_outlined,
            color: AppTheme.statusFault,
            title: 'Problemen oplossen',
            children: [
              const _HintRow(
                label: 'SDK-fout bij openen afbeelding',
                description:
                    'Controleer of het bestand een echte FLIR-radiometrische JPEG is. '
                    'Gewone foto\'s of geëxporteerde PNG-bestanden bevatten geen thermische data.',
              ),
              const _HintRow(
                label: 'flir_extract niet gevonden',
                description:
                    'Compileer de tool met build.sh. Controleer of het pad '
                    'tools/flir_extract/flir_extract bestaat en uitvoerbaar is (chmod +x).',
              ),
              const _HintRow(
                label: 'DYLD_LIBRARY_PATH fout',
                description:
                    'De Atlas SDK-bibliotheek (libatlas_c_sdk.dylib) moet gevonden kunnen worden. '
                    'Controleer of het SDK lib-pad correct is in FlirExtractService._sdkLibPath.',
              ),
              const _HintRow(
                label: '"not_thermal" foutmelding',
                description:
                    'ACS_ThermalImage_isThermalImageFromFile() geeft false terug. '
                    'Het bestand bevat geen radiometrische data — mogelijk een gewone JPEG-export.',
              ),
              const _HintRow(
                label: 'Temperatuur veel te hoog of laag',
                description:
                    'Controleer de emissiviteitsinstelling. Een onjuiste ε (bijv. 1,0 voor '
                    'glanzend metaal) leidt tot grote systematische fouten. '
                    'Gebruik set-params om de waarden aan te passen.',
              ),
              const _HintRow(
                label: 'Spots wijzigen worden niet opgeslagen',
                description:
                    'Bij move-spot/add-spot/remove-spot moet het uitvoerpad (out.jpg) '
                    'hetzelfde zijn als het bronbestand om de wijzigingen in-place op te slaan. '
                    'De app doet dit automatisch via de FLIR Editor.',
              ),
            ],
          ),

          // ── SDK-versie ───────────────────────────────────────────────────────
          Card(
            color: const Color(0xFFF0F4FF),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gebruikte SDK-versie',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const _InfoRow(
                      label: 'Naam',
                      value: 'Teledyne FLIR Atlas C SDK',
                      mono: false),
                  const _InfoRow(
                      label: 'Versie', value: '2.18.0', mono: true),
                  const _InfoRow(
                      label: 'Platform',
                      value: 'macOS arm64 (Apple Silicon)',
                      mono: false),
                  const _InfoRow(
                      label: 'Xcode', value: 'Xcode 15', mono: false),
                  const _InfoRow(
                      label: 'Header', value: '<acs/thermal_image.h>', mono: true),
                  const _InfoRow(
                      label: 'Library', value: 'libatlas_c_sdk.dylib', mono: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gedeelde widgets ────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withValues(alpha: 0.14),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  final String text;
  const _Paragraph(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(height: 1.45),
        ),
      );
}

class _SubHeader extends StatelessWidget {
  final String text;
  const _SubHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryDark,
              ),
        ),
      );
}

class _CodeBlock extends StatelessWidget {
  final String code;
  const _CodeBlock(this.code);

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(8),
        ),
        width: double.infinity,
        child: SelectableText(
          code,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11.5,
            color: Color(0xFFCDD6F4),
            height: 1.55,
          ),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const _InfoRow({
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: mono ? 'monospace' : null,
                fontSize: mono ? 12 : 13,
                height: 1.4,
              ),
            ),
          ),
        ],
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 6, color: AppTheme.statusFault),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryDark)),
                const SizedBox(height: 2),
                Text(description,
                    style:
                        theme.textTheme.bodySmall?.copyWith(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteChip extends StatelessWidget {
  final FlirPalette palette;
  const _PaletteChip({required this.palette});

  @override
  Widget build(BuildContext context) => Chip(
        label: Text(
          '${palette.cliName}  —  ${palette.displayName}',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      );
}
