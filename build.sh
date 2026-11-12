#!/bin/sh
# Build Clammr.app. Pass "install" to copy into ~/Applications and launch.
set -e
cd "$(dirname "$0")"

APP=Clammr.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

swiftc -O -swift-version 5 App.swift -o "$APP/Contents/MacOS/Clammr"

# App icon: render original artwork from make_icon.swift -> .iconset -> .icns
mkdir -p "$APP/Contents/Resources"
TMP=$(mktemp -d)
swift make_icon.swift "$TMP/icon_1024.png" >/dev/null
mkdir "$TMP/AppIcon.iconset"
for s in 16 32 128 256 512; do
    sips -z $s $s "$TMP/icon_1024.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
    d=$((s * 2))
    sips -z $d $d "$TMP/icon_1024.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$TMP/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$TMP"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Clammr</string>
    <key>CFBundleDisplayName</key><string>Clammr</string>
    <key>CFBundleIdentifier</key><string>local.clammr</string>
    <key>CFBundleExecutable</key><string>Clammr</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>NSHumanReadableCopyright</key><string>© 2026 Subrahmanya Lingappa · MIT License</string>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"
echo "built ./$APP"

if [ "$1" = "install" ]; then
    mkdir -p "$HOME/Applications"
    killall Clammr 2>/dev/null || true
    rm -rf "$HOME/Applications/$APP"
    cp -R "$APP" "$HOME/Applications/"
    open "$HOME/Applications/$APP"
    echo "installed + launched ~/Applications/$APP"
fi
