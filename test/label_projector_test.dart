import 'package:flutter/painting.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidz_planets/infrastructure/scene/orbit_camera_rig.dart';
import 'package:kidz_planets/infrastructure/scene/scene_models.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'helpers/scene_stubs.dart';

/// Looks down -Z from [eyeZ] towards the origin.
PerspectiveCamera headOnCamera({
  double eyeZ = 10,
  double fovRadiansY = 0.85,
}) =>
    PerspectiveCamera(
      fovRadiansY: fovRadiansY,
      position: vm.Vector3(0, 0, eyeZ),
      target: vm.Vector3.zero(),
      up: vm.Vector3(0, 1, 0),
    );

void main() {
  group('project', () {
    test('returns nothing for an empty viewport', () {
      final builder = makeSceneBuilder();
      addBody(builder, 'earth');

      expect(
        LabelProjector(builder: builder, planets: [testPlanet()])
            .project(camera: headOnCamera(), viewSize: Size.zero),
        isEmpty,
      );
    });

    test('skips a planet the builder has not built yet', () {
      final builder = makeSceneBuilder();
      // The body is registered but its planet is not in the catalogue list.
      addBody(builder, 'earth');

      final frames = LabelProjector(builder: builder, planets: const [])
          .project(camera: headOnCamera(), viewSize: const Size(400, 800));

      expect(frames, isEmpty);
    });

    test('skips a planet that is missing from the render states', () {
      final builder = makeSceneBuilder();
      // A planet with no PlanetRenderState never made it into the scene.
      final frames = LabelProjector(
        builder: builder,
        planets: [testPlanet()],
      ).project(camera: headOnCamera(), viewSize: const Size(400, 800));

      expect(frames, isEmpty);
    });

    test('skips a planet that is behind the camera', () {
      final builder = makeSceneBuilder();
      // Past the eye, so the projection has no screen position.
      addBody(builder, 'earth', position: vm.Vector3(0, 0, 20));
      addBody(builder, 'mars', position: vm.Vector3.zero());

      final frames = LabelProjector(
        builder: builder,
        planets: [testPlanet(id: 'earth'), testPlanet(id: 'mars', name: 'Mars')],
      ).project(camera: headOnCamera(), viewSize: const Size(400, 800));

      expect(frames.map((f) => f.id), ['mars']);
    });

    test('emits one frame per projected planet', () {
      final builder = makeSceneBuilder();
      addBody(builder, 'earth', position: vm.Vector3.zero());
      addBody(builder, 'mars', position: vm.Vector3(0, 0, -5));

      final frames = LabelProjector(
        builder: builder,
        planets: [testPlanet(id: 'earth'), testPlanet(id: 'mars', name: 'Mars')],
      ).project(camera: headOnCamera(), viewSize: const Size(400, 800));

      expect(frames, hasLength(2));
    });

    test('sorts far planets first so near labels paint on top', () {
      final builder = makeSceneBuilder();
      addBody(builder, 'earth', position: vm.Vector3.zero());
      addBody(builder, 'far', position: vm.Vector3(0, 0, -20));

      final frames = LabelProjector(
        builder: builder,
        planets: [
          testPlanet(id: 'earth'),
          testPlanet(id: 'far', name: 'Far'),
        ],
      ).project(camera: headOnCamera(), viewSize: const Size(400, 800));

      expect(frames.map((f) => f.id), ['far', 'earth']);
    });

    test('depth is the squared distance to the camera eye', () {
      final builder = makeSceneBuilder();
      addBody(builder, 'earth', position: vm.Vector3(0, 0, -10));

      final frames = LabelProjector(builder: builder, planets: [testPlanet()])
          .project(camera: headOnCamera(), viewSize: const Size(400, 800));

      expect(frames.single.worldDepth, closeTo(400, 1e-6));
    });

    test('keeps the horizontal screen position of the globe', () {
      final builder = makeSceneBuilder();
      addBody(builder, 'earth', position: vm.Vector3.zero());

      final frames = LabelProjector(builder: builder, planets: [testPlanet()])
          .project(camera: headOnCamera(), viewSize: const Size(400, 800));

      expect(frames.single.screenX, closeTo(200, 1e-6));
    });
  });

  group('label lift', () {
    PlanetLabelFrame projectOne({
      required double radius,
      Size viewSize = const Size(400, 800),
    }) {
      final builder = makeSceneBuilder();
      addBody(builder, 'earth', position: vm.Vector3.zero(), radius: radius);
      final camera = headOnCamera();
      final frames = LabelProjector(
        builder: builder,
        planets: [testPlanet(radius: radius)],
      ).project(camera: camera, viewSize: viewSize);
      return frames.single;
    }

    double rawScreenY({required double radius}) {
      final builder = makeSceneBuilder();
      addBody(builder, 'earth', position: vm.Vector3.zero(), radius: radius);
      return headOnCamera()
          .worldToScreen(vm.Vector3.zero(), const Size(400, 800))!
          .dy;
    }

    test('floats a mid-size label a fixed amount above the globe', () {
      final radius = 1.0;
      final frame = projectOne(radius: radius);

      // 34 + 1 * 10 = 44 logical pixels.
      expect(frame.screenY, closeTo(rawScreenY(radius: radius) - 44, 1e-6));
    });

    test('applies a minimum lift to very small moons', () {
      final radius = 0.1;
      final frame = projectOne(radius: radius);

      // 34 + 1 = 35, which is below the 40px floor.
      expect(frame.screenY, closeTo(rawScreenY(radius: radius) - 40, 1e-6));
    });

    test('caps the lift on large planets so the chip stays on screen', () {
      final radius = 4.0;
      final frame = projectOne(radius: radius);

      // 34 + 40 = 74, capped at 72.
      expect(frame.screenY, closeTo(rawScreenY(radius: radius) - 72, 1e-6));
    });

    test('the lift does not shrink with distance', () {
      final near = projectOne(radius: 1.0);
      final far = _projectAtDistance(40, radius: 1.0);

      expect(near.screenY - rawScreenY(radius: 1.0),
          closeTo(far.screenY - rawScreenY(radius: 1.0), 1e-6));
    });
  });

  group('visibility', () {
    test('a centred planet is visible', () {
      final builder = makeSceneBuilder();
      addBody(builder, 'earth', position: vm.Vector3.zero());

      final frames = LabelProjector(builder: builder, planets: [testPlanet()])
          .project(camera: headOnCamera(), viewSize: const Size(400, 800));

      expect(frames.single.visible, isTrue);
    });

    test('a planet projected far off screen is marked hidden', () {
      final builder = makeSceneBuilder();
      // A narrow lens throws this body well past the right-hand margin.
      addBody(builder, 'earth', position: vm.Vector3(50, 0, 0));

      final frames = LabelProjector(builder: builder, planets: [testPlanet()])
          .project(
            camera: headOnCamera(fovRadiansY: 0.2),
            viewSize: const Size(100, 100),
          );

      expect(frames.single.visible, isFalse);
    });

    test('a planet just inside the margin stays visible', () {
      final builder = makeSceneBuilder();
      addBody(builder, 'earth', position: vm.Vector3.zero());

      final frames = LabelProjector(builder: builder, planets: [testPlanet()])
          .project(camera: headOnCamera(), viewSize: const Size(400, 800));

      // Dead centre of a 400x800 view, well within the 80/60px margins.
      expect(frames.single.screenX, inInclusiveRange(0, 400));
      expect(frames.single.visible, isTrue);
    });
  });
}

PlanetLabelFrame _projectAtDistance(double z, {required double radius}) {
  final builder = makeSceneBuilder();
  addBody(builder, 'earth', position: vm.Vector3(0, 0, -z), radius: radius);
  return LabelProjector(builder: builder, planets: [testPlanet(radius: radius)])
      .project(camera: headOnCamera(eyeZ: 10), viewSize: const Size(400, 800))
      .single;
}
