import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/screens/explorer_screen.dart';
import 'presentation/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Allow the app to follow the device orientation instead of locking it
  // to portrait. The UI/scene can then adapt to both portrait and landscape.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

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
