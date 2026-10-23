#!/usr/bin/env bash
# Build the sl4ppy/plezy pre-roll fork as a signed arm64 release APK.
# See FORK.md for the toolchain, signing key and install steps.
set -euo pipefail

FLUTTER_HOME="${FLUTTER_HOME:-$HOME/sdk/flutter}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
# A full JDK (javac) is required; a distro JRE fails with "does not provide JAVA_COMPILER".
export JAVA_HOME="${JAVA_HOME:-$(ls -d "$HOME"/sdk/jdk-21* 2>/dev/null | tail -1)}"
export PATH="$FLUTTER_HOME/bin:$PATH"

cd "$(dirname "$0")/.."

if [[ ! -e android/key.properties ]]; then
  echo "android/key.properties missing - link it to the fork keystore config (FORK.md, 'Signing')." >&2
  exit 1
fi

flutter --version | head -1
flutter pub get --enforce-lockfile --no-example
dart run slang
flutter build apk --release --target-platform android-arm64 --split-per-abi \
  --dart-define=GIT_COMMIT="$(git rev-parse HEAD)"

version="$(sed -n 's/^version: \(.*\)+.*/\1/p' pubspec.yaml)"
out="build/fork/plezy-preroll-${version}-arm64-v8a.apk"
mkdir -p build/fork
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk "$out"
sha256sum "$out"
apksigner="$(ls -d "$ANDROID_HOME"/build-tools/*/apksigner | sort -V | tail -1)"
"$apksigner" verify --print-certs "$out" | grep -m1 'SHA-256'
