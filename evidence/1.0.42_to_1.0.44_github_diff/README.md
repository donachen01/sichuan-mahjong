# 1.0.42 to 1.0.44 GitHub comparison

Date: 2026-05-20

## Current conclusion

The new report from the BlueStacks test changes the direction: if 1.0.44 also has the AI-not-playing problem, then the `assets/dotnet` deletion found in 1.0.45/1.0.46 is not the first root cause.

I pulled GitHub release metadata and compared the GitHub tag commits for 1.0.42 and 1.0.44. The code changes between these two releases do **not** touch the runtime AI discard path, C# bridge/runtime, rule engines, game scene logic, or Android export scripts.

Therefore, if the GitHub 1.0.42 APK plays correctly and the GitHub 1.0.44 APK does not, the next primary suspect is an APK/build-artifact difference, not the source-code diff between `v1.0.42` and `v1.0.44`.

## GitHub release identity

GitHub remote tag objects:

```text
v1.0.42 -> acf1a506f257d881f2f7cc9b02d86b95e0567bf5
v1.0.43 -> 80c8e9b60234c2092c56b00776d4df77464f939f
v1.0.44 -> 0f33f38b6d20a895873494c2c41ddc24b1318336
```

Local note: the local `v1.0.44` tag object differs because it is an annotated tag object, but it points at the same release commit shown by GitHub. The source comparison uses the GitHub commit `0f33f38`.

## GitHub release APK metadata

From GitHub release metadata:

```text
NeijiangMahjong-1.0.42-release.apk
size: 118855436
sha256: 68493b048df30efad322fa565c56c1e88c976fc3e832fe2d34278697b3641f9a
asset id: 424833796

NeijiangMahjong-1.0.43-release.apk
size: 118863853
sha256: 71b3fcb8d8cb4b531803b0cf980dcf869c437f8d3abfe6fd33acc1e648c7d7fd
asset id: 424857366

NeijiangMahjong-1.0.44-release.apk
size: 118655160
sha256: 16ca522f51b86ab828bc977e84fd7ef86a6940ac04a44a229b80eb4772753f8b
asset id: 424905848
```

Local 1.0.44 APK hash was verified against GitHub release metadata:

```text
16ca522f51b86ab828bc977e84fd7ef86a6940ac04a44a229b80eb4772753f8b  build/android/NeijiangMahjong-1.0.44-release.apk
```

## Source-code diff summary

Commits between 1.0.42 and GitHub 1.0.44:

```text
408b905 Release 1.0.43 bao jiao fourth tile evidence
80c8e9b Add evidence runner uid
0f33f38 Show app version on splash screen
```

Runtime-sensitive changed paths:

```text
M project.godot
M scenes/boot/SplashScreen.tscn
M scripts/boot/SplashScreen.gd
A tests/current/NeijiangBaoJiaoFourthTileEvidenceRunner.gd
A tests/current/NeijiangBaoJiaoFourthTileEvidenceRunner.gd.uid
M tests/current/NeijiangCurrentSmokeRunner.gd
A tests/current/SplashScreenRegressionRunner.gd
A tests/current/SplashScreenRegressionRunner.gd.uid
```

No files changed under these runtime-sensitive areas:

```text
scripts/ai
scripts/game
scripts/core
dotnet
tools/export_android_direct.gd
tools/export_android_release.sh
export_presets.cfg
```

## Critical file identity check

The following critical files have identical blob ids and content hashes in `acf1a50` and `0f33f38`:

```text
tools/export_android_direct.gd
tools/export_android_release.sh
scripts/ai/AIManager.gd
scripts/ai/NeijiangCSharpRuntime.cs
scripts/game/MainSceneV2.gd
dotnet/AI.Core/Entry/NeijiangAiFacade.cs
dotnet/AI.Core/Engines/NeijiangBaoJiaoActionEngine.cs
```

Full hash evidence is in:

```text
evidence/1.0.42_to_1.0.44_github_diff/reports/runtime_sensitive_hashes.txt
```

## APK comparison status

The official GitHub 1.0.42 APK download is still in progress and is slow. The file must not be used for APK content diff until both checks pass:

```text
expected size:   118855436 bytes
expected sha256: 68493b048df30efad322fa565c56c1e88c976fc3e832fe2d34278697b3641f9a
```

