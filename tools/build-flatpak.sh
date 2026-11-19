#!/bin/sh
# Build and install the Vibival flatpak for the current user.
#   tools/build-flatpak.sh             build + install
#   tools/build-flatpak.sh --bundle    also write vibival.flatpak
#   tools/build-flatpak.sh --release   GPG-sign the repo (commits and summary)
#                                      and write a signed vibival.flatpak
# The release key is read from $VIBIVAL_SIGNING (default
# ~/.local/share/vibival-signing): gnupg/ holds the key, flatpak-gpg-key-id its
# fingerprint and vibival-flatpak.gpg the public key.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
MODE=${1:-}
SIGN=""
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
