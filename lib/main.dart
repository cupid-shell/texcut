import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/snippet_repository.dart';
import 'state/app_state.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await SnippetRepository.open();
  final appState = AppState(repository: repository);
  await appState.load();

  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const TexcutApp(),
    ),
  );
}

class TexcutApp extends StatelessWidget {
  const TexcutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'texcut',
      debugShowCheckedModeBanner: false,
      theme: TexcutTheme.light(),
      darkTheme: TexcutTheme.dark(),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
