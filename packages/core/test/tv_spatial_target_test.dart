import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:core/platform.dart';

void main() {
  /// Pumps one spatial target into a Stack, recording registry traffic.
  Future<void> pumpTarget(
    WidgetTester tester, {
    required String id,
    required VoidCallback? onSelect,
    FocusNode? focusNode,
    ValueChanged<bool>? onFocusChange,
    Widget? ancestor,
    List<TvSpatialTarget>? registered,
    List<String>? unregistered,
  }) async {
    tester.view.physicalSize =
        const Size(800, 800) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    final widget = TvSpatialTargetWidget(
      id: id,
      onSelect: onSelect,
      onTarget: registered?.add ?? (_) {},
      onUnregister: unregistered?.add ?? (_) {},
      focusNode: focusNode,
      onFocusChange: onFocusChange,
      child: Container(width: 60, height: 40, color: Colors.white24),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                top: 100,
                left: 200,
              child: ancestor == null ? widget : _wrap(widget, ancestor),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('registers once laid out, with real screen-space center', (
    tester,
  ) async {
    final registered = <TvSpatialTarget>[];
    await pumpTarget(
      tester,
      id: 'test:one',
      onSelect: () {},
      registered: registered,
    );
    expect(registered, isNotEmpty);
    final last = registered.last;
    expect(last.id, 'test:one');
    // 200+30, 100+20: the container centre in global space.
    expect(last.center, const Offset(230, 120));
    expect(last.onActivate, isNotNull);
    expect(last.focusNode, isNotNull);
  });

  testWidgets('a disabled control never enters the navigation graph', (
    tester,
  ) async {
    final registered = <TvSpatialTarget>[];
    final unregistered = <String>[];
    await pumpTarget(
      tester,
      id: 'test:disabled',
      onSelect: null,
      registered: registered,
      unregistered: unregistered,
    );
    expect(registered, isEmpty);
    expect(unregistered, isEmpty);
  });

  testWidgets('an IgnorePointer ancestor drops the target from the graph', (
    tester,
  ) async {
    final registered = <TvSpatialTarget>[];
    final unregistered = <String>[];
    await pumpTarget(
      tester,
      id: 'test:ignored',
      onSelect: () {},
      registered: registered,
      unregistered: unregistered,
      ancestor: IgnorePointer(ignoring: true, child: const SizedBox()),
    );
    expect(registered, isEmpty);
    expect(unregistered, isEmpty);
  });

  testWidgets('a fully transparent ancestor drops the target from the graph', (
    tester,
  ) async {
    final registered = <TvSpatialTarget>[];
    await pumpTarget(
      tester,
      id: 'test:opacity',
      onSelect: () {},
      registered: registered,
      ancestor: const Opacity(opacity: 0, child: SizedBox()),
    );
    expect(registered, isEmpty);
  });

  testWidgets('centers track layout movement without a rebuild', (
    tester,
  ) async {
    final registered = <TvSpatialTarget>[];
    var top = 100.0;
    Widget build() => MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned(
              top: top,
              left: 0,
              child: TvSpatialTargetWidget(
                id: 'test:moving',
                onSelect: () {},
                onTarget: registered.add,
                onUnregister: (_) {},
                child: Container(width: 60, height: 40, color: Colors.white24),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(build());
    await tester.pump();
    expect(registered.last.center, const Offset(30, 120));
    // Same target widget, new layout: no rebuild of the target itself, yet the
    // registry must report the new centre on the next frame.
    top = 300;
    await tester.pumpWidget(build());
    await tester.pump();
    await tester.pump();
    expect(registered.last.center, const Offset(30, 320));
  });

  testWidgets('dispose unregisters the last-registered id', (tester) async {
    final registered = <TvSpatialTarget>[];
    final unregistered = <String>[];
    var visible = true;
    Widget build() => MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            if (visible)
              Positioned(
                top: 0,
                left: 0,
                child: TvSpatialTargetWidget(
                  id: 'test:life',
                  onSelect: () {},
                  onTarget: registered.add,
                  onUnregister: unregistered.add,
                  child: Container(
                    width: 60,
                    height: 40,
                    color: Colors.white24,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(build());
    await tester.pump();
    expect(registered, isNotEmpty);
    visible = false;
    await tester.pumpWidget(build());
    await tester.pump();
    expect(unregistered, contains('test:life'));
  });

  testWidgets('an id change unregisters the old id, not the new one', (
    tester,
  ) async {
    final registered = <TvSpatialTarget>[];
    final unregistered = <String>[];
    var id = 'test:before';
    Widget build() => MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: TvSpatialTargetWidget(
                id: id,
                onSelect: () {},
                onTarget: registered.add,
                onUnregister: unregistered.add,
                child: Container(width: 60, height: 40, color: Colors.white24),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(build());
    await tester.pump();
    id = 'test:after';
    await tester.pumpWidget(build());
    await tester.pump();
    expect(unregistered, contains('test:before'));
    expect(unregistered, isNot(contains('test:after')));
    expect(registered.last.id, 'test:after');
  });

  testWidgets('OK activates the control that holds focus', (tester) async {
    var activations = 0;
    final focusNode = FocusNode(debugLabel: 'chain');
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                child: TvSpatialTargetWidget(
                  id: 'test:ok',
                  onSelect: () => activations++,
                  onTarget: (_) {},
                  onUnregister: (_) {},
                  focusNode: focusNode,
                  child: Container(
                    width: 60,
                    height: 40,
                    color: Colors.white24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(activations, 1);
  });

  testWidgets('focus changes are reported to the host', (tester) async {
    final focusEvents = <bool>[];
    final focusNode = FocusNode(debugLabel: 'host');
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                child: TvSpatialTargetWidget(
                  id: 'test:focus-events',
                  onSelect: () {},
                  onTarget: (_) {},
                  onUnregister: (_) {},
                  focusNode: focusNode,
                  onFocusChange: focusEvents.add,
                  child: Container(
                    width: 60,
                    height: 40,
                    color: Colors.white24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    focusNode.requestFocus();
    await tester.pump();
    focusNode.unfocus();
    await tester.pump();
    expect(focusEvents, [true, false]);
  });
}

/// Wraps [child] under [ancestor]'s decoration type (the IgnorePointer /
/// Opacity forms used above), preserving the child.
Widget _wrap(Widget child, Widget ancestor) {
  if (ancestor is IgnorePointer) {
    return IgnorePointer(ignoring: ancestor.ignoring, child: child);
  }
  if (ancestor is Opacity) {
    return Opacity(opacity: ancestor.opacity, child: child);
  }
  return child;
}
