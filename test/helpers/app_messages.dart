import 'package:kidz_planets/application/state/app_message.dart';

/// Message fixtures for tests.
///
/// The controller no longer accepts display strings, so tests that assert on
/// timing, identity, or gating rather than on wording reuse these instead of
/// inventing prose per assertion. Wording is covered by the ARB parity tests
/// and the resolver tests, which is where a copy change should actually fail.
abstract final class TestMessages {
  const TestMessages._();

  static const title =
      AppMessage(AppMessageId.celebrationMissionTitle, {'id': 1});
  static const description =
      AppMessage(AppMessageId.celebrationDiscovered, {'planetId': 'earth'});

  /// Any message, for tests that only care that a toast exists.
  static const any = AppMessage(AppMessageId.toastSandboxReady, {});

  /// A message whose content can be told apart, for tests that prove toasts are
  /// tracked individually and so need to tell the survivors of a stack apart.
  static AppMessage named(String title) =>
      AppMessage(AppMessageId.toastMissionComplete, {'title': title});
}
