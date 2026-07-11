# Version

Current app version: `1.0.59`

`1.0.59` keeps the 1.0.58 realtime AI behavior, cleans old generated evidence and retired regression runners out of the source tree, and refreshes the release/test structure after system-disk cleanup.

## Versioning Workflow

- Every meaningful code, asset, rule, or UI change should be committed to git.
- Android package builds must update `version/name` and `version/code` in the local `export_presets.cfg` before export.
- Installer/APK filenames must include the app version number.
- The repository tracks the source version in `project.godot` (`application/config/version`) and this file.
- `export_presets.cfg` stays ignored because it can contain local export paths and signing configuration.
- Build outputs such as APK/AAB files stay out of git. Put release installers on GitHub Releases when needed.
