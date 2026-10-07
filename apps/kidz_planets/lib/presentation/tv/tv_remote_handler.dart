import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:avatar/controllers.dart';
import 'package:avatar/state.dart';
import 'package:core/platform.dart';
import 'package:kidz_planets/application/state/providers.dart';
import 'package:mission/state.dart';
import 'package:planets/state.dart';

import 'tv_explorer_controller.dart';
import 'tv_providers.dart';

/// Maps Android TV remote buttons to [TvRemoteKey], without depending on any
/// manufacturer's remote.
///
/// Covers the standard set: D-pad arrows, CENTER/OK (which Android reports
/// as `select`, with Enter/Space/gamepad-A as equivalents), BACK (`goBack`,
/// Escape on emulator/desktop) and media play/pause. Anything else is left
/// for the focus system.
TvRemoteKey? tvRemoteKeyFor(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.arrowUp) return TvRemoteKey.up;
  if (key == LogicalKeyboardKey.arrowDown) return TvRemoteKey.down;
  if (key == LogicalKeyboardKey.arrowLeft) return TvRemoteKey.left;
  if (key == LogicalKeyboardKey.arrowRight) return TvRemoteKey.right;
  if (key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.space ||
      key == LogicalKeyboardKey.gameButtonA) {
    return TvRemoteKey.center;
  }
  if (key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.escape) {
    return TvRemoteKey.back;
  }
  if (key == LogicalKeyboardKey.mediaPlayPause ||
      key == LogicalKeyboardKey.mediaPlay ||
      key == LogicalKeyboardKey.mediaPause) {
    return TvRemoteKey.playPause;
  }
  return null;
}

/// The single place raw remote key events enter the app.
///
/// Sits above the explorer chrome (below dialogs, which are separate routes
/// and consume their own keys first). Directional keys that a focused control
/// handles never reach here — key events bubble up from the focused node, so
/// this only sees what the focus system left alone — and [TvInputLayer]
/// priority decides whether the explorer may react to the rest.
///
/// Holding a direction drives smooth velocity-based motion: [handleKeyDown]
/// latches the direction and the per-frame ticker feeds [advance], so a held
/// button is one continuous gesture instead of a stream of camera jumps.
///
/// Focus guarantee: the scene scope is re-seated whenever focus dies
/// entirely (a dismissed overlay taking the focused node with it), so there
/// is never a state with the Explorer visible, nothing focused, and a dead
/// remote. BACK shuttles between the scene scope and the controller cluster
/// once the unwind hierarchy is exhausted, so every control stays reachable
/// without ever dropping the key to the system.
class TvRemoteHandler extends ConsumerStatefulWidget {
  const TvRemoteHandler({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TvRemoteHandler> createState() => _TvRemoteHandlerState();
}

class _TvRemoteHandlerState extends ConsumerState<TvRemoteHandler>
    with SingleTickerProviderStateMixin {
  final FocusNode _scope = FocusNode(debugLabel: 'tvScene');
  Ticker? _ticker;
  Duration? _lastTick;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    FocusManager.instance.addListener(_refocusFromVoid);
    if (kDebugMode) {
      // One line per process, read over `adb logcat`: proves TV detection
      // and handler wiring on hardware where nothing else is observable.
      debugPrint(
        'TvRemoteHandler: television=${ref.read(isTelevisionProvider)}',
      );
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_refocusFromVoid);
    _ticker?.dispose();
    _scope.dispose();
    super.dispose();
  }

  /// Re-seats focus into the scene scope when it dies entirely.
  ///
  /// Dismissing whatever held focus (home cards, detail pill) can orphan the
  /// focus tree; without this the remote goes silent until something happens
  /// to autofocus again. Dialogs and chrome scopes hold their own focus, so
  /// this only ever fires from the void — never steals.
  void _refocusFromVoid() {
    if (!mounted) return;
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null || primary == FocusManager.instance.rootScope) {
      _scope.requestFocus();
    }
  }

  void _onTick(Duration elapsed) {
    final last = _lastTick;
    _lastTick = elapsed;
    if (last == null) return;
    final dt = (elapsed - last).inMicroseconds / 1e6;
    try {
      ref.read(tvExplorerControllerProvider.notifier).advance(dt);
    } catch (_) {}
  }

