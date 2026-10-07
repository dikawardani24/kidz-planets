import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:core/layout.dart';
import 'package:core/platform.dart';
import 'package:kidz_planets/application/startup/startup_providers.dart';
import 'package:kidz_planets/presentation/screens/intro/intro_page.dart';

import '../helpers/localized_app.dart';
import 'fake_startup_hooks.dart';

/// Pumps the intro the way an Android TV shows it: landscape with the
/// television override on, so the TV layout and focus paths are exercised
/// without a TV.
Future<void> pumpTvIntro(
  WidgetTester tester,
  FakeStartupHooks hooks, {
  Size surface = const Size(1920, 1080),
  void Function()? onEnter,
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    localizedApp(
      IntroPage(onEnterExplorer: onEnter ?? () {}),
      overrides: [
        startupWith(hooks),
        tvModeOverrideProvider.overrideWith((ref) => true),
      ],
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('the TV intro fits a 1080p landscape screen', (tester) async {
    await pumpTvIntro(tester, FakeStartupHooks());

    // Type derives from the viewport scale (28 × 1080p factor), not a
    // per-device constant. Any RenderFlex overflow fails the test.
    final factor = DesignScale.sharedFactorFor(const Size(1920, 1080));
    final title = tester.widget<Text>(find.text('SPACE ADVENTURE'));
    expect(title.style?.fontSize, closeTo(28 * factor, 0.01));
    expect(find.text('100%'), findsOneWidget);
    expect(find.text("LET'S EXPLORE!"), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the TV intro fits a 720p screen with room to spare', (
    tester,
  ) async {
    await pumpTvIntro(
      tester,
      FakeStartupHooks(),
      surface: const Size(1280, 720),
    );

    expect(find.text('100%'), findsOneWidget);
    expect(find.text("LET'S EXPLORE!"), findsOneWidget);
    // The CTA must be on screen, not below the fold: a D-pad cannot scroll.
    final cta = tester.getRect(find.text("LET'S EXPLORE!"));
    expect(cta.bottom, lessThanOrEqualTo(720));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the TV intro fits a 4K screen without stretching', (
    tester,
  ) async {
    await pumpTvIntro(
      tester,
      FakeStartupHooks(),
      surface: const Size(3840, 2160),
    );

    // Capped scale, fraction-capped column: composed, not huge.
    expect(find.text('100%'), findsOneWidget);
    expect(find.text("LET'S EXPLORE!"), findsOneWidget);
    final cta = tester.getRect(find.text("LET'S EXPLORE!"));
    expect(cta.bottom, lessThanOrEqualTo(2160));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a tablet portrait keeps the single-column composition', (
    tester,
  ) async {
    await pumpTvIntro(
      tester,
      FakeStartupHooks(),
      surface: const Size(800, 1280),
    );

    expect(find.text('100%'), findsOneWidget);
    expect(find.text("LET'S EXPLORE!"), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the remote OK activates the TV completion CTA', (tester) async {
    var entered = false;
    await pumpTvIntro(
      tester,
      FakeStartupHooks(),
      onEnter: () => entered = true,
    );
    expect(find.text("LET'S EXPLORE!"), findsOneWidget);

    // No touch involved: the CTA holds focus and SELECT triggers it, exactly
    // what a TV remote's OK button sends.
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(entered, isFalse); // launch beat first
    await tester.pump(const Duration(milliseconds: 700));
    expect(entered, isTrue);
  });

  testWidgets('OK still enters when no button holds focus', (tester) async {
    var entered = false;
    await pumpTvIntro(
      tester,
      FakeStartupHooks(),
      onEnter: () => entered = true,
    );
    expect(find.text("LET'S EXPLORE!"), findsOneWidget);

    // The broken-TV state: autofocus never landed anywhere. The page-level
    // fallback must still turn OK into an entry.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 700));
    expect(entered, isTrue);
  });

  testWidgets('a startup failure shouts through an error dialog', (
    tester,
  ) async {
    final hooks = FakeStartupHooks()
      ..failing.add(SolarSystemStartupTaskId.solarSystem);
    await pumpTvIntro(tester, hooks);
    await tester.pump();

    // Modal dialog on top of the inline card: impossible to miss, and its
    // retry is the focused control.
    expect(find.text('🔄 TRY AGAIN'), findsNWidgets(2));

    hooks.failing.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text("LET'S EXPLORE!"), findsOneWidget);
  });
}
