#!/bin/bash
set -e

# Install dependencies: brew install graphicsmagick imagemagick npq
PROJECT_DIR="$(pwd)"
BUILD_DIR="$PROJECT_DIR/build"
echo "==> Cleaning build directory..."

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Building release archive..."
xcodebuild -project "$PROJECT_DIR/System Spinner.xcodeproj" \
    -scheme "System Spinner" \
    -configuration Release \
    -archivePath "$BUILD_DIR/System Spinner.xcarchive" \
    archive

#echo "==> Exporting notarized app..."
xcodebuild -exportArchive \
    -archivePath "$BUILD_DIR/System Spinner.xcarchive" \
    -exportPath "$BUILD_DIR" \
    -exportOptionsPlist "$PROJECT_DIR/ExportOptions.plist"

echo "==> Creating DMG..."
npx create-dmg "$BUILD_DIR/System Spinner.app" "$BUILD_DIR" --overwrite --no-code-sign

echo "==> Done!"
echo "DMG created at: $BUILD_DIR/"
ls -la "$BUILD_DIR"/*.dmg