  bool _focusHolds(FocusNode scope) {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return false;
    if (identical(primary, scope)) return true;
    return primary.ancestors.contains(scope);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    final remoteKey = tvRemoteKeyFor(key);
    if (remoteKey == null) return KeyEventResult.ignored;
    final controller = ref.read(tvExplorerControllerProvider.notifier);
    if (event is KeyUpEvent) {
      controller.handleKeyUp(remoteKey);
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final shell = ref.read(appShellProvider);
    final explorer = ref.read(explorerControllerProvider);
    final celebrationVisible = ref.read(
      missionProgressProvider.select((s) => s.celebrationVisible),
    );
    // The TV home is the root: BACK there stays put instead of leaving the
    // app out from under a child reaching for the remote.
    if (remoteKey == TvRemoteKey.back &&
        shell.tab == AppTab.explore &&
        !explorer.hasSelection &&
        !celebrationVisible &&
        ref.read(tvExplorerControllerProvider).homeVisible) {
      return KeyEventResult.handled;
    }
    final layer = resolveTvInputLayer(
      modalOpen: celebrationVisible,
      missionOpen: shell.tab != AppTab.explore,
      detailOpen: explorer.hasSelection,
      avatarFocused: ref.read(tvAvatarFocusedProvider),
    );

    // BACK on the explore tab shuttles focus before unwinding state: chrome
    // (or the void) re-seats into the scene, and empty hands in the scene
    // offer the controller cluster — play/pause included — instead of dying
    // at the system boundary.
    if (remoteKey == TvRemoteKey.back && layer == TvInputLayer.explorer) {
      final back = _backContext(
        shellTab: shell.tab,
        celebrationVisible: celebrationVisible,
      );
      final focusAction = resolveBackFocus(
        focusInScene: _focusHolds(_scope),
        focusInChrome: _focusHolds(ref.read(tvChromeScopeProvider)),
        canUnwind:
            back.celebrationVisible ||
            explorer.hasSelection ||
            explorer.markedTargetId != null ||
            back.missionsOpen,
      );
      switch (focusAction) {
        case TvBackFocusAction.toScene:
          _scope.requestFocus();
          _log(remoteKey, layer, true, 'focus-to-scene');
          return KeyEventResult.handled;
        case TvBackFocusAction.toChrome:
          ref.read(tvChromeScopeProvider).requestFocus();
          _log(remoteKey, layer, true, 'focus-to-chrome');
          return KeyEventResult.handled;
        case TvBackFocusAction.unwind:
          final outcome = controller.handleBack(back);
          final handled = outcome != TvBackOutcome.unhandled;
          _log(remoteKey, layer, handled, 'unwind-$outcome');
          return handled ? KeyEventResult.handled : KeyEventResult.ignored;
      }
    }

    final back = _backContext(
      shellTab: shell.tab,
      celebrationVisible: celebrationVisible,
    );
    final handled = controller.handleKeyDown(
      remoteKey,
      layer,
      back: back,
      // A held remote button streams KeyRepeatEvents: repeats may keep
      // stepping the cursor, but must never re-fire select/BACK/play-pause
      // (one hold closing detail *and* clearing the mark would punish a
      // child for holding the button a moment too long).
      isRepeat: event is KeyRepeatEvent,
      onInteractAvatar: () => _interactAvatar(),
    );
    _log(remoteKey, layer, handled, null);
    return handled ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  TvBackContext _backContext({
    required AppTab shellTab,
    required bool celebrationVisible,
  }) => TvBackContext(
    celebrationVisible: celebrationVisible,
    missionsOpen: shellTab != AppTab.explore,
    closeCelebration: () =>
        ref.read(appShellProvider.notifier).closeCelebration(),
    exitMissions: () {
      ref.read(appShellProvider.notifier).setTab(AppTab.explore);
      // Coming back to explore with empty hands lands on home, not on an
      // empty scene with no obvious next step.
      if (!ref.read(explorerControllerProvider).hasSelection) {
        ref.read(tvExplorerControllerProvider.notifier).showHome();
      }
    },
  );

  void _log(TvRemoteKey key, TvInputLayer layer, bool handled, String? note) {
    if (!kDebugMode) return;
    debugPrint(
      'TvRemote: $key layer=$layer handled=$handled${note == null ? '' : ' $note'} '
      'focus=${FocusManager.instance.primaryFocus?.debugLabel}',
    );
  }

  /// The TV equivalent of tapping the companion: a disappointed rocket gets
  /// encouragement, otherwise it reacts happily. Same outcomes as touch.
  void _interactAvatar() {
    if (ref.read(appShellProvider).avatarMood == AvatarMood.wrong) {
      ref.read(appShellProvider.notifier).retryMission();
    } else {
      ref.read(avatarControllerProvider.notifier).react(AvatarReaction.happy);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _scope,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: widget.child,
    );
  }
}
