#!/bin/bash
set -e

APP_NAME="iMic"
APP_DIR="build/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

echo "🧹 Cleaning old build..."
rm -rf build
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "🔨 Compiling Swift sources..."
swiftc -O -parse-as-library -o "$MACOS_DIR/$APP_NAME" Sources/*.swift \
    -framework SwiftUI \
    -framework AppKit \
    -framework CoreAudio \
    -framework IOKit \
    -framework ApplicationServices

cp Resources/AppIcon.icns "$RESOURCES_DIR/"

echo "📝 Generating Info.plist..."
cat > "$APP_DIR/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.user.iMic</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>iMic requires audio access to monitor and manage input devices.</string>
</dict>
</plist>
EOF

echo "🔏 Signing app bundle with persistent local certificate..."
if security find-certificate -c "iMic Self Signed" >/dev/null 2>&1; then
    codesign --force --deep -s "iMic Self Signed" "$APP_DIR"
else
    codesign --force --deep -s - "$APP_DIR"
fi

echo "✨ Build complete! $APP_DIR created."
