import 'dart:developer';
import 'dart:io';

/// Reads version values from source files and updates the version table
/// in README.md so it never drifts out of sync.
///
/// Run: `dart run tool/update_readme_versions.dart`
void main() {
  final projectRoot = Directory.current;

  final gradleFile = File('${projectRoot.path}/android/build.gradle.kts');
  final pubspecFile = File('${projectRoot.path}/pubspec.yaml');
  final readmeFile = File('${projectRoot.path}/README.md');

  if (!gradleFile.existsSync() ||
      !pubspecFile.existsSync() ||
      !readmeFile.existsSync()) {
    stderr.writeln('ERROR: Run this from the project root.');
    exit(1);
  }

  final gradle = gradleFile.readAsStringSync();
  final pubspec = pubspecFile.readAsStringSync();
  final readme = readmeFile.readAsStringSync();

  // --- Extract values ---
  final compileSdk = _extract(gradle, r'compileSdk\s*=\s*(\d+)');
  final minSdk = _extract(gradle, r'minSdk\s*=\s*(\d+)');
  final appfunctionsVersion = _extract(
    gradle,
    r'androidx\.appfunctions:appfunctions:([^")\s]+)',
  );

  // pubspec constraints – e.g. ">=3.3.0" or "^3.12.0"
  final sdkConstraintRaw = _extract(
    pubspec,
    r'^\s+sdk:\s*([^\n]+)',
    multiLine: true,
  );
  final flutterConstraintRaw = _extract(
    pubspec,
    r"^\s+flutter:\s*'?([^'\n]+)",
    multiLine: true,
  );

  final flutterDisplay = _friendlyConstraint(flutterConstraintRaw, 'Flutter');
  final dartDisplay = _friendlyConstraint(sdkConstraintRaw, 'Dart');

  // --- Build the table ---
  final table =
      '''
| | |
| --- | --- |
| Android only | Minimum SDK $minSdk, compile SDK $compileSdk |
| AndroidX `appfunctions` | `$appfunctionsVersion` |
| Flutter | $flutterDisplay with $dartDisplay |
| Latest release | See the pub.dev badge above |'''
          .trim();

  // --- Replace content between markers ---
  const markerStart = '<!-- VERSIONS -->';
  const markerEnd = '<!-- /VERSIONS -->';

  final startIdx = readme.indexOf(markerStart);
  final endIdx = readme.indexOf(markerEnd);

  if (startIdx == -1 || endIdx == -1) {
    stderr.writeln('ERROR: Insert $markerStart and $markerEnd in README.md.');
    exit(1);
  }

  final before = readme.substring(0, startIdx + markerStart.length);
  final after = readme.substring(endIdx);

  final updated = '$before\n$table\n$after';

  readmeFile.writeAsStringSync(updated);
  log('  minSdk=$minSdk, compileSdk=$compileSdk');
  log('  appfunctions=$appfunctionsVersion');
  log('  $flutterDisplay, $dartDisplay');
  log('✓ README.md updated');
}

/// Extracts the first capture group for [pattern] in [text].
String _extract(String text, String pattern, {bool multiLine = false}) {
  return RegExp(pattern, multiLine: multiLine).firstMatch(text)?.group(1) ??
      '?';
}

/// Converts a raw pubspec constraint like `>=3.3.0` or `^3.12.0` into a
/// human-friendly string like `Flutter 3.3+` or `Dart 3.12.0+`.
String _friendlyConstraint(String raw, String label) {
  if (raw == '?' || raw.isEmpty) return '$label ?';

  // `^X.Y.Z`  →  X.Y.Z+
  if (raw.startsWith('^')) {
    return '$label ${raw.substring(1)}+';
  }
  // `>=A.B.C` →  A.B.C+
  if (raw.startsWith('>=')) {
    final ver = raw.substring(2);
    // Remove trailing space / junk
    final clean = ver.replaceAll(RegExp(r"[>='\s]"), '');
    return '$label $clean+';
  }
  return '$label $raw';
}
