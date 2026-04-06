---
name: MijnGradientApp — thermal gradient analyser
description: Flutter app for analysing thermal gradients in electrical conductors using calibrated thermographic data
type: project
---

Full Flutter app built at /Users/sjaaj/Flutter/MijnGradientApp. Flutter 3.41.4, Dart SDK ^3.11.1.

**Why:** Electrical conductor inspection tool — analyses emissivity-corrected thermographic data to detect hotspots and compare conductors.

**How to apply:** The clean-architecture structure is already in place; new features should follow the same domain→data→presentation layering.

Architecture (41 Dart files):
- `lib/core/` — constants, MathUtils (gradient, SG filter, hotspot detection), AppTheme, GetIt DI
- `lib/domain/` — entities (Conductor, Hotspot, AnalysisResult, ComparisonResult, MeasurementSession), repository interface, 7 use cases
- `lib/data/` — SessionModel (JSON), LocalDataSource (SharedPreferences), ConductorModel
- `lib/presentation/` — AnalysisBloc, ComparisonBloc, SessionBloc; 5 screens (Main, Input, Analysis, Comparison, SessionHistory); widgets (TemperatureChart, GradientChart, MetricsPanel, StatusBadge, HotspotInfoCard)

Key dependencies: flutter_bloc ^8.1.6, fl_chart ^0.69.0, file_picker ^8.0.0+1, csv ^6.0.0, shared_preferences ^2.3.2, share_plus ^10.0.0, get_it ^8.0.0

State: 0 analyzer issues, 3 unit tests passing.
