import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'explorer_screen.dart';
import 'intro/intro_page.dart';

export 'explorer_screen.dart';
export 'intro/intro_page.dart';

/// The composition root's gate: intro until the universe is ready.
///
/// A plain boolean rather than a route: the Explorer is expensive to build
/// (its scene view constructs the controller the moment it mounts), so it
/// must not exist in the tree at all until startup completes — pushing it as
/// a route would still build it underneath the intro. The boolean keeps
/// exactly one of the two screens alive, and the Explorer is constructed
/// fresh on entry, reusing the already-built scene the startup tasks primed.
class StartupGate extends ConsumerStatefulWidget {
  const StartupGate({super.key, this.explorerBuilder});

  /// Builds the Explorer shown after startup; `null` builds the real one.
  ///
  /// A test seam in the same style as `MissionCompanion.controllerFactory`:
  /// the real Explorer pulls in the 3D scene view, which needs a GPU, while a
  /// gate test only cares *when* the swap happens, not what the Explorer
  /// renders.
  final Widget Function()? explorerBuilder;

  @override
  ConsumerState<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends ConsumerState<StartupGate> {
  /// True once the child tapped the completion CTA after a ready startup.
  ///
  /// Latched (never reset): going back to the intro mid-exploration would
  /// strand the already-built scene behind a loading screen that has nothing
  /// left to load.
  var _entered = false;

  @override
  Widget build(BuildContext context) {
    if (_entered) {
      return widget.explorerBuilder?.call() ?? const ExplorerScreen();
    }
    return IntroPage(onEnterExplorer: () => setState(() => _entered = true));
  }
}
