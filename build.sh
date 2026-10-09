#!/bin/zsh
# Builds Clips.app, installs it to /Applications and restarts it.
set -e
cd "${0:A:h}"

APP=build/Clips.app
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/AppIcon.iconset
cp Info.plist "$APP/Contents/"

echo "Compiling…"
swiftc -O Sources/*.swift -o "$APP/Contents/MacOS/Clips"

echo "Making icon…"
swiftc makeicon.swift -o build/makeicon
build/makeicon build/icon.png
for s in 16 32 128 256 512; do
  sips -z $s $s build/icon.png --out build/AppIcon.iconset/icon_${s}x${s}.png >/dev/null
  sips -z $((s * 2)) $((s * 2)) build/icon.png --out build/AppIcon.iconset/icon_${s}x${s}@2x.png >/dev/null
done
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

# Signing with the same local certificate every time keeps the Accessibility permission across rebuilds.
IDENTITY=$(security find-identity -p codesigning | awk '/Vikram Local Code Signing/ {print $2; exit}')
codesign --force --sign "${IDENTITY:--}" "$APP"

echo "Installing…"
killall Clips 2>/dev/null || true
while pgrep -x Clips >/dev/null; do sleep 0.1; done   # wait for the old copy to quit before relaunching
rm -rf /Applications/Clips.app
ditto "$APP" /Applications/Clips.app
open /Applications/Clips.app
echo "Done: /Applications/Clips.app"
