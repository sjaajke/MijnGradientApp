import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/injection_container.dart';
import '../../domain/usecases/delete_session_usecase.dart';
import '../../domain/usecases/get_sessions_usecase.dart';
import '../../domain/usecases/save_session_usecase.dart';
import '../bloc/session/session_bloc.dart';
import 'info_screen.dart';
import 'session_history_screen.dart';
import 'thermal_indicator_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  static const _titles = ['Historie', 'K = ΔT/I²'];
  static const _icons = [
    Icons.history_rounded,
    Icons.bolt_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => SessionBloc(
            sl<GetSessionsUseCase>(),
            sl<SaveSessionUseCase>(),
            sl<DeleteSessionUseCase>(),
          ),
        ),
      ],
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(_titles[_currentIndex]),
            centerTitle: false,
            actions: [
              IconButton(
                tooltip: 'Uitleg over berekeningen',
                icon: const Icon(Icons.info_outline_rounded),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const InfoScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: [
              SessionHistoryScreen(
                onTabSwitch: (i) => setState(() => _currentIndex = i),
              ),
              const ThermalIndicatorScreen(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) =>
                setState(() => _currentIndex = i),
            destinations: List.generate(
              2,
              (i) => NavigationDestination(
                icon: Icon(_icons[i]),
                label: _titles[i],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
