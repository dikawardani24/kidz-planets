import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/layout.dart';
import 'package:core/l10n.dart';
import 'package:kidz_planets/application/state/providers.dart';
import 'package:planets/data.dart';
import 'package:planets/state.dart';

class ToastOverlay extends ConsumerWidget {
  const ToastOverlay({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toasts = ref.watch(
      explorerControllerProvider.select((s) => s.toasts),
    );
    if (toasts.isEmpty) return const SizedBox.shrink();
    final t = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final bodyName = ref.watch(bodyNameResolverProvider);
    // Toast type tracks the viewport scale, sitting clear of the scaled bar.
    final ds = DesignScale.sharedOf(context);
    return Positioned(
      top: ds.px(86),
      left: 0,
      right: 0,
      child: Column(
        children: [
          for (final toast in toasts)
            Container(
              margin: EdgeInsets.only(
                bottom: ds.px(8),
                left: ds.px(40),
                right: ds.px(40),
              ),
              padding: ds.insets(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF14532D).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(ds.radius(999)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: Text(
                _textFor(toast, t, locale, bodyName),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: ds.font(12),
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// A toast carries either controller copy or a catalogue hotspot name, and
  /// the two are resolved through different tables.
  String _textFor(
    ToastMessage toast,
    AppLocalizations t,
    Locale locale,
    BodyNameResolver bodyName,
  ) {
    final message = toast.message;
    if (message != null) return message.resolve(t, locale, bodyName: bodyName);
    return localizedHotspotTitle(toast.hotspot!, locale);
  }
}
