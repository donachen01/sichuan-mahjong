#!/bin/zsh
set -euo pipefail
setopt NULL_GLOB

PROJECT_DIR="/Volumes/AI/Codex/四川麻将工程_20260701_v2"
APP_VERSION="$(sed -n 's/^config\/version="\([^"]*\)"/\1/p' "$PROJECT_DIR/project.godot" | head -n 1)"
if [[ -z "$APP_VERSION" ]]; then
  echo "Could not read application/config/version from project.godot"
  exit 1
fi

GODOT_BIN="${GODOT_BIN:-}"
if [[ -z "$GODOT_BIN" || ! -x "$GODOT_BIN" ]]; then
  for candidate in \
    "/Applications/Godot.NET.app/Contents/MacOS/Godot" \
    "/Applications/Godot_mono.app/Contents/MacOS/Godot" \
    "/Applications/Godot.app/Contents/MacOS/Godot"; do
    if [[ -x "$candidate" ]] && "$candidate" --version 2>/dev/null | grep -qi "mono"; then
      GODOT_BIN="$candidate"
      break
    fi
  done
fi

if [[ ! -x "$GODOT_BIN" ]]; then
  echo "Godot .NET executable not found. Set GODOT_BIN to a Godot 4.6.2 .NET/Mono editor binary."
  exit 1
fi

if ! "$GODOT_BIN" --version 2>/dev/null | grep -qi "mono"; then
  echo "Refusing to export with non-.NET Godot: $GODOT_BIN"
  exit 1
fi

export DOTNET_ROOT="${DOTNET_ROOT:-/opt/homebrew/opt/dotnet/libexec}"
export DOTNET_ROLL_FORWARD="${DOTNET_ROLL_FORWARD:-Major}"
export DOTNET_NOLOGO=1
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
export PATH="$DOTNET_ROOT:$DOTNET_ROOT/sdk:/opt/homebrew/bin:$PATH"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Users/chendong/Downloads/Xcode.app/Contents/Developer}"

if [[ ! -d "$DEVELOPER_DIR" ]]; then
  echo "Missing Xcode developer directory: $DEVELOPER_DIR"
  exit 1
fi

TEMPLATE_VERSION_DIR="/Users/chendong/Library/Application Support/Godot/export_templates/4.6.2.stable.mono"
DEFAULT_IOS_TEMPLATE="$TEMPLATE_VERSION_DIR/ios.zip"
NESTED_IOS_TEMPLATE="$TEMPLATE_VERSION_DIR/templates/ios.zip"
IOS_TEMPLATE="${GODOT_IOS_TEMPLATE:-$DEFAULT_IOS_TEMPLATE}"

# Some manually extracted .NET template archives retain an extra `templates/`
# directory. Godot's preset exporter only probes the version directory itself,
# so expose the existing archive at the canonical path without duplicating it.
if [[ "$IOS_TEMPLATE" == "$DEFAULT_IOS_TEMPLATE" && ! -e "$IOS_TEMPLATE" && -f "$NESTED_IOS_TEMPLATE" ]]; then
  ln -s "templates/ios.zip" "$IOS_TEMPLATE"
fi
if [[ ! -f "$IOS_TEMPLATE" ]]; then
  echo "Missing iOS export template: $IOS_TEMPLATE"
  exit 1
fi

if ! zipinfo -1 "$IOS_TEMPLATE" >/dev/null 2>&1; then
  echo "Invalid iOS export template: $IOS_TEMPLATE"
  exit 1
fi

IOS_BUILD_ROOT="$PROJECT_DIR/build/ios"
EXPORT_DIR="$IOS_BUILD_ROOT/SichuanMahjong-${APP_VERSION}-ios-xcode"
# Keep generated Xcode/DerivedData files out of the next Godot resource scan.
# Rebuild only the current version target. Older signed apps are retained as a
# rollback boundary instead of being erased whenever a new iOS version exports.
rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"
export GODOT_IOS_OUTPUT="$EXPORT_DIR/SichuanMahjongIOS"

EXPORT_CONFIG="ExportRelease"
if [[ "${GODOT_IOS_DEBUG_EXPORT:-false}" == "1" || "${GODOT_IOS_DEBUG_EXPORT:-false}" == "true" || "${GODOT_IOS_DEBUG_EXPORT:-false}" == "yes" ]]; then
  EXPORT_CONFIG="ExportDebug"
fi

# Godot/.NET NativeAOT can leave stale iOS native libraries even when managed
# assemblies changed. Clear only generated iOS NativeAOT outputs before export.
for runtime_id in ios-arm64 iossimulator-arm64 iossimulator-x64; do
  rm -rf "$PROJECT_DIR/.godot/mono/temp/obj/$EXPORT_CONFIG/$runtime_id/native"
  rm -rf "$PROJECT_DIR/.godot/mono/temp/bin/$EXPORT_CONFIG/$runtime_id/native"
  rm -rf "$PROJECT_DIR/.godot/mono/temp/bin/godot-publish-dotnet/$EXPORT_CONFIG-$runtime_id"
  rm -f "$PROJECT_DIR/.godot/mono/temp/obj/$EXPORT_CONFIG/$runtime_id"/SichuanMahjong.*.Up2Date
done
rm -rf "$PROJECT_DIR/.godot/mono/temp/bin/$EXPORT_CONFIG/SichuanMahjong.Godot_aot.xcframework"

echo "Using Godot: $("$GODOT_BIN" --version)"
echo "Using iOS template: $IOS_TEMPLATE"
echo "Export output: $EXPORT_DIR"
echo "Team ID: ${GODOT_IOS_TEAM_ID:-FCB4ZVWWD8}"
echo "Bundle ID: ${GODOT_IOS_BUNDLE_ID:-com.chendong.sichuanmahjong.iosdev}"

"$GODOT_BIN" \
  --headless \
  --editor \
  --path "$PROJECT_DIR" \
  --script res://tools/export_ios_xcode_direct.gd

if [[ ! -f "$EXPORT_DIR/SichuanMahjongIOS.xcodeproj/project.pbxproj" ]]; then
  echo "iOS export did not produce an Xcode project at $EXPORT_DIR"
  exit 1
fi

AOT_XCFRAMEWORK_SRC="$PROJECT_DIR/.godot/mono/temp/bin/$EXPORT_CONFIG/SichuanMahjong.Godot_aot.xcframework"
AOT_DEVICE_DYLIB="$PROJECT_DIR/.godot/mono/temp/bin/$EXPORT_CONFIG/ios-arm64/native/SichuanMahjong.Godot.dylib"
if [[ ! -f "$AOT_DEVICE_DYLIB" ]]; then
  echo "Godot export did not generate iOS NativeAOT dylib; running dotnet publish for ios-arm64."
  dotnet publish "$PROJECT_DIR/SichuanMahjong.Godot.csproj" \
    -c "$EXPORT_CONFIG" \
    -r ios-arm64 \
    -p:GodotTargetPlatform=ios \
    -p:UseNativeAOTRuntime=true \
    -p:PublishAot=true \
    -p:PublishAotUsingRuntimePack=true
fi
if [[ ! -f "$AOT_DEVICE_DYLIB" ]]; then
  echo "Missing Godot .NET iOS NativeAOT dylib: $AOT_DEVICE_DYLIB"
  exit 1
fi
if [[ ! -d "$AOT_XCFRAMEWORK_SRC" ]]; then
  echo "Creating Godot .NET iOS AOT xcframework from $AOT_DEVICE_DYLIB"
  xcodebuild -create-xcframework \
    -library "$AOT_DEVICE_DYLIB" \
    -output "$AOT_XCFRAMEWORK_SRC"
fi
AOT_XCFRAMEWORK_DST="$EXPORT_DIR/SichuanMahjong.Godot_aot.xcframework"
if [[ ! -d "$AOT_XCFRAMEWORK_SRC" ]]; then
  echo "Missing Godot .NET iOS AOT framework: $AOT_XCFRAMEWORK_SRC"
  exit 1
fi

PBXPROJ="$EXPORT_DIR/SichuanMahjongIOS.xcodeproj/project.pbxproj"
if grep -q "SichuanMahjong.Godot_aot.xcframework" "$PBXPROJ"; then
  echo "Godot export already embedded .NET iOS AOT framework in Xcode project."
  echo "iOS Xcode project: $EXPORT_DIR/SichuanMahjongIOS.xcodeproj"
  exit 0
fi

rsync -a --delete "$AOT_XCFRAMEWORK_SRC/" "$AOT_XCFRAMEWORK_DST/"
AOT_FILE_REF="C0D3A021C0D3A021C0D3A021"
AOT_FRAMEWORK_BUILD="C0D3A022C0D3A022C0D3A022"
AOT_EMBED_BUILD="C0D3A023C0D3A023C0D3A023"
if ! grep -q "$AOT_FILE_REF" "$PBXPROJ"; then
  perl -0pi -e "s/(\\/\\* Begin PBXBuildFile section \\*\\/\\n)/\$1\t\t$AOT_FRAMEWORK_BUILD \\/\\* SichuanMahjong.Godot_aot.xcframework in Frameworks \\*\\/ = {isa = PBXBuildFile; fileRef = $AOT_FILE_REF \\/\\* SichuanMahjong.Godot_aot.xcframework \\*\\/; };\\n\t\t$AOT_EMBED_BUILD \\/\\* SichuanMahjong.Godot_aot.xcframework in Embed Frameworks \\*\\/ = {isa = PBXBuildFile; fileRef = $AOT_FILE_REF \\/\\* SichuanMahjong.Godot_aot.xcframework \\*\\/; settings = {ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, ); }; };\\n/" "$PBXPROJ"
  perl -0pi -e "s/(\\/\\* Begin PBXFileReference section \\*\\/\\n)/\$1\t\t$AOT_FILE_REF \\/\\* SichuanMahjong.Godot_aot.xcframework \\*\\/ = {isa = PBXFileReference; lastKnownFileType = wrapper.xcframework; path = \"SichuanMahjong.Godot_aot.xcframework\"; sourceTree = \"<group>\"; };\\n/" "$PBXPROJ"
  perl -0pi -e "s/(90A13CD024AA68E500E8464F \\/\\* Embed Frameworks \\*\\/ = \\{.*?files = \\(\\n)/\$1\t\t\t\t\t$AOT_EMBED_BUILD \\/\\* SichuanMahjong.Godot_aot.xcframework in Embed Frameworks \\*\\/,\\n/s" "$PBXPROJ"
  perl -0pi -e "s/(D0BCFE3118AEBDA2004A7AAE \\/\\* Frameworks \\*\\/ = \\{.*?files = \\(\\n)/\$1\t\t\t\t$AOT_FRAMEWORK_BUILD \\/\\* SichuanMahjong.Godot_aot.xcframework in Frameworks \\*\\/,\\n/s" "$PBXPROJ"
  perl -0pi -e "s/(D0BCFE3618AEBDA2004A7AAE \\/\\* Frameworks \\*\\/ = \\{.*?children = \\(\\n)/\$1\t\t\t\t$AOT_FILE_REF \\/\\* SichuanMahjong.Godot_aot.xcframework \\*\\/,\\n/s" "$PBXPROJ"
fi
if ! grep -q "SichuanMahjong.Godot_aot.xcframework in Embed Frameworks" "$PBXPROJ"; then
  echo "Could not add Godot .NET AOT framework to Embed Frameworks."
  exit 1
fi

echo "Embedded Godot .NET iOS AOT framework: $AOT_XCFRAMEWORK_SRC -> $AOT_XCFRAMEWORK_DST"
echo "iOS Xcode project: $EXPORT_DIR/SichuanMahjongIOS.xcodeproj"
