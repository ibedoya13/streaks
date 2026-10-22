#!/usr/bin/env bash
# Renders the Streaks icon set and installs it into the Android resources.
#
# The SVGs live in assets/icon/ (see tool/generate_icon.py). SVG is rasterised
# with macOS `qlmanage`, which is available on every Mac and needs no extra
# tooling. Densities follow the standard Android launcher sizes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICON_DIR="$ROOT/assets/icon"
RES_DIR="$ROOT/android/app/src/main/res"

# density:legacy size:adaptive foreground size
DENSITIES=(
  "mdpi:48:108"
  "hdpi:72:162"
  "xhdpi:96:216"
  "xxhdpi:144:324"
  "xxxhdpi:192:432"
)

echo "==> Rendering SVG sources"
cd "$ICON_DIR"
for svg in app_icon app_icon_round app_icon_foreground app_icon_monochrome; do
  rm -f "$svg.svg.png"
  qlmanage -t -s 1024 -o . "$svg.svg" >/dev/null 2>&1
done

render() { # <source svg> <target png> <size>
  sips -s format png -z "$3" "$3" "$ICON_DIR/$1.svg.png" --out "$2" >/dev/null
}

echo "==> Installing launcher icons"
for entry in "${DENSITIES[@]}"; do
  IFS=":" read -r density legacy fg <<<"$entry"
  dir="$RES_DIR/mipmap-$density"
  mkdir -p "$dir"
  render app_icon          "$dir/ic_launcher.png"          "$legacy"
  render app_icon_round    "$dir/ic_launcher_round.png"    "$legacy"
  render app_icon_foreground "$dir/ic_launcher_foreground.png" "$fg"
  render app_icon_monochrome "$dir/ic_launcher_monochrome.png" "$fg"
  echo "    mipmap-$density  legacy=${legacy}px  foreground=${fg}px"
done

echo "==> Writing adaptive icon XML"
mkdir -p "$RES_DIR/mipmap-anydpi-v26"
for name in ic_launcher ic_launcher_round; do
  cat > "$RES_DIR/mipmap-anydpi-v26/$name.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
XML
done

echo "==> Writing background colour"
cat > "$RES_DIR/values/ic_launcher_background.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#FDF6EC</color>
</resources>
XML

echo "==> Cleaning up rendered intermediates"
rm -f "$ICON_DIR"/*.svg.png

echo "Done."
