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

const _lightDemoColorScheme = ColorSchemes.lightNeutral;
const _darkDemoColorScheme = ColorSchemes.darkNeutral;

ThemeData _demoTheme(ColorScheme colorScheme) {
  return ThemeData(colorScheme: colorScheme, radius: 0.5);
}

material.ThemeData _demoMaterialTheme(ColorScheme colorScheme) {
  final base = material.ThemeData(
    brightness: colorScheme.brightness,
    colorSchemeSeed: colorScheme.foreground,
    useMaterial3: true,
  );
  final materialColorScheme = base.colorScheme.copyWith(
    primary: colorScheme.foreground,
    onPrimary: colorScheme.background,
    secondary: colorScheme.secondary,
    onSecondary: colorScheme.secondaryForeground,
    surface: colorScheme.background,
    onSurface: colorScheme.foreground,
    error: colorScheme.destructive,
    onError: material.Colors.white,
    outline: colorScheme.border,
  );
  final textTheme = base.textTheme.apply(
    bodyColor: colorScheme.foreground,
    displayColor: colorScheme.foreground,
  );

  return base.copyWith(
    colorScheme: materialColorScheme,
    scaffoldBackgroundColor: colorScheme.background,
    textTheme: textTheme,
    primaryTextTheme: base.primaryTextTheme.apply(
      bodyColor: colorScheme.foreground,
      displayColor: colorScheme.foreground,
    ),
    iconTheme: base.iconTheme.copyWith(color: colorScheme.foreground),
    textSelectionTheme: material.TextSelectionThemeData(
      cursorColor: colorScheme.foreground,
      selectionColor: colorScheme.foreground.withAlpha(
        colorScheme.brightness == material.Brightness.dark ? 64 : 42,
      ),
      selectionHandleColor: colorScheme.foreground,
    ),
    inputDecorationTheme: material.InputDecorationTheme(
      labelStyle: material.TextStyle(color: colorScheme.mutedForeground),
      floatingLabelStyle: material.TextStyle(color: colorScheme.foreground),
      hintStyle: material.TextStyle(color: colorScheme.mutedForeground),
      enabledBorder: material.OutlineInputBorder(
        borderSide: material.BorderSide(color: colorScheme.input),
      ),
      focusedBorder: material.OutlineInputBorder(
        borderSide: material.BorderSide(color: colorScheme.foreground),
      ),
    ),
  );
}

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
    final colorScheme = _isDark ? _darkDemoColorScheme : _lightDemoColorScheme;
    return ShadcnApp(
      title: 'Offline Sync Demo',
      theme: _demoTheme(_lightDemoColorScheme),
      darkTheme: _demoTheme(_darkDemoColorScheme),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      materialTheme: _demoMaterialTheme(colorScheme),
      debugShowCheckedModeBanner: false,
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
    return Scaffold(
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
    );
  }
}
