import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/state/providers.dart';

class ToastOverlay extends ConsumerWidget {
  const ToastOverlay({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toasts = ref.watch(explorerControllerProvider.select((s) => s.toasts));
    if (toasts.isEmpty) return const SizedBox.shrink();
    return Positioned(top: 86, left: 0, right: 0, child: Column(children: [
      for (final t in toasts)
        Container(margin: const EdgeInsets.only(bottom: 8, left: 40, right: 40), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFF14532D).withValues(alpha: 0.95), borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25))),
          child: Text(t.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
    ]));
  }
}
