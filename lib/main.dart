import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/screens/explorer_screen.dart';
import 'presentation/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ProviderScope(child: KidzPlanetsApp()));
}

class KidzPlanetsApp extends StatelessWidget {
  const KidzPlanetsApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Space Explorer - Kidz Planets',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const ExplorerScreen(),
    );
  }
}
