// Human-readable release highlights for the About screen (key = pubspec semver).
library;

/// Notes shown when the installed [version] matches a key (e.g. `6.0.1`).
/// Keys use **major.minor.micro** only (same as [PackageInfo.version]); the `+build`
/// suffix in `pubspec.yaml` is not shown in the UI but must increase for Play Store.
/// Update this map whenever you ship a new semver from `scripts/bump_pubspec_version.ps1`.
const Map<String, List<String>> kReleaseNotesByVersion = <String, List<String>>{
  '6.0.0': <String>[
    'Version is shown as major.minor.micro (major → breaking-style changes, minor → features, micro → fixes and small tweaks).',
    'Open About for a short summary of what changed in each listed release.',
    'The in-app navigation guide now walks the bottom bar like a tour: Home (what’s on the dashboard), then Diagnose, Scan, My Fields, and More.',
  ],
};

/// Fallback when we have not added notes for this version yet.
const List<String> kDefaultReleaseNotes = <String>[
  'Thanks for using PINYA-PIC.',
  'Release notes for this exact version are not in the app yet—check with your team or project docs for details.',
];

List<String> releaseNotesForVersion(String version) {
  final String normalized = version.trim();
  if (normalized.isEmpty) {
    return kDefaultReleaseNotes;
  }
  return kReleaseNotesByVersion[normalized] ?? kDefaultReleaseNotes;
}
