#!/bin/sh
# Export the web or Android build with the official Godot editor in .tools/.
#   tools/export.sh web       build/web/index.html (+ .wasm, .pck, .js)
#   tools/export.sh android   build/android/vibival.apk (debug-signed; needs the
#                             Android SDK and JDK paths in the editor settings)
#   tools/export.sh android-test
#                             build/android-test/vibival.apk: the debug build as
#                             top.dns7.vibival.test ("Vibival Test"), so it
#                             installs beside the real game with its own saves
#   tools/export.sh android-test-lite
#                             build/android-test-lite/vibival.apk: the same, arm64
#                             only and without the music, small enough to send
#                             (under 30 MiB)
#   tools/export.sh android-release
#                             build/android-release/vibival.apk, signed with the
#                             release key in $VIBIVAL_SIGNING (default
#                             ~/.local/share/vibival-signing/android-release.env)
#   tools/export.sh android-x86-release
#                             build/android-x86-release/vibival.apk: the same,
#                             for x86 devices only (32- and 64-bit x86; the
#                             main APK is arm64 and x86_64)
# The game is staged in build/stage so the editor's import cache and .import
# files never land in game/. Music is kept as raw files ("keep" importer),
# since it is loaded at runtime from its bytes.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
GODOT=${GODOT:-$ROOT/.tools/godot/Godot_v4.7.2-stable_linux.x86_64}
TARGET=${1:?usage: tools/export.sh web|android|android-test|android-test-lite|android-release|android-x86-release}
SIGNING=${VIBIVAL_SIGNING:-$HOME/.local/share/vibival-signing}
STAGE=$ROOT/build/stage
MODE=--export-release
ARCHS=""   # Android architectures to build in place of the preset's, if set
TEST=""    # set for the side-by-side test package
NO_MUSIC=""  # set to leave the music out
case "$TARGET" in
  web) PRESET=Web; OUT=$ROOT/build/web/index.html ;;
  android|android-test|android-test-lite)
    PRESET=Android; OUT=$ROOT/build/$TARGET/vibival.apk; MODE=--export-debug
    [ "$TARGET" != android ] && TEST=1
    [ "$TARGET" = android-test-lite ] && { ARCHS="arm64-v8a"; NO_MUSIC=1; }
    # Signed with the editor's debug keystore (export/android/debug_keystore
    # in its editor settings), made here if it is missing.
    KS=$(dirname "$GODOT")/editor_data/keystores/debug.keystore
    if [ ! -f "$KS" ]; then
      mkdir -p "$(dirname "$KS")"
      keytool -genkeypair -keystore "$KS" -storepass android -keypass android \
        -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 \
        -dname "CN=Android Debug,O=Android,C=US"
    fi
    ;;
  android-release|android-x86-release)
    PRESET=Android; OUT=$ROOT/build/$TARGET/vibival.apk
    [ "$TARGET" = android-x86-release ] && ARCHS="x86 x86_64"
    # The keystore path, alias and password come from the env file and are
    # read by the editor (GODOT_ANDROID_KEYSTORE_RELEASE_*), never stored here.
    ENV=$SIGNING/android-release.env
    [ -f "$ENV" ] || { echo "missing $ENV" >&2; exit 1; }
    set -a; . "$ENV"; set +a
    [ -f "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" ] || {
      echo "missing keystore $GODOT_ANDROID_KEYSTORE_RELEASE_PATH" >&2; exit 1; }
    ;;
  *) echo "unknown target: $TARGET" >&2; exit 2 ;;
esac
rm -rf "$STAGE" "$(dirname "$OUT")"
mkdir -p "$STAGE" "$(dirname "$OUT")"
cp -r "$ROOT/game/." "$STAGE/"
rm -rf "$STAGE/tests" "$STAGE/.godot"
# The exports want a project icon; the source tree has none (nothing in it is
# imported), so the staged copy gets the flatpak's.
cp "$ROOT/flatpak/top.dns7.vibival.svg" "$STAGE/icon.svg"
sed -i 's|^config/name=.*|&\nconfig/icon="res://icon.svg"|' "$STAGE/project.godot"
if [ -n "$ARCHS" ]; then
  # Only the staged copy of the presets changes: every architecture off, then
  # the ones asked for on.
  sed -i 's|^\(architectures/[a-z0-9_-]*\)=true|\1=false|' "$STAGE/export_presets.cfg"
  for a in $ARCHS; do
    sed -i "s|^architectures/$a=false|architectures/$a=true|" "$STAGE/export_presets.cfg"
  done
  grep '^architectures/' "$STAGE/export_presets.cfg"
fi
if [ -n "$TEST" ]; then
  sed -i -e 's|^package/unique_name=.*|package/unique_name="top.dns7.vibival.test"|' \
    -e 's|^package/name=.*|package/name="Vibival Test"|' "$STAGE/export_presets.cfg"
  grep '^package/\(unique_\)\?name=' "$STAGE/export_presets.cfg"
fi
# The game plays no music when it finds no tracks.
[ -n "$NO_MUSIC" ] && rm -f "$STAGE"/music/*.mp3 "$STAGE"/music/*.ogg
for f in "$STAGE"/music/*.mp3 "$STAGE"/music/*.ogg; do
  [ -e "$f" ] && printf '[remap]\n\nimporter="keep"\n' > "$f.import"
done
"$GODOT" --headless --path "$STAGE" --import
"$GODOT" --headless --path "$STAGE" "$MODE" "$PRESET" "$OUT"
ls -l "$(dirname "$OUT")"
