import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'application/state/locale_controller.dart';
import 'l10n/generated/app_localizations.dart';
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

class KidzPlanetsApp extends ConsumerWidget {
  const KidzPlanetsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(localeControllerProvider);
    final controller = ref.read(localeControllerProvider.notifier);
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      locale: controller.resolve(chosen ?? WidgetsBinding.instance.platformDispatcher.locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: kSupportedLocales,
      home: const ExplorerScreen(),
    );
  }
}
