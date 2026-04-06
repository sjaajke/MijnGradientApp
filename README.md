# MijnGradientApp — Thermische indicator K

Een Flutter-app voor het analyseren van thermografische FLIR-metingen aan elektrische verbindingen. De app berekent de genormaliseerde thermische weerstand **K = ΔT / I²** en bepaalt statistisch of een afwijking significant is.

---

## Wat doet de app?

### 1. FLIR-afbeeldingen inlezen
- Open een radiometrische FLIR-afbeelding (JPEG met ingebedde thermische data) via de bestandskiezer of drag-and-drop.
- De app leest metadata op: cameramodel, resolutie, opnamedatum, temperatuurbereik, palet en GPS-richting.
- Meetpunten (spots) worden automatisch uitgelezen en toegewezen aan 6 meetingvelden.

### 2. FLIR Editor
- Verplaats, voeg toe of verwijder meetpunten direct op de thermische afbeelding.
- Temperatuurwaarden worden na elke wijziging automatisch bijgewerkt via de Teledyne FLIR Atlas C SDK.
- Wijzigingen worden opgeslagen in het originele FLIR-bestand (radiometrische data blijft intact).

### 3. K-indicator berekenen
Per meting worden ingevuld:
- Stroom **I** (A) en meetfout **δI** (A)
- Temperatuur **T** (°C) en meetfout **δT** (°C)
- Gedeelde omgevingstemperatuur **T_amb** (°C)

De app berekent:

| Grootheid | Formule |
|-----------|---------|
| ΔT | ΔT = T − T_amb |
| K | K = ΔT / I²  [°C/A²] |
| δK | δK = K × √( (δΔT/ΔT)² + (2×δI/I)² ) |

K is de genormaliseerde thermische weerstand — onafhankelijk van de stroomsterkte. Een hogere K duidt op een hogere lokale thermische weerstand, wat kan wijzen op een slechte verbinding of verhoogde contactweerstand.

### 4. Vergelijking via SNR
Metingen worden paarsgewijs vergeleken (1↔2, 3↔4, 5↔6) én kruislings over alle 6 metingen:

| SNR | Betekenis |
|-----|-----------|
| ≥ 3 | Significante afwijking — mogelijke slechte verbinding |
| 1–3 | Onzeker — verschil meetbaar maar valt binnen de onzekerheid |
| < 1 | Niet significant — geen uitspraak mogelijk |

De gecombineerde onzekerheid wordt berekend als δ(ΔK) = √(δK₁² + δK₂²), waarna SNR = |ΔK| / δ(ΔK).

### 5. Sessiehistorie
- Sla meetresultaten op als sessie (naam, datum, notities).
- Bekijk en vergelijk eerdere sessies.
- Laad een opgeslagen sessie terug in het K-scherm.

### 6. Exporteren
- Exporteer alle metingen en berekeningen naar een **Excel-bestand** (.xlsx).
- Deel de export via het systeem-deelvenster.

---

## Technische vereisten

| Onderdeel | Vereiste |
|-----------|----------|
| Flutter | 3.41.4 (stable) |
| Dart SDK | ^3.11.1 |
| FLIR SDK | Teledyne FLIR Atlas C SDK 2.18.0 (macOS arm64) |
| Xcode | Xcode 15 (voor SDK-compilatie) |

De Atlas C SDK is alleen vereist voor het uitlezen van radiometrische pixeldata. Zonder SDK kan de app worden gebruikt met handmatig ingevoerde temperatuurwaarden.

---

## Download

De nieuwste versie is te vinden onder [Releases](../../releases).

| Platform | Bestand |
|----------|---------|
| macOS | `MijnGradientApp-macOS.zip` |
| Windows | `MijnGradientApp-Windows.zip` |
| Android | `app-release.apk` |
| iOS | `MijnGradientApp-iOS-unsigned.zip` (xcarchive) |

---

## Bouwen vanuit broncode

Vereisten: [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel)

```bash
git clone https://github.com/sjaajke/MijnGradientApp.git
cd MijnGradientApp
flutter pub get

# macOS
flutter build macos --release

# Windows
flutter build windows --release

# Android
flutter build apk --release

# iOS (zonder codesigning)
flutter build ios --release --no-codesign
```

Voor volledige FLIR SDK-functionaliteit: compileer de native tool via `tools/flir_extract/build.sh`. Zie het **FLIR Atlas SDK — handleiding** scherm in de app voor instructies.

---

## Licentie

Privégebruik. Zie [Privacy Policy](lib/screens/privacy_screen.dart) in de app.
