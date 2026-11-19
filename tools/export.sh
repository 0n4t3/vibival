#!/bin/sh
# Export the web or Android build with the official Godot editor in .tools/.
#   tools/export.sh web       build/web/index.html (+ .wasm, .pck, .js)
#   tools/export.sh android   build/android/vibival.apk (debug-signed; needs the
#                             Android SDK and JDK paths in the editor settings)
#   tools/export.sh android-release
#                             build/android-release/vibival.apk, signed with the
#                             release key in $VIBIVAL_SIGNING (default
#                             ~/.local/share/vibival-signing/android-release.env)
# The game is staged in build/stage so the editor's import cache and .import
# files never land in game/. Music is kept as raw files ("keep" importer),
# since it is loaded at runtime from its bytes.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
GODOT=${GODOT:-$ROOT/.tools/godot/Godot_v4.7.2-stable_linux.x86_64}
TARGET=${1:?usage: tools/export.sh web|android|android-release}
SIGNING=${VIBIVAL_SIGNING:-$HOME/.local/share/vibival-signing}
STAGE=$ROOT/build/stage
MODE=--export-release
case "$TARGET" in
  web) PRESET=Web; OUT=$ROOT/build/web/index.html ;;
  android)
    PRESET=Android; OUT=$ROOT/build/android/vibival.apk; MODE=--export-debug
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
  android-release)
    PRESET=Android; OUT=$ROOT/build/android-release/vibival.apk
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
for f in "$STAGE"/music/*.mp3 "$STAGE"/music/*.ogg; do
  [ -e "$f" ] && printf '[remap]\n\nimporter="keep"\n' > "$f.import"
done
"$GODOT" --headless --path "$STAGE" --import
"$GODOT" --headless --path "$STAGE" "$MODE" "$PRESET" "$OUT"
ls -l "$(dirname "$OUT")"
