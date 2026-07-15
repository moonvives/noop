#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
REPOSITORY_ROOT="$(cd "$ROOT/.." && pwd)"
BUILD_DIR="$ROOT/build"
LOCK_DIR="$ROOT/.build-lock"
APP_NAME="VWAR Loop Life"
EXECUTABLE_NAME="VWARLoopLifeMac"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
OUTPUT_ZIP="${OUTPUT_ZIP:-$REPOSITORY_ROOT/../VWAR-Loop-Life-macOS12.7.6.app.zip}"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
DEPLOYMENT_TARGET="12.0"
TARGET_ARCHS="${TARGET_ARCHS:-$(uname -m)}"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "Já existe uma compilação do VWAR em andamento." >&2
  exit 20
fi
trap 'rm -rf "$LOCK_DIR"' EXIT INT TERM

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/bin" "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources/pt-BR.lproj"

SOURCE_FILES=("$ROOT"/Sources/*.swift)
BUILT_BINARIES=()
BUILT_ARCHS=()

for ARCH in $TARGET_ARCHS; do
  BINARY="$BUILD_DIR/bin/$EXECUTABLE_NAME-$ARCH"
  echo "Compilando $ARCH para macOS $DEPLOYMENT_TARGET…"
  swiftc \
    -parse-as-library \
    -O \
    -target "$ARCH-apple-macosx$DEPLOYMENT_TARGET" \
    -sdk "$SDK_PATH" \
    -module-name VWARLoopLifeMac \
    -framework AppKit \
    -framework SwiftUI \
    -framework UniformTypeIdentifiers \
    -Xlinker -dead_strip \
    "${SOURCE_FILES[@]}" \
    -o "$BINARY"
  BUILT_BINARIES+=("$BINARY")
  BUILT_ARCHS+=("$ARCH")
done

if [[ "${#BUILT_BINARIES[@]}" -eq 1 ]]; then
  cp "${BUILT_BINARIES[0]}" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
else
  lipo -create "${BUILT_BINARIES[@]}" -output "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
fi
chmod 755 "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"

cp "$ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
printf 'APPL????' > "$APP_BUNDLE/Contents/PkgInfo"
printf '"CFBundleDisplayName" = "VWAR Loop Life";\n' > "$APP_BUNDLE/Contents/Resources/pt-BR.lproj/InfoPlist.strings"

ICON_SOURCE_SET="$REPOSITORY_ROOT/Strand/Resources/Assets.xcassets/AppIcon.appiconset"
if [[ -d "$ICON_SOURCE_SET" ]]; then
  ICONSET="$BUILD_DIR/AppIcon.iconset"
  mkdir -p "$ICONSET"
  for ICON_FILE in \
    icon_16x16.png icon_16x16@2x.png \
    icon_32x32.png icon_32x32@2x.png \
    icon_128x128.png icon_128x128@2x.png \
    icon_256x256.png icon_256x256@2x.png \
    icon_512x512.png icon_512x512@2x.png; do
    cp "$ICON_SOURCE_SET/$ICON_FILE" "$ICONSET/$ICON_FILE"
  done
  iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

plutil -lint "$APP_BUNDLE/Contents/Info.plist"
codesign --force --deep --sign - "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

TEST_BINARY="$BUILD_DIR/ParserSmoke"
swiftc \
  -O \
  -target "$(uname -m)-apple-macosx$DEPLOYMENT_TARGET" \
  -sdk "$SDK_PATH" \
  -module-name VWARHealthArchiveSmoke \
  "$ROOT/Sources/HealthArchive.swift" \
  "$ROOT/Tests/ParserSmoke.swift" \
  -o "$TEST_BINARY"
"$TEST_BINARY" "$ROOT/Tests/fixture.xml" --fixture

rm -f "$OUTPUT_ZIP"
mkdir -p "$(dirname "$OUTPUT_ZIP")"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$OUTPUT_ZIP"
unzip -tq "$OUTPUT_ZIP"

ARCH_LIST="$(lipo -archs "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME")"
for ARCH in "${BUILT_ARCHS[@]}"; do
  [[ " $ARCH_LIST " == *" $ARCH "* ]] || { echo "Arquitetura ausente: $ARCH" >&2; exit 10; }
done

MIN_OS_COUNT="$(otool -l "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME" | awk '/minos 12\.0/{count++} END{print count+0}')"
[[ "$MIN_OS_COUNT" -eq "${#BUILT_ARCHS[@]}" ]] || { echo "LC_BUILD_VERSION não declara macOS 12.0 em todas as arquiteturas" >&2; exit 11; }

echo "App: $APP_BUNDLE"
echo "ZIP: $OUTPUT_ZIP"
echo "Arquiteturas: $ARCH_LIST"
echo "Sistema mínimo: macOS $DEPLOYMENT_TARGET"
