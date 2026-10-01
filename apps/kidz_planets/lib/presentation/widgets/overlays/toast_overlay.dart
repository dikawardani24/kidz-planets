import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidz_planets/application/state/explorer_state.dart';
import 'package:kidz_planets/application/state/providers.dart';
import 'package:kidz_planets/l10n/generated/app_localizations.dart';
import 'package:kidz_planets/l10n/resolve_message.dart';
import '../../../l10n/localized_planet.dart';

class ToastOverlay extends ConsumerWidget {
  const ToastOverlay({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toasts = ref.watch(explorerControllerProvider.select((s) => s.toasts));
    if (toasts.isEmpty) return const SizedBox.shrink();
    final t = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    return Positioned(top: 86, left: 0, right: 0, child: Column(children: [
      for (final toast in toasts)
        Container(margin: const EdgeInsets.only(bottom: 8, left: 40, right: 40), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFF14532D).withValues(alpha: 0.95), borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25))),
          child: Text(_textFor(toast, t, locale), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
    ]));
  }

  /// A toast carries either controller copy or a catalogue hotspot name, and
  /// the two are resolved through different tables.
  String _textFor(ToastMessage toast, AppLocalizations t, Locale locale) {
    final message = toast.message;
    if (message != null) return message.resolve(t, locale);
    return localizedHotspotTitle(toast.hotspot!, locale);
  }
}