Current partial file path:

```text
evidence/1.0.42_to_1.0.44_github_diff/downloads/NeijiangMahjong-1.0.42-release.apk
```

Once the full file is available, the next checks are:

```bash
/usr/bin/wc -c evidence/1.0.42_to_1.0.44_github_diff/downloads/NeijiangMahjong-1.0.42-release.apk
/usr/bin/shasum -a 256 evidence/1.0.42_to_1.0.44_github_diff/downloads/NeijiangMahjong-1.0.42-release.apk

for apk in \
  evidence/1.0.42_to_1.0.44_github_diff/downloads/NeijiangMahjong-1.0.42-release.apk \
  build/android/NeijiangMahjong-1.0.44-release.apk
do
  name=$(basename "$apk")
  printf '%s\n' "$name"
  LC_ALL=C unzip -l "$apk" | LC_ALL=C awk '
    BEGIN{dotnet=0;mono=0;lib=0;tools=0;tests=0}
    /assets\/dotnet\//{dotnet++}
    /assets\/\.godot\/mono\/publish\/arm64\//{mono++}
    /lib\/arm64-v8a\//{lib++}
    /assets\/tools\//{tools++}
    /assets\/tests\//{tests++}
    END{printf "  assets/dotnet=%d mono_publish_arm64=%d lib_arm64=%d tools=%d tests=%d\n", dotnet, mono, lib, tools, tests}'
done
```

## Failed rebuild note

I attempted to rebuild 1.0.42 from `acf1a50` in a temporary worktree, but that old release script cannot rebuild cleanly in the current environment without later export-template preparation fixes. It failed with:

```text
export_result=3
message_count=1
尝试从自定义构建模板构建，但是它所使用的版本信息不存在。请从“项目”菜单中重新安装。
```

Because of that, the authoritative APK comparison should use the original GitHub release APK for 1.0.42, not a locally rebuilt substitute.

## Evidence files

```text
reports/release_metadata.json.txt
reports/tags.txt
reports/code_diff.txt
reports/full_diff_stat.txt
reports/runtime_sensitive_name_status.txt
reports/runtime_sensitive_hashes.txt
reports/apk_hashes.txt
```

## Final APK root cause found

After the official GitHub 1.0.42 APK finished downloading, it was verified against GitHub release metadata:

```text
size:   118855436
sha256: 68493b048df30efad322fa565c56c1e88c976fc3e832fe2d34278697b3641f9a
```

The APK content comparison found:

```text
1.0.42: assets/dotnet=121 mono_publish_arm64=181 lib_arm64=11 tools=20 tests=30 docs=0 project_binary=1 manifest=1 dex=1
1.0.44: assets/dotnet=121 mono_publish_arm64=181 lib_arm64=11 tools=20 tests=34 docs=0 project_binary=1 manifest=1 dex=1
1.0.47: assets/dotnet=121 mono_publish_arm64=181 lib_arm64=11 tools=20 tests=34 docs=0 project_binary=1 manifest=1 dex=1
```

1.0.44 only adds four test runner files compared with 1.0.42:

```text
assets/tests/current/NeijiangBaoJiaoFourthTileEvidenceRunner.gd.remap
assets/tests/current/NeijiangBaoJiaoFourthTileEvidenceRunner.gdc
assets/tests/current/SplashScreenRegressionRunner.gd.remap
assets/tests/current/SplashScreenRegressionRunner.gdc
```

The critical package difference is the Android native engine library:

```text
1.0.42 lib/arm64-v8a/libgodot_android.so
sha256: 9da745177c364666278250a8912d43869166998a277ab8eebfb9f7322a064b6a
strings include: 4.6.2.stable.mono.official, initialize_coreclr_and_godot_plugins, modules/mono

1.0.44 lib/arm64-v8a/libgodot_android.so
sha256: 3871a52c9435ffbe8881f93a0c9693f32b7fad11ff771971fa7140c37e38d4a6
strings include: 4.6.2.stable.official
strings do not include: 4.6.2.stable.mono.official, initialize_coreclr_and_godot_plugins, modules/mono

1.0.47 lib/arm64-v8a/libgodot_android.so
sha256: 3871a52c9435ffbe8881f93a0c9693f32b7fad11ff771971fa7140c37e38d4a6
same non-mono native library as 1.0.44
```

