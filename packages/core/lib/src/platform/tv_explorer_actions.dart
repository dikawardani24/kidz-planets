/// Semantic TV remote actions and input-layer priority.
///
/// Raw Android key codes are translated to [TvExplorerAction] at the edge of
/// the app (see the app's `TvRemoteHandler`); everything downstream reacts to
/// these semantic actions, which is what makes the controller unit-testable
/// without a device, a remote, or a key event.
library;

/// A physical remote button, before mode and layer are applied.
///
/// The app's key handler translates Android key codes into these; the TV
/// controller turns them into [TvExplorerAction]s. In the default navigate
/// mode every D-pad direction is spatial navigation; rotate mode is opt-in
/// via an explicit chrome control.
enum TvRemoteKey { up, down, left, right, center, back, playPause }

/// What the child meant, independent of which remote sent it.
enum TvExplorerAction {
  rotateLeft,
  rotateRight,
  rotateUp,
  rotateDown,

  /// Move the spatial cursor to the nearest interactive target in a direction.
  /// All four D-pad arrows map here in navigate mode (never zoom/rotate).
  navigate,

  select,
  back,
  playPause,
}

/// Which interaction layer owns the remote right now.
///
/// Ordered by priority: only the highest active layer consumes an event, so a
/// D-pad press inside a dialog never also rotates the 3D scene behind it.
enum TvInputLayer {
  /// Celebration dialog or any modal: it owns every key until dismissed.
  modal,

  /// Mission list / mission interaction is the frontmost surface.
  mission,

  /// Planet detail card / detail rails are open.
  detail,

  /// The avatar companion holds focus.
  avatar,

  /// Free exploration of the solar system.
  explorer,

  /// Nothing specific is active: tabs and global navigation.
  global,
}

/// Picks the single layer that may consume the next remote event.
///
/// Exactly one layer is ever returned: the highest-priority active one.
///
/// [detailOpen] means detail *chrome widgets* currently own focus — not merely
/// that a planet is selected. Selection alone must not block spatial D-pad
/// navigation across bodies and Explorer controls.
TvInputLayer resolveTvInputLayer({
  required bool modalOpen,
  required bool missionOpen,
  required bool detailOpen,
  required bool avatarFocused,
}) {
  if (modalOpen) return TvInputLayer.modal;
  if (missionOpen) return TvInputLayer.mission;
  if (detailOpen) return TvInputLayer.detail;
  if (avatarFocused) return TvInputLayer.avatar;
  return TvInputLayer.explorer;
}

/// Whether [action] may reach the explorer when [layer] owns the remote.
///
/// Directional actions and select are exclusive to the owning layer; [back]
/// and [playPause] bubble: back unwinds the topmost layer, play/pause always
/// drives the simulation clock.
bool isActionForLayer(TvExplorerAction action, TvInputLayer layer) {
  if (layer == TvInputLayer.explorer) return true;
  return switch (action) {
    TvExplorerAction.back || TvExplorerAction.playPause => true,
    _ => false,
  };
}

/// What BACK does about *focus* before the unwind hierarchy runs.
///
/// The explorer must never strand focus in a dead node (which reads as
/// "the remote died"): BACK first re-seats focus, and only unwinds state
/// once focus is verifiably inside the scene scope.
enum TvBackFocusAction {
  /// Focus is on chrome (or lost entirely): seat it in the scene scope.
  toScene,

  /// Focus is in the scene scope and nothing is left to unwind: offer the
  /// controller cluster instead of dropping the key to the system.
  toChrome,

  /// Focus is in the scene scope and the unwind hierarchy owns the press.
  unwind,
}

/// Picks the BACK focus move from where focus provably is right now.
///
/// Pure so the priority is unit-testable: chrome (or void) always re-seats
/// to the scene; the scene unwinds while it can and shuttles to the cluster
/// only with empty hands.
TvBackFocusAction resolveBackFocus({
  required bool focusInScene,
  required bool focusInChrome,
  required bool canUnwind,
}) {
  if (focusInChrome || !focusInScene) return TvBackFocusAction.toScene;
  return canUnwind ? TvBackFocusAction.unwind : TvBackFocusAction.toChrome;
}

/// Opt-in camera spin vs the default spatial navigator.
///
/// Default is [browse]: every D-pad direction moves among interactive targets
/// (3D bodies and registered chrome controls). [rotate] is entered only when
/// the child activates the Rotate control — never automatically on selection.
enum TvControlMode {
  /// Spatial navigation among interactive targets; OK activates the target.
  browse,

  /// All four directions rotate the view (or the selected body in detail).
  /// Armed explicitly from chrome; selecting a planet does not enter this.
  rotate,
}

extension TvControlModeX on TvControlMode {
  /// The other mode. Used when the child toggles from the on-screen control.
  TvControlMode get toggled => this == TvControlMode.browse
      ? TvControlMode.rotate
      : TvControlMode.browse;
}
