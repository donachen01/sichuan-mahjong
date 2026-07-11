# 1.0.47 Android package restore evidence

Date: 2026-05-20

## Conclusion

The BlueStacks package issue was reproduced as an APK content difference, not as a new game-rule decision bug.

The release pruning step introduced in `0f4af74 Release 1.0.45 Android AI async fix` removed `assets/dotnet/*` from the APK. Versions 1.0.45 and 1.0.46 therefore shipped with `assets/dotnet=0`, while 1.0.44 had `assets/dotnet=121`.

Version 1.0.47 removes that pruning line and restores `assets/dotnet` into the release APK.

The Android Gradle build directory was also moved outside the Godot project tree. This avoids `res://build/android/gradle_build` being scanned back into the next export and prevents stale Gradle resources from contaminating later APK builds.

## APK content comparison

Command:

```bash
for apk in \
  build/android/NeijiangMahjong-1.0.44-release.apk \
  build/android/NeijiangMahjong-1.0.45-release.apk \
  build/android/NeijiangMahjong-1.0.46-release.apk \
  build/android/NeijiangMahjong-1.0.47-release.apk
do
  name=$(basename "$apk" -release.apk | sed 's/NeijiangMahjong-//')
  printf '%s\n' "$name"
  LC_ALL=C unzip -l "$apk" | LC_ALL=C awk '
    BEGIN{dotnet=0;mono=0;lib=0;tools=0;tests=0;evidence=0}
    /assets\/dotnet\//{dotnet++}
    /assets\/\.godot\/mono\/publish\/arm64\//{mono++}
    /lib\/arm64-v8a\//{lib++}
    /assets\/tools\//{tools++}
    /assets\/tests\//{tests++}
    /assets\/evidence\//{evidence++}
    END{printf "  assets/dotnet=%d mono_publish_arm64=%d lib_arm64=%d tools=%d tests=%d evidence=%d\n", dotnet, mono, lib, tools, tests, evidence}'
done
```

Observed result:

```text
1.0.44
  assets/dotnet=121 mono_publish_arm64=181 lib_arm64=11 tools=20 tests=34 evidence=0
1.0.45
  assets/dotnet=0 mono_publish_arm64=181 lib_arm64=11 tools=20 tests=34 evidence=0
1.0.46
  assets/dotnet=0 mono_publish_arm64=181 lib_arm64=11 tools=0 tests=0 evidence=0
1.0.47
  assets/dotnet=121 mono_publish_arm64=181 lib_arm64=11 tools=20 tests=34 evidence=0
```

## Critical files present in 1.0.47

Command:

```bash
LC_ALL=C unzip -l build/android/NeijiangMahjong-1.0.47-release.apk | LC_ALL=C rg \
  'assets/dotnet/AI.Core/Engines/NeijiangBaoJiaoActionEngine.cs|assets/dotnet/AI.Core/Entry/NeijiangAiFacade.cs|assets/.godot/mono/publish/arm64/NeijiangMahjong.AI.Core.dll|assets/.godot/mono/publish/arm64/NeijiangMahjong.Godot.dll|lib/arm64-v8a/libmonosgen-2.0.so'
```

Observed result:

```text
  3123368  01-01-1981 01:01   lib/arm64-v8a/libmonosgen-2.0.so
   232448  01-01-1981 01:01   assets/.godot/mono/publish/arm64/NeijiangMahjong.AI.Core.dll
   162304  01-01-1981 01:01   assets/.godot/mono/publish/arm64/NeijiangMahjong.Godot.dll
     9267  01-01-1981 01:01   assets/dotnet/AI.Core/Engines/NeijiangBaoJiaoActionEngine.cs
     2939  01-01-1981 01:01   assets/dotnet/AI.Core/Entry/NeijiangAiFacade.cs
```

## Version and startup scene present in 1.0.47

Command:

```bash
unzip -p build/android/NeijiangMahjong-1.0.47-release.apk assets/project.binary \
  | strings \
  | rg '1\.0\.47|SplashScreen|autoload/NeijiangCSharpRuntime4|NeijiangCSharpRuntime\.cs'
```

Observed result:

```text
1.0.47
res://scenes/boot/SplashScreen.tscn
autoload/NeijiangCSharpRuntime4
*res://scripts/ai/NeijiangCSharpRuntime.cs
```

## Signature verification

Command:

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"
/Users/chendong/Library/Android/sdk/build-tools/35.0.0/apksigner verify --verbose \
  build/android/NeijiangMahjong-1.0.47-release.apk
```

Observed result:

```text
Verifies
Verified using v1 scheme (JAR signing): false
Verified using v2 scheme (APK Signature Scheme v2): true
Verified using v3 scheme (APK Signature Scheme v3): true
Verified using v3.1 scheme (APK Signature Scheme v3.1): false
Verified using v4 scheme (APK Signature Scheme v4): false
Verified for SourceStamp: false
Number of signers: 1
```

## Code change

`tools/export_android_release.sh` no longer deletes `assets/dotnet/*` from the final APK.

Removed line:

```bash
zip -q -d "$PRUNED_APK" 'assets/dotnet/*' 2>/dev/null || true
```

`project.godot` version was updated from `1.0.46` to `1.0.47`.

`tools/export_android_release.sh` now exports `GODOT_ANDROID_GRADLE_BUILD_DIR` to `/tmp/neijiang_mahjong_android_gradle_build` by default and deletes the old base APK before export. If Godot does not produce a fresh base APK, the script exits before pruning/signing.

`tools/export_android_direct.gd` now:

- Uses `GODOT_ANDROID_GRADLE_BUILD_DIR` instead of a project-local Gradle build directory.
- Excludes `evidence/*` from Android exports.
- Deletes the output APK and quits when `export_project` returns a non-OK result.

## Build verification

Commands:

```bash
zsh -n tools/export_android_release.sh
zsh -n tools/export_android_debug.sh
git diff --check
DOTNET_NOLOGO=1 DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1 \
  dotnet build NeijiangMahjong.Godot.csproj --no-restore
zsh tools/export_android_release.sh
```

Observed result:

```text
dotnet build: 0 warnings, 0 errors
Android export: export_result=0, message_count=0
Release APK: build/android/NeijiangMahjong-1.0.47-release.apk
```

## Cleanup

The project-local Android Gradle build cache was removed:

```text
build/android/gradle_build: 476M before cleanup
build/android/gradle_build: removed
```

Only the final 1.0.47 APK was retained from this build. Intermediate `base`, `pruned`, `aligned`, and `.idsig` files were removed after verification.
