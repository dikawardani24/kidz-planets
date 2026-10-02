// Guards the dependency direction the workspace architecture depends on.
//
// The rule the packages are built around:
//
//   kidz_planets -> {planets, avatar, mission, core}
//   feature -> core
//
// So a feature package importing another feature package, or anything
// importing an app package, is an architecture violation. This is checked in
// CI-style rather than trusted, because a single well-meaning import is how a
// feature boundary quietly disappears.
//
// Run with: melos run check:deps
import 'dart:io';

/// Feature packages and what each one is allowed to import.
const _featurePackages = {'planets', 'avatar', 'mission'};

/// Packages that may be imported by anything in the workspace.
const _sharedPackages = {'core'};

/// The runnable app. It is the composition root, so it may import every
/// feature; nothing may import it.
const _appPackages = {'kidz_planets'};

void main(List<String> args) {
  final root = Directory.current;
  final packages = <String, Directory>{};

  for (final dir in ['apps', 'packages']) {
    final parent = Directory('${root.path}/$dir');
    if (!parent.existsSync()) continue;
    for (final entry in parent.listSync()) {
      if (entry is! Directory) continue;
      final pubspec = File('${entry.path}/pubspec.yaml');
      if (!pubspec.existsSync()) continue;
      final name = RegExp(
        r'^name:\s*(\S+)',
        multiLine: true,
      ).firstMatch(pubspec.readAsStringSync())?.group(1);
      if (name != null) packages[name] = entry;
    }
  }

  final violations = <String>[];

  for (final entry in packages.entries) {
    final owner = entry.key;
    final dir = entry.value;
    final libDir = Directory('${dir.path}/lib');
    if (!libDir.existsSync()) continue;

    for (final file in libDir.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final relative = file.path.substring(root.path.length + 1);
      final source = file.readAsStringSync();

      for (final match in RegExp(
        r'''import\s+['"]package:([a-z_0-9]+)/''',
        multiLine: true,
      ).allMatches(source)) {
        final target = match.group(1)!;
        if (target == owner) continue;
        if (_sharedPackages.contains(target)) continue;
        if (_appPackages.contains(target)) {
          violations.add('$relative imports the app package ($target)');
          continue;
        }
        if (_appPackages.contains(owner)) continue; // it composes everything
        if (_featurePackages.contains(owner) &&
            _featurePackages.contains(target)) {
          violations.add(
            '$relative ($owner) imports feature package $target; '
            'features may only depend on core',
          );
        }
      }
    }
  }

  if (violations.isEmpty) {
    stdout.writeln(
      'check_package_deps: OK - ${packages.length} packages, '
      'no feature-to-feature imports and nothing imports the app.',
    );
    return;
  }

  stderr.writeln('check_package_deps: ${violations.length} violation(s):');
  for (final v in violations) {
    stderr.writeln('  - $v');
  }
  exit(1);
}
