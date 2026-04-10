#!/bin/bash
set -e

FLATPAK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$FLATPAK_DIR/dev.lorendb.tayra.yml"

echo "Installing and running Tayra Flatpak..."
flatpak-builder --user --install --force-clean "$FLATPAK_DIR/build-dir" "$MANIFEST"

FLATPAK_EXPORTS="$HOME/.local/share/flatpak/exports/share"
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$FLATPAK_EXPORTS/applications" >/dev/null 2>&1 || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t "$FLATPAK_EXPORTS/icons/hicolor" >/dev/null 2>&1 || true
fi
if command -v kbuildsycoca6 >/dev/null 2>&1; then
  kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
fi

echo "Launching Tayra..."
flatpak run dev.lorendb.tayra
