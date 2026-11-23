#!/bin/sh
# Build and install the Vibival flatpak for the current user.
#   tools/build-flatpak.sh             build + install
#   tools/build-flatpak.sh --bundle    also write vibival.flatpak
#   tools/build-flatpak.sh --release   GPG-sign the repo (commits and summary)
#                                      and write a signed vibival.flatpak
#   tools/build-flatpak.sh --test      write build/flatpak-test/Vibival-Test.flatpak
#                                      as top.dns7.vibival.test ("Vibival Test"),
#                                      unsigned and not installed; it installs
#                                      beside the real game with its own saves
# The release key is read from $VIBIVAL_SIGNING (default
# ~/.local/share/vibival-signing): gnupg/ holds the key, flatpak-gpg-key-id its
# fingerprint and vibival-flatpak.gpg the public key.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
MODE=${1:-}
SIGN=""
if [ "$MODE" = "--test" ]; then
  # A renamed copy of the packaging files; flatpak/, repo/ and the installed
  # game are left alone.
  OUT=$ROOT/build/flatpak-test
  APP=top.dns7.vibival.test
  rm -rf "$OUT"
  mkdir -p "$OUT/flatpak"
  cp flatpak/vibival.sh "$OUT/flatpak/"
  cp flatpak/top.dns7.vibival.svg "$OUT/flatpak/$APP.svg"
  sed -e "s/top\.dns7\.vibival/$APP/g" -e 's/^Name=Vibival$/Name=Vibival Test/' \
    flatpak/top.dns7.vibival.desktop > "$OUT/flatpak/$APP.desktop"
  sed -e "s/top\.dns7\.vibival/$APP/g" -e 's|<name>Vibival</name>|<name>Vibival Test</name>|' \
    flatpak/top.dns7.vibival.metainfo.xml > "$OUT/flatpak/$APP.metainfo.xml"
  sed -e "s/top\.dns7\.vibival/$APP/g" -e 's|path: \.\./|path: ../../../|' \
    flatpak/top.dns7.vibival.yml > "$OUT/flatpak/$APP.yml"
  flatpak-builder --user --force-clean --state-dir="$OUT/state" --repo="$OUT/repo" \
    "$OUT/build-dir" "$OUT/flatpak/$APP.yml"
  flatpak build-bundle --runtime-repo=https://dl.flathub.org/repo/flathub.flatpakrepo \
    "$OUT/repo" "$OUT/Vibival-Test.flatpak" "$APP"
  echo "wrote $OUT/Vibival-Test.flatpak"
  exit 0
fi
if [ "$MODE" = "--release" ]; then
  SIGNING=${VIBIVAL_SIGNING:-$HOME/.local/share/vibival-signing}
  KEY=$(cat "$SIGNING/flatpak-gpg-key-id")
  SIGN="--gpg-sign=$KEY --gpg-homedir=$SIGNING/gnupg"
fi
# shellcheck disable=SC2086
flatpak-builder --user --install --force-clean --repo=repo $SIGN \
  build-dir flatpak/top.dns7.vibival.yml
if [ -n "$SIGN" ]; then
  # shellcheck disable=SC2086
  flatpak build-update-repo --generate-static-deltas --prune $SIGN repo
fi
if [ "$MODE" = "--bundle" ] || [ -n "$SIGN" ]; then
  # The Godot BaseApp is baked into the app; only the Freedesktop runtime is
  # fetched from Flathub when the bundle is installed. A release bundle also
  # carries the public key, so its origin remote verifies updates.
  # shellcheck disable=SC2086
  flatpak build-bundle $SIGN ${SIGN:+--gpg-keys=$SIGNING/vibival-flatpak.gpg} \
    --runtime-repo=https://dl.flathub.org/repo/flathub.flatpakrepo \
    repo vibival.flatpak top.dns7.vibival
  echo "wrote $ROOT/vibival.flatpak"
fi
