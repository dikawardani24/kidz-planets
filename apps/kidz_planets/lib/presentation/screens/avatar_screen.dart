import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:avatar/state.dart';
import 'package:avatar/scene.dart';
import 'package:avatar/widgets.dart';
import 'package:core/l10n.dart';
import 'package:core/layout.dart';
import 'package:core/platform.dart';
import 'package:core/theme.dart';
import 'package:kidz_planets/application/state/providers.dart';

/// The dedicated avatar selection page: a 3D stage to meet the avatars, a
/// choice between them, and one big button that saves the choice.
///
/// Rendered as a full-screen overlay over the current tab (see
/// [AppShellState.avatarPageVisible]), so opening it never disturbs where the
/// child was: closing returns to the exact same tab. The preview reuses the
/// avatar system's own scene, pose and reactions through [AvatarPreview] —
/// the only thing it deliberately lacks is the Explorer's automatic flight,
/// which stays in the companion widget where it belongs.
class AvatarScreen extends ConsumerStatefulWidget {
  const AvatarScreen({super.key, this.controllerFactory});

  /// Test seam in the same style as `MissionCompanion.controllerFactory`.
  final AvatarSceneController Function()? controllerFactory;

  @override
  ConsumerState<AvatarScreen> createState() => _AvatarScreenState();
}

class _AvatarScreenState extends ConsumerState<AvatarScreen> {
  /// The avatar on stage. Starts on the saved choice; tapping a card changes
  /// only the preview until Select is pressed.
  late AvatarType _previewType;

  /// Guards the save against a double tap while preferences are writing.
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _previewType = ref.read(avatarSelectionProvider);
  }

  Future<void> _selectAndClose() async {
    if (_saving) return;
    setState(() => _saving = true);
    await ref.read(avatarSelectionProvider.notifier).select(_previewType);
    if (!mounted) return;
    ref.read(appShellProvider.notifier).closeAvatarPage();
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(avatarSelectionProvider);
    final preview = _previewType;
    final t = AppLocalizations.of(context);
    final ds = DesignScale.sharedOf(context);
    final isTv = ref.watch(isTelevisionProvider);

    return Container(
      color: AppTheme.space950,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: ds.insets(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _RoundButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: t.avatarBack,
                    autofocus: isTv,
                    onTap: () =>
                        ref.read(appShellProvider.notifier).closeAvatarPage(),
                  ),
                  Expanded(
                    child: Text(
                      t.avatarPageTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: ds.font(18),
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // Balances the back button so the title stays centred.
                  SizedBox(width: ds.px(44)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: ds.insets(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.space800.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(ds.radius(24)),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AvatarPreview(
                    avatarType: preview,
                    controllerFactory: widget.controllerFactory,
                  ),
                ),
              ),
            ),
            SizedBox(height: ds.px(8)),
            Text(
              t.avatarPreviewHint,
              style: TextStyle(
                fontSize: ds.font(11),
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: ds.px(10)),
            Padding(
              padding: ds.insets(horizontal: 16),
              child: Row(
                children: [
                  for (final type in AvatarType.values)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: type == AvatarType.values.first ? ds.px(6) : 0,
                          left: type == AvatarType.values.first ? 0 : ds.px(6),
                        ),
                        child: _AvatarCard(
                          type: type,
                          name: type == AvatarType.rocket
                              ? t.avatarRocketName
                              : t.avatarAstronautName,
                          emoji: type == AvatarType.rocket ? '🚀' : '👨‍🚀',
                          previewed: type == preview,
                          current: type == saved,
                          currentLabel: t.avatarCurrentBadge,
                          onTap: () {
                            if (type != preview) {
                              setState(() => _previewType = type);
                            }
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: ds.px(12)),
            Padding(
              padding: ds.insets(horizontal: 16),
              child: _SelectButton(
                label: t.avatarSelectCta,
                busy: _saving,
                onTap: _selectAndClose,
              ),
            ),
            SizedBox(height: ds.px(12)),
          ],
        ),
      ),
    );
  }
}

/// One avatar choice: its emoji, its name, and two independent signals.
///
/// The amber ring says "this is the one on stage"; the badge says "this is
/// the one Explore is using". They agree most of the time and disagree while
/// the child is trying the other one on, which is exactly when both facts
/// matter.
class _AvatarCard extends StatelessWidget {
  const _AvatarCard({
    required this.type,
    required this.name,
    required this.emoji,
    required this.previewed,
    required this.current,
    required this.currentLabel,
    required this.onTap,
  });

  final AvatarType type;
  final String name;
  final String emoji;
  final bool previewed;
  final bool current;
  final String currentLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ds = DesignScale.sharedOf(context);
    return TvFocusable(
      onSelect: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: ds.insets(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: previewed
                ? AppTheme.accentIndigo.withValues(alpha: 0.35)
                : AppTheme.space800.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(ds.radius(18)),
            border: Border.all(
              color: previewed
                  ? AppTheme.accentAmber
                  : Colors.white.withValues(alpha: 0.12),
              width: previewed ? 2.5 : 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: TextStyle(fontSize: ds.font(30))),
              SizedBox(height: ds.px(4)),
              Text(
                name,
                style: TextStyle(
                  fontSize: ds.font(13),
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: ds.px(4)),
              // The slot is always laid out so the two cards stay the same
              // height whether or not either of them is the current one.
              SizedBox(
                height: ds.px(20),
                child: current
                    ? Container(
                        padding: ds.insets(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentAmber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(ds.radius(999)),
                          border: Border.all(
                            color: AppTheme.accentAmber,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_rounded,
                              size: ds.px(11),
                              color: AppTheme.accentAmber,
                            ),
                            SizedBox(width: ds.px(3)),
                            Text(
                              currentLabel,
                              style: TextStyle(
                                fontSize: ds.font(9),
                                fontWeight: FontWeight.w800,
                                color: AppTheme.accentAmber,
                              ),
                            ),
                          ],
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The one big action: saves the staged choice everywhere and leaves.
///
/// Saving and closing happen in that order from a single tap, so the child
/// never sees a stale companion and never has to confirm twice.
class _SelectButton extends StatelessWidget {
  const _SelectButton({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ds = DesignScale.sharedOf(context);
    return TvFocusable(
      onSelect: busy ? null : onTap,
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: busy ? 0.6 : 1.0,
          child: Container(
            width: double.infinity,
            padding: ds.insets(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ds.radius(999)),
              gradient: const LinearGradient(
                colors: [AppTheme.accentIndigo, Color(0xFF7C3AED)],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x664F46E5),
                  blurRadius: 18,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: busy
                ? SizedBox(
                    width: ds.px(20),
                    height: ds.px(20),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: ds.font(15),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Round glass navigation button matching the top-bar circles.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.autofocus = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final ds = DesignScale.sharedOf(context);
    final extent = ds.px(44);
    return Tooltip(
      message: tooltip,
      child: TvFocusable(
        autofocus: autofocus,
        onSelect: onTap,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: extent,
            height: extent,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.38),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 12),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: ds.px(20), color: Colors.white),
          ),
        ),
      ),
    );
  }
}
