#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
sdk="${ANDROID_SDK_ROOT:-$root/tools/android-sdk}"
java_home="${JAVA_HOME:-$root/tools/local/jdk17}"
export JAVA_HOME="$java_home"
export PATH="$java_home/bin:$PATH"
buildtools="${ANDROID_BUILD_TOOLS:-$sdk/build-tools/36.0.0}"
signing="${SHANGHAI_SIGNING_DIR:-$root/tools/signing}"
output="${1:-$root/builds/v0.2/android/Shanghai-OpenWorld-v0.2.0-arm64.apk}"
out_dir="$(dirname "$output")"
mkdir -p "$out_dir"
output="$(cd "$out_dir" && pwd)/$(basename "$output")"
for utility in "$buildtools/apksigner" "$buildtools/aapt" "$java_home/bin/keytool"; do
    if [[ ! -x "$utility" ]]; then
        printf 'Missing Android build dependency %s\n' "$utility" >&2
        exit 1
    fi
done
if [[ ! -s "$signing/shanghai-release.p12" || ! -s "$signing/password" ]]; then
    printf 'Restore the original V0.1 signing key and password to %s\n' "$signing" >&2
    exit 1
fi
actual_certificate="$(keytool -exportcert -keystore "$signing/shanghai-release.p12" \
    -storepass:file "$signing/password" -alias shanghai-release | sha256sum | cut -d' ' -f1)"
expected_certificate="$(<docs/android-release-certificate.sha256)"
if [[ "$actual_certificate" != "$expected_certificate" ]]; then
    printf 'Release key does not match the original Android APK certificate.\n' >&2
    exit 1
fi
install -m 0644 docs/android-release-certificate.pem "$out_dir/public-certificate.pem"
tools/configure_editor.py "$sdk" "$java_home"
work="$(mktemp -d "$out_dir/.build-XXXXXX")"
trap 'rm -rf "$work"' EXIT
tools/godot.sh --headless --editor --import
tools/godot.sh --headless --export-release Android "$work/export.apk"
python3 tools/fix_android_manifest.py "$work/export.apk" "$work/manifest.apk"
"$buildtools/zipalign" -f -P 16 4 "$work/manifest.apk" "$work/aligned.apk"
"$buildtools/apksigner" sign --ks "$signing/shanghai-release.p12" --ks-key-alias shanghai-release \
    --ks-pass "file:$signing/password" --v4-signing-enabled false --out "$work/signed.apk" "$work/aligned.apk"
"$buildtools/aapt" dump badging "$work/signed.apk" > "$work/badging.txt"
mv "$work/signed.apk" "$output"
"$buildtools/apksigner" verify --verbose --print-certs "$output"
"$buildtools/zipalign" -c -P 16 -v 4 "$output" > "$out_dir/zipalign.txt"
"$buildtools/aapt" dump badging "$output" > "$out_dir/badging.txt"
"$buildtools/aapt" dump xmltree "$output" AndroidManifest.xml > "$out_dir/manifest.txt"
unzip -tq "$output"
(cd "$out_dir" && sha256sum "$(basename "$output")" > SHA256SUMS)
