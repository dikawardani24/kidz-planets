import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/l10n.dart';
import 'package:core/theme.dart';
import 'package:planets/audio.dart';

import 'dependency_injection/injection.dart';
import 'presentation/screens/startup_gate.dart';

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

  // The audio session and players are configured by the `core.session` and
  // `core.sounds` startup tasks, after the first intro frame — not here. The
  // gate keeps the Explorer (and its narration/sound reads) out of the tree
  // until those tasks finish, so nothing can reach an unregistered service.
  runApp(
    ProviderScope(
      // The features ship their own providers for these, which is right for a
      // feature that is used on its own. Here they are overridden with the
      // singletons GetIt owns, so narration and ambience stay one voice no
      // matter how many packages ask for them.
      overrides: [
        planetSoundServiceProvider.overrideWith(
          (ref) => locator<PlanetSoundService>(),
        ),
        planetNarrationServiceProvider.overrideWith(
          (ref) => locator<PlanetNarrationService>(),
        ),
      ],
      child: const KidzPlanetsApp(),
    ),
  );
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
      locale: controller.resolve(
        chosen ?? WidgetsBinding.instance.platformDispatcher.locale,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: kSupportedLocales,
      home: const StartupGate(),
    );
  }
}
