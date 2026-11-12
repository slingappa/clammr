#!/bin/sh
# Build Clammr.app. Pass "install" to copy into ~/Applications and launch.
set -e
cd "$(dirname "$0")"

APP=Clammr.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

swiftc -O -swift-version 5 App.swift -o "$APP/Contents/MacOS/Clammr"

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
