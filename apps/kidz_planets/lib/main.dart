import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:avatar/state.dart';
import 'package:core/l10n.dart';
import 'package:core/theme.dart';
import 'package:planets/audio.dart';

import 'dependency_injection/injection.dart';
import 'infrastructure/services/avatar_selection_store.dart';
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
  //
  // The avatar choice hydrates here instead: preferences are ready before the
  // first frame, so the selection provider below starts on the saved avatar
  // with no async gap for the UI to guess through.
  final prefs = await SharedPreferences.getInstance();
  final avatarStore = SharedPreferencesAvatarSelectionStore(prefs);
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
        // The avatar feature defaults to an in-memory selection; the app
        // installs the persisted store, so the child's choice survives
        // restarts while tests stay hermetic.
        avatarSelectionProvider.overrideWith(
          (ref) => AvatarSelectionController(store: avatarStore),
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
      // Explicit remote-OK mapping: several Android TV devices deliver
      // DPAD_CENTER/ENTER in ways that never reach the default shortcut
      // table, which strands every D-pad control. Declared once here so all
      // focusable controls (intro CTA included) activate from the remote.
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
      },
      home: const StartupGate(),
    );
  }
}
