import 'dart:async';

import 'package:flutter/material.dart' as material;
import 'package:flutter_driver/driver_extension.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'src/demo_controller.dart';
import 'src/demo_view.dart';

const _defaultServerUrl = String.fromEnvironment(
  'SERVERPOD_URL',
  defaultValue: 'http://localhost:8080/',
);

void main() {
  enableFlutterDriverExtension(enableTextEntryEmulation: false);
  runApp(const DemoRoot());
}

/// Hosts the [ShadcnApp] and owns the light/dark theme selection.
class DemoRoot extends StatefulWidget {
  const DemoRoot({super.key});

  @override
  State<DemoRoot> createState() => _DemoRootState();
}

class _DemoRootState extends State<DemoRoot> {
  bool _isDark = false;

  void _toggleTheme() => setState(() => _isDark = !_isDark);

  @override
  Widget build(BuildContext context) {
    return ShadcnApp(
      title: 'Offline Sync Demo',
      theme: ThemeData(colorScheme: ColorSchemes.lightZinc, radius: 0.5),
      darkTheme: ThemeData(colorScheme: ColorSchemes.darkZinc, radius: 0.5),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: DemoHome(isDark: _isDark, onToggleTheme: _toggleTheme),
    );
  }
}

/// The main screen: builds the controller and the dashboard scaffold.
class DemoHome extends StatefulWidget {
  const DemoHome({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  State<DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<DemoHome> {
  late final DemoController controller;

  @override
  void initState() {
    super.initState();
    controller = DemoController(serverUrl: _defaultServerUrl);
    unawaited(controller.initialize());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Scaffold(
        headers: [
          AppBar(
            title: const Text('Serverpod Offline Sync Demo'),
            subtitle: const Text(_defaultServerUrl),
            trailing: [
              ThemeToggleButton(
                isDark: widget.isDark,
                onToggle: widget.onToggleTheme,
              ),
              const Gap(8),
              UserAvatarMenu(controller: controller),
            ],
          ),
          const Divider(),
        ],
        child: material.Material(
          color: material.Colors.transparent,
          child: DemoDashboard(controller: controller),
        ),
      ),
    );
  }
}
