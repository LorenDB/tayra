#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLATPAK_DIR="$PROJECT_ROOT/flatpak"
MANIFEST="$FLATPAK_DIR/dev.lorendb.tayra.yml"

echo "=== Tayra Flatpak Build Script ==="
echo "Project root: $PROJECT_ROOT"
echo ""

# Check if flatpak-builder is installed
if ! command -v flatpak-builder &> /dev/null; then
  echo "❌ flatpak-builder not found. Install flatpak first."
  exit 1
fi

# Check SDK
echo "Checking for GNOME SDK 48..."
if ! flatpak info org.gnome.Sdk//48 &> /dev/null; then
  echo "⚠️  SDK not installed. Installing..."
  flatpak install -y flathub org.gnome.Sdk//48
fi

# Resize icon to 512x512 (Flatpak maximum)
echo "Preparing icon..."
if ! command -v magick &> /dev/null; then
  echo "❌ ImageMagick 'magick' not found. Install imagemagick."
  exit 1
fi
# Helper: create rounded-corner version of an image
make_rounded() {
  src="$1"
  dst="$2"
  size="$3"
  # radius: ~1/6 of size for a gentle rounding
  radius=$((size / 6))

  # Build an antialiased rounded-rect mask at the target size and apply it
  # as the alpha channel. -antialias smooths the mask edges cleanly.
  magick "$src" -resize "${size}x${size}" -gravity center -alpha set \
    \( -size ${size}x${size} xc:none -fill white -antialias \
       -draw "roundrectangle 0,0,$((size-1)),$((size-1)) ${radius},${radius}" \) \
    -compose CopyOpacity -composite -define png:color-type=6 "$dst"
}

# Generate rounded icons used by Flatpak and native bundle
make_rounded "$PROJECT_ROOT/assets/tayra.png" "$FLATPAK_DIR/dev.lorendb.tayra.png" 512
make_rounded "$PROJECT_ROOT/assets/tayra.png" "$FLATPAK_DIR/dev.lorendb.tayra-256.png" 256
make_rounded "$PROJECT_ROOT/assets/tayra.png" "$FLATPAK_DIR/dev.lorendb.tayra-128.png" 128
make_rounded "$PROJECT_ROOT/assets/tayra.png" "$FLATPAK_DIR/dev.lorendb.tayra-64.png" 64
make_rounded "$PROJECT_ROOT/assets/tayra.png" "$FLATPAK_DIR/dev.lorendb.tayra-48.png" 48
make_rounded "$PROJECT_ROOT/assets/tayra.png" "$FLATPAK_DIR/dev.lorendb.tayra-32.png" 32
make_rounded "$PROJECT_ROOT/assets/tayra.png" "$FLATPAK_DIR/dev.lorendb.tayra-16.png" 16

# Also write a rounded 512px icon into assets for native Linux bundle install
make_rounded "$PROJECT_ROOT/assets/tayra.png" "$PROJECT_ROOT/assets/tayra-rounded.png" 512

# Build Flutter release
echo ""
echo "Building Flutter app in release mode..."
cd "$PROJECT_ROOT"
flutter build linux --release


# Build Flatpak
echo ""
echo "Building Flatpak..."
cd "$FLATPAK_DIR"
flatpak-builder --force-clean build-dir "$MANIFEST"

echo ""
echo "✅ Flatpak built successfully!"
echo ""
echo "To install and run locally:"
echo "  flatpak-builder --user --install --force-clean build-dir $MANIFEST"
echo "  flatpak run dev.lorendb.tayra"
