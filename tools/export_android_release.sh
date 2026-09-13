#!/bin/zsh
set -euo pipefail

export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
if [[ -n "${DOTNET_ROOT:-}" && -x "$DOTNET_ROOT/dotnet" ]]; then
  export DOTNET_ROOT="$DOTNET_ROOT"
elif [[ -x "/opt/homebrew/opt/dotnet/libexec/dotnet" ]]; then
  export DOTNET_ROOT=/opt/homebrew/opt/dotnet/libexec
elif [[ -x "/tmp/dotnet10_root/dotnet" ]]; then
  export DOTNET_ROOT=/tmp/dotnet10_root
elif [[ -x "/private/tmp/dotnet11_root/dotnet" ]]; then
  export DOTNET_ROOT=/private/tmp/dotnet11_root
else
  export DOTNET_ROOT=/opt/homebrew/opt/dotnet@9/libexec
fi
export DOTNET_ROLL_FORWARD="${DOTNET_ROLL_FORWARD:-Major}"
export DOTNET_NOLOGO=1
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
export PATH="$DOTNET_ROOT:$DOTNET_ROOT/sdk:$JAVA_HOME/bin:/opt/homebrew/opt/dotnet@9/bin:/opt/homebrew/bin:/Users/chendong/Library/Android/sdk/platform-tools:$PATH"
export GODOT_ANDROID_EXPORT_MODE=release
PROJECT_DIR="/Volumes/AI/Codex/四川麻将工程_20260701_v2"
APP_VERSION="$(sed -n 's/^config\/version="\([^"]*\)"/\1/p' "$PROJECT_DIR/project.godot" | head -n 1)"
if [[ -z "$APP_VERSION" ]]; then
  echo "Could not read application/config/version from project.godot"
  exit 1
fi
RELEASE_BASENAME="SichuanMahjong-${APP_VERSION}-release"
export GODOT_ANDROID_OUTPUT="$PROJECT_DIR/build/android/${RELEASE_BASENAME}-base.apk"
mkdir -p "$PROJECT_DIR/build/android/signing"
GODOT_BIN="${GODOT_BIN:-}"
BUILD_TOOLS="/Users/chendong/Library/Android/sdk/build-tools/35.0.0"
ANDROID_SOURCE_TEMPLATE="/Users/chendong/Library/Application Support/Godot/export_templates/4.6.2.stable.mono/templates/android_source.zip"
MONO_ANDROID_LIB_SOURCE="$PROJECT_DIR/evidence/1.0.42_to_1.0.44_github_diff/extracted/1.0.42/libgodot_android.so"
MONO_ANDROID_LIB_SHA256="9da745177c364666278250a8912d43869166998a277ab8eebfb9f7322a064b6a"
MONO_ANDROID_APK_SOURCE="$PROJECT_DIR/evidence/1.0.42_to_1.0.44_github_diff/downloads/NeijiangMahjong-1.0.42-release.apk"
MONO_ANDROID_APK_URL="https://github.com/donachen01/neijiang-mahjong/releases/download/v1.0.42/NeijiangMahjong-1.0.42-release.apk"
MONO_ANDROID_APK_SHA256="68493b048df30efad322fa565c56c1e88c976fc3e832fe2d34278697b3641f9a"
GRADLE_BUILD_DIR="${GODOT_ANDROID_GRADLE_BUILD_DIR:-/tmp/sichuan_mahjong_android_gradle_build}"
export GODOT_ANDROID_GRADLE_BUILD_DIR="$GRADLE_BUILD_DIR"
GRADLE_PROJECT_DIR="$GRADLE_BUILD_DIR/build"
ANDROID_SOURCE_HASH="2e4953ced35c490cba7c57d55684ee00"
EXPECTED_BUILD_VERSION="$ANDROID_SOURCE_TEMPLATE [$ANDROID_SOURCE_HASH]"

if [[ -z "$GODOT_BIN" || ! -x "$GODOT_BIN" ]]; then
  for candidate in \
    "/tmp/godot_mono_462/Godot_mono.app/Contents/MacOS/Godot" \
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

SIGNING_INFO="$PROJECT_DIR/build/android/signing/release_keystore_info.txt"
if [[ ! -f "$SIGNING_INFO" ]]; then
  echo "Missing release signing info: $SIGNING_INFO"
  echo "Restore the local ignored signing file before exporting a release APK."
  exit 1
fi
export GODOT_ANDROID_RELEASE_KEYSTORE="$(sed -n 's/^keystore=//p' "$SIGNING_INFO")"
export GODOT_ANDROID_RELEASE_ALIAS="$(sed -n 's/^alias=//p' "$SIGNING_INFO")"
export GODOT_ANDROID_RELEASE_PASSWORD="$(sed -n 's/^store_password=//p' "$SIGNING_INFO")"

if [[ ! -x "$GRADLE_PROJECT_DIR/gradlew" ]] || [[ ! -f "$GRADLE_BUILD_DIR/.build_version" ]] || [[ "$(<"$GRADLE_BUILD_DIR/.build_version")" != "$EXPECTED_BUILD_VERSION" ]]; then
  echo "Preparing Android Gradle build template..."
  rm -rf "$GRADLE_BUILD_DIR"
  mkdir -p "$GRADLE_PROJECT_DIR"
  unzip -q "$ANDROID_SOURCE_TEMPLATE" -d "$GRADLE_PROJECT_DIR"
  printf '%s' "$EXPECTED_BUILD_VERSION" > "$GRADLE_BUILD_DIR/.build_version"
fi

ensure_verified_mono_android_lib() {
  if [[ -f "$MONO_ANDROID_LIB_SOURCE" ]]; then
    local existing_hash
    existing_hash="$(shasum -a 256 "$MONO_ANDROID_LIB_SOURCE" | awk '{print $1}')"
    if [[ "$existing_hash" == "$MONO_ANDROID_LIB_SHA256" ]]; then
      return 0
    fi
    echo "Removing invalid Mono Android lib source with hash: $existing_hash"
    rm -f "$MONO_ANDROID_LIB_SOURCE"
  fi

  mkdir -p "${MONO_ANDROID_APK_SOURCE:h}" "${MONO_ANDROID_LIB_SOURCE:h}"
  if [[ ! -f "$MONO_ANDROID_APK_SOURCE" ]]; then
    echo "Downloading verified v1.0.42 APK to recover Mono Android native library..."
    curl -L --fail --retry 3 --connect-timeout 30 -o "$MONO_ANDROID_APK_SOURCE.tmp" "$MONO_ANDROID_APK_URL"
    mv "$MONO_ANDROID_APK_SOURCE.tmp" "$MONO_ANDROID_APK_SOURCE"
  fi

  local apk_hash
  apk_hash="$(shasum -a 256 "$MONO_ANDROID_APK_SOURCE" | awk '{print $1}')"
  if [[ "$apk_hash" != "$MONO_ANDROID_APK_SHA256" ]]; then
    echo "v1.0.42 APK hash mismatch: $apk_hash"
    echo "Expected: $MONO_ANDROID_APK_SHA256"
    exit 1
  fi

  unzip -p "$MONO_ANDROID_APK_SOURCE" 'lib/arm64-v8a/libgodot_android.so' > "$MONO_ANDROID_LIB_SOURCE"
  local lib_hash
  lib_hash="$(shasum -a 256 "$MONO_ANDROID_LIB_SOURCE" | awk '{print $1}')"
  if [[ "$lib_hash" != "$MONO_ANDROID_LIB_SHA256" ]]; then
    echo "Extracted Mono Android lib hash mismatch: $lib_hash"
    exit 1
  fi
}

echo "Using Godot: $("$GODOT_BIN" --version)"

rm -f "$GODOT_ANDROID_OUTPUT"

"$GODOT_BIN" \
  --headless \
  --rendering-method gl_compatibility \
  --editor \
  --path "$PROJECT_DIR" \
  --script "res://tools/export_android_direct.gd"

FINAL_APK="$PROJECT_DIR/build/android/${RELEASE_BASENAME}-base.apk"
PRUNED_APK="$PROJECT_DIR/build/android/${RELEASE_BASENAME}-pruned.apk"
ALIGNED_APK="$PROJECT_DIR/build/android/${RELEASE_BASENAME}-aligned.apk"
SIGNED_APK="$PROJECT_DIR/build/android/${RELEASE_BASENAME}.apk"

if [[ ! -f "$FINAL_APK" ]]; then
  echo "Android export did not produce $FINAL_APK"
  exit 1
fi

BASE_APK_BYTES="$(stat -f '%z' "$FINAL_APK")"
echo "Base APK bytes: $BASE_APK_BYTES"

cp "$FINAL_APK" "$PRUNED_APK"
zip -q -d "$PRUNED_APK" 'assets/build/*' 'assets/tests/*' 'assets/tools/*' 'assets/artifacts/*' 'assets/evidence/*' 'assets/research/*' 'assets/dotnet/*' 'assets/backups/*' 'assets/source_assets/*' 'assets/planning/*' 'assets/测试数据统计/*' 'assets/设计文档/*' 'assets/.tmp_tts/*' 'assets/.venv_tts/*' 2>/dev/null || true
zip -q -d "$PRUNED_APK" 'assets/docs/*' 2>/dev/null || true
zip -q -d "$PRUNED_APK" 'assets/*/current_ai_*' 'assets/*/hell_training/*' 'assets/*/hell_marked_cases/*' 'assets/*/hell_replay/*' 'assets/*/*seedlive*' 'assets/*/*seed250514*' 2>/dev/null || true
# Godot's all-resources export can retain imported derivatives after their
# source artifact folders are excluded. Remove only known visual-QA derivatives;
# the runtime settlement frame asset is intentionally not matched here.
zip -q -d "$PRUNED_APK" \
  'assets/.godot/imported/*target_rework*' \
  'assets/.godot/imported/*concept_a_*' \
  'assets/.godot/imported/*concept_b_*' \
  'assets/.godot/imported/*concept_c_*' \
  'assets/.godot/imported/*scheme_b_runtime*' \
  'assets/.godot/imported/*nameplates_narrowed_real*' 2>/dev/null || true
CURRENT_GODOT_LIB_SHA256="$(unzip -p "$PRUNED_APK" 'lib/arm64-v8a/libgodot_android.so' | shasum -a 256 | awk '{print $1}')"
if [[ "$CURRENT_GODOT_LIB_SHA256" != "$MONO_ANDROID_LIB_SHA256" ]]; then
  ensure_verified_mono_android_lib
  SOURCE_GODOT_LIB_SHA256="$(shasum -a 256 "$MONO_ANDROID_LIB_SOURCE" | awk '{print $1}')"
  if [[ "$SOURCE_GODOT_LIB_SHA256" != "$MONO_ANDROID_LIB_SHA256" ]]; then
    echo "Mono Android lib source hash mismatch: $SOURCE_GODOT_LIB_SHA256"
    exit 1
  fi
  echo "Replacing non-mono libgodot_android.so with verified mono Android native library."
  PATCH_DIR="$PROJECT_DIR/build/android/${RELEASE_BASENAME}-mono-lib"
  rm -rf "$PATCH_DIR"
  mkdir -p "$PATCH_DIR/lib/arm64-v8a"
  cp "$MONO_ANDROID_LIB_SOURCE" "$PATCH_DIR/lib/arm64-v8a/libgodot_android.so"
  (cd "$PATCH_DIR" && zip -q -0 -u "$PRUNED_APK" 'lib/arm64-v8a/libgodot_android.so')
  rm -rf "$PATCH_DIR"
fi
FINAL_GODOT_LIB_SHA256="$(unzip -p "$PRUNED_APK" 'lib/arm64-v8a/libgodot_android.so' | shasum -a 256 | awk '{print $1}')"
if [[ "$FINAL_GODOT_LIB_SHA256" != "$MONO_ANDROID_LIB_SHA256" ]]; then
  echo "Release APK still does not contain the verified mono Android native library: $FINAL_GODOT_LIB_SHA256"
  exit 1
fi
if ! unzip -p "$PRUNED_APK" 'assets/_cl_' | strings | grep -Fxq -- '--rendering-method' || \
   ! unzip -p "$PRUNED_APK" 'assets/_cl_' | strings | grep -Fxq -- 'gl_compatibility'; then
  echo "Release APK is missing the Android gl_compatibility runtime override."
  exit 1
fi
"$BUILD_TOOLS/zipalign" -f -p 4 "$PRUNED_APK" "$ALIGNED_APK"
"$BUILD_TOOLS/apksigner" sign \
  --ks "$GODOT_ANDROID_RELEASE_KEYSTORE" \
  --ks-key-alias "$GODOT_ANDROID_RELEASE_ALIAS" \
  --ks-pass "pass:$GODOT_ANDROID_RELEASE_PASSWORD" \
  --key-pass "pass:$GODOT_ANDROID_RELEASE_PASSWORD" \
  --out "$SIGNED_APK" \
  "$ALIGNED_APK"
"$BUILD_TOOLS/apksigner" verify "$SIGNED_APK"
SIGNED_APK_BYTES="$(stat -f '%z' "$SIGNED_APK")"
MAX_RELEASE_APK_BYTES="${MAX_RELEASE_APK_BYTES:-314572800}"
echo "Signed APK bytes: $SIGNED_APK_BYTES"
if (( SIGNED_APK_BYTES > MAX_RELEASE_APK_BYTES )); then
  echo "Release APK exceeds the 300 MiB size budget: $SIGNED_APK_BYTES bytes"
  exit 1
fi
echo "Release APK: $SIGNED_APK"