The local export template path that was supposed to be Mono is also non-Mono:

```text
/Users/chendong/Library/Application Support/Godot/export_templates/4.6.2.stable.mono/templates/android_release.apk
lib/arm64-v8a/libgodot_android.so sha256: 3871a52c9435ffbe8881f93a0c9693f32b7fad11ff771971fa7140c37e38d4a6
strings include: 4.6.2.stable.official
```

Conclusion: the Android release template installed in the local Mono template directory contains a non-Mono `libgodot_android.so`. Debug/editor mode can run C# because the editor is Mono, but release APKs built from that bad template cannot initialize the C# runtime on Android, so AI decisions do not return and AI appears to stop playing.

## 1.0.48 package fix

Version 1.0.48 updates the release packaging script to enforce a verified Mono Android native library before signing. The script uses the verified Mono `libgodot_android.so` extracted from the official GitHub 1.0.42 APK:

```text
sha256: 9da745177c364666278250a8912d43869166998a277ab8eebfb9f7322a064b6a
```

1.0.48 verification:

```text
build/android/NeijiangMahjong-1.0.48-release.apk
size: 118885090
sha256: c746f6d7ad8434bb30eced28cfa16242c4230c44a2cbf64cdd65daca7ad529f4

lib/arm64-v8a/libgodot_android.so
sha256: 9da745177c364666278250a8912d43869166998a277ab8eebfb9f7322a064b6a
zip method: Stored
strings include: initialize_coreclr_and_godot_plugins, modules/mono, Godot Engine v4.6.2.stable.mono.official

APK signature: v2=true, v3=true
C# contract regression: NEIJIANG CSHARP CONTRACT OK
```

The `Stored` zip method is intentional. The official 1.0.42 APK stores `lib/arm64-v8a/libgodot_android.so` uncompressed, and Android native libraries must remain loadable after signing and zipalign. A first local 1.0.48 rebuild compressed the replacement `.so`; that intermediate APK was discarded and rebuilt with `zip -0` before this report was finalized.

The release script does not commit the 113 MB v1.0.42 APK or extracted APK contents to git. If the verified Mono `.so` is missing locally, the script downloads the official v1.0.42 release APK, verifies sha256 `68493b048df30efad322fa565c56c1e88c976fc3e832fe2d34278697b3641f9a`, extracts `lib/arm64-v8a/libgodot_android.so`, verifies sha256 `9da745177c364666278250a8912d43869166998a277ab8eebfb9f7322a064b6a`, and only then patches the new APK.

## 1.0.48 regression evidence

Fresh verification on 2026-05-20:

```text
dotnet build NeijiangMahjong.Godot.csproj --no-restore
result: 0 warnings, 0 errors

/Applications/Godot.NET.app/Contents/MacOS/Godot --headless --path . --script res://tests/current/NeijiangCurrentSmokeRunner.gd
result: NEIJIANG CURRENT SMOKE OK

/Applications/Godot.NET.app/Contents/MacOS/Godot --headless --path . --script res://tests/current/NeijiangCSharpContractRunner.gd
result: NEIJIANG CSHARP CONTRACT OK

/Applications/Godot.NET.app/Contents/MacOS/Godot --headless --path . --script res://tests/current/NeijiangBaoJiaoFourthTileEvidenceRunner.gd
result: wrote 测试数据统计/回归证据_20260520_未报杠摸第四张/case_replay_results.json
```

The fourth-tile replay evidence contains the required two cases:

```text
真实规则复盘：未报 9筒杠，摸第 4 张 9筒
input: hand contains 9筒 ids 601/602/603 and last_draw_tile 9筒 id 604
backend paths: csharp_native_async passed=true, csharp_native_sync_delivery passed=true
result: no gang options, self_action_decision empty, action=discard, discarded_tile id=604

同类型回归：未报 7条杠，摸第 4 张 7条
input: hand contains 7条 ids 701/702/703 and last_draw_tile 7条 id 704
backend paths: csharp_native_async passed=true, csharp_native_sync_delivery passed=true
result: no gang options, self_action_decision empty, action=discard, discarded_tile id=704
```
