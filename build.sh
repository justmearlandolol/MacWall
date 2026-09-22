#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Live HTML Wallpaper — build script (tanpa Xcode project, tanpa dependency)
#
# Hasil: build/LiveHTMLWallpaper.app
#        Universal binary: x86_64 (10.13 High Sierra+) + arm64 (11.0+)
#
# Butuh: macOS + Xcode Command Line Tools:
#        xcode-select --install
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")"

# ---- Identitas app (ubah di sini kalau mau ganti nama) --------------------
APP_NAME="LiveHTMLWallpaper"
BUNDLE_ID="com.brochacho.livehtmlwallpaper"
VERSION="${VERSION:-0.1.0}"

MIN_X86="10.13"   # High Sierra — target utama
MIN_ARM="11.0"    # Big Sur — slice Apple Silicon pertama

OUT="build"
APP="$OUT/$APP_NAME.app"
MACOS_DIR="$APP/Contents/MacOS"
RESOURCES_DIR="$APP/Contents/Resources"

# Semua source Objective-C ada di SATU file: src/main.m
SRC=(src/main.m)

CFLAGS=(
	-x objective-c
	-fobjc-arc
	-Wall
	-Wno-deprecated-declarations
	-O2
)
LDLIBS=(-framework Cocoa -framework WebKit -framework CoreGraphics)

echo "==> Toolchain: $(xcrun clang --version | head -1)"

echo "==> Bersihin build lama"
rm -rf "$APP"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

echo "==> Nulis Info.plist"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>$APP_NAME</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleName</key>
	<string>Live HTML Wallpaper</string>
	<key>CFBundleDisplayName</key>
	<string>Live HTML Wallpaper</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundleVersion</key>
	<string>$VERSION</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleDevelopmentRegion</key>
	<string>id</string>
	<key>LSMinimumSystemVersion</key>
	<string>$MIN_X86</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
PLIST

echo "==> Compile slice x86_64 (min $MIN_X86 — High Sierra)"
xcrun clang "${CFLAGS[@]}" -arch x86_64 -mmacosx-version-min="$MIN_X86" \
	"${SRC[@]}" "${LDLIBS[@]}" -o "$OUT/slice-x86_64"

echo "==> Compile slice arm64 (min $MIN_ARM — Apple Silicon)"
xcrun clang "${CFLAGS[@]}" -arch arm64 -mmacosx-version-min="$MIN_ARM" \
	"${SRC[@]}" "${LDLIBS[@]}" -o "$OUT/slice-arm64"

echo "==> Lipo jadi satu universal binary"
lipo -create -output "$MACOS_DIR/$APP_NAME" "$OUT/slice-x86_64" "$OUT/slice-arm64"
xcrun strip "$MACOS_DIR/$APP_NAME" || true

echo "==> Bundel wallpaper bawaan ke Resources"
cp wallpapers/wallpaper.html "$RESOURCES_DIR/wallpaper.html"

echo "==> Ad-hoc codesign (nggak butuh akun Apple Developer)"
codesign --force --sign - "$APP"
codesign --verify --verbose=2 "$APP" || true

echo ""
echo "✅ Selesai: $APP"
echo "   Jalanin:  open $APP"
