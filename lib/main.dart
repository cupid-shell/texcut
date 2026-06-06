import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/expansion_settings.dart';
import 'services/drive_sync.dart';
import 'services/snippet_repository.dart';
import 'state/app_state.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await SnippetRepository.open();
  final appState = AppState(repository: repository);
  await appState.load();

  final driveSync = DriveSync(appState);
  // Fire-and-forget: attempts a silent sign-in + pull if previously connected.
  unawaited(driveSync.init());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: driveSync),
      ],
      child: const TexcutApp(),
    ),
  );
}

class TexcutApp extends StatelessWidget {
  const TexcutApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.select<AppState, ExpansionSettings>(
      (s) => s.settings,
    );
    final seed = Color(settings.accentColor);
    return MaterialApp(
      title: 'texcut',
      debugShowCheckedModeBanner: false,
      theme: TexcutTheme.light(seed: seed),
      darkTheme: TexcutTheme.dark(seed: seed),
      themeMode: switch (settings.themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      home: const SplashScreen(),
    );
  }
}
