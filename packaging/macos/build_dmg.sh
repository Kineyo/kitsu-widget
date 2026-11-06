#!/usr/bin/env bash
# ============================================================================
# build_dmg.sh - macOS App Bundle & .dmg / .pkg Builder for Kitsu v2.0
# ============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
APP_DIR="${DIST_DIR}/Kitsu.app"
VERSION="2.0.0"

mkdir -p "${DIST_DIR}"
rm -rf "${APP_DIR}"

mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources/bin"
mkdir -p "${APP_DIR}/Contents/Resources/lib/skills"
mkdir -p "${APP_DIR}/Contents/Resources/lib/native"
mkdir -p "${APP_DIR}/Contents/Resources/assets"
mkdir -p "${APP_DIR}/Contents/Resources/models"

cp -a "${ROOT_DIR}/bin/"* "${APP_DIR}/Contents/Resources/bin/" 2>/dev/null || true
cp -a "${ROOT_DIR}/lib/"*.lua "${APP_DIR}/Contents/Resources/lib/"
cp -a "${ROOT_DIR}/lib/"*.so "${APP_DIR}/Contents/Resources/lib/" 2>/dev/null || true
cp -a "${ROOT_DIR}/lib/skills/"*.lua "${APP_DIR}/Contents/Resources/lib/skills/"
cp -a "${ROOT_DIR}/assets/"* "${APP_DIR}/Contents/Resources/assets/"

cat > "${APP_DIR}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>kitsu-macos</string>
    <key>CFBundleIdentifier</key>
    <string>org.kitsu.desktop</string>
    <key>CFBundleName</key>
    <string>Kitsu</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

cat > "${APP_DIR}/Contents/MacOS/kitsu-macos" <<'EOF'
#!/usr/bin/env bash
RES_DIR="$(cd "$(dirname "$0")/../Resources" && pwd)"
export KITSU_DIR="$RES_DIR"
export KITSU_ROOT="$RES_DIR"
export QWEN_WIDGET_DIR="$RES_DIR"
export QWEN_WIDGET_ROOT="$RES_DIR"
if [ -x "${RES_DIR}/bin/kitsu-bin" ]; then
    exec "${RES_DIR}/bin/kitsu-bin" "$@"
else
    exec "${RES_DIR}/bin/qwen-widget-bin" "$@"
fi
EOF
chmod +x "${APP_DIR}/Contents/MacOS/kitsu-macos"

if command -v hdiutil >/dev/null 2>&1; then
    hdiutil create -volname "Kitsu ${VERSION}" -srcfolder "${APP_DIR}" -ov -format UDZO "${DIST_DIR}/Kitsu-${VERSION}-macOS.dmg"
    cp -f "${DIST_DIR}/Kitsu-${VERSION}-macOS.dmg" "${DIST_DIR}/QwenWidget-${VERSION}-macOS.dmg" 2>/dev/null || true
fi
