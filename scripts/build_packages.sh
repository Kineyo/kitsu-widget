#!/usr/bin/env bash
# ============================================================================
# build_packages.sh - Builds Kitsu v2.4.1 Packages Locally (Pop!_OS / Linux)
# Outputs in dist/:
#   1. kitsu_2.4.1_amd64.deb (Debian / Ubuntu / Pop!_OS package)
#   2. kitsu-2.4.1-linux-x86_64.tar.gz (Universal portable tarball)
# ============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
VERSION="2.4.1"
ARCH="amd64"
export PATH="$HOME/.local/bin:$PATH"

echo "[1/4] Compiling C/C++ native extensions with CMake..."
mkdir -p "${ROOT_DIR}/build" "${DIST_DIR}"
cmake -S "${ROOT_DIR}" -B "${ROOT_DIR}/build" -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "${ROOT_DIR}/build" -j"$(nproc 2>/dev/null || echo 2)" >/dev/null

# Locate lua5.3 runtime to bundle inside packages
LUA_BIN=""
for cand in "${ROOT_DIR}/bin/lua5.3" "/opt/kitsu/bin/lua5.3" "/opt/qwen-widget/bin/lua5.3" "$HOME/.local/bin/lua5.3" /usr/bin/lua5.3; do
    if [ -x "$cand" ]; then
        LUA_BIN="$cand"
        break
    fi
done

echo "[2/4] Building Debian / Ubuntu / Pop!_OS package (.deb)..."
DEB_STAGE="$(mktemp -d)"
mkdir -p "${DEB_STAGE}/DEBIAN"
mkdir -p "${DEB_STAGE}/opt/kitsu/bin"
mkdir -p "${DEB_STAGE}/opt/kitsu/lib/native"
mkdir -p "${DEB_STAGE}/opt/kitsu/lib/skills"
mkdir -p "${DEB_STAGE}/opt/kitsu/assets/sprites"
mkdir -p "${DEB_STAGE}/opt/kitsu/assets/icons"
mkdir -p "${DEB_STAGE}/opt/kitsu/models"
mkdir -p "${DEB_STAGE}/usr/local/bin"
mkdir -p "${DEB_STAGE}/usr/share/applications"

# Copy binaries
for b in kitsu kitsu-power kitsu-avatar kitsu-bin qwen-widget qwen-power qwen-avatar qwen-widget-bin llama-server; do
    [ -f "${ROOT_DIR}/bin/${b}" ] && cp -a "${ROOT_DIR}/bin/${b}" "${DEB_STAGE}/opt/kitsu/bin/"
done
[ -n "$LUA_BIN" ] && cp -a "$LUA_BIN" "${DEB_STAGE}/opt/kitsu/bin/lua5.3"
chmod 755 "${DEB_STAGE}/opt/kitsu/bin/"*

# Copy libraries and assets
cp -a "${ROOT_DIR}/lib/"*.lua "${DEB_STAGE}/opt/kitsu/lib/"
cp -a "${ROOT_DIR}/lib/"*.so "${DEB_STAGE}/opt/kitsu/lib/" 2>/dev/null || true
cp -a "${ROOT_DIR}/lib/skills/"*.lua "${DEB_STAGE}/opt/kitsu/lib/skills/"
cp -a "${ROOT_DIR}/lib/native/"* "${DEB_STAGE}/opt/kitsu/lib/native/" 2>/dev/null || true
cp -a "${ROOT_DIR}/assets/"* "${DEB_STAGE}/opt/kitsu/assets/"
mkdir -p "${DEB_STAGE}/opt/kitsu/themes"
cp -a "${ROOT_DIR}/themes/"* "${DEB_STAGE}/opt/kitsu/themes/" 2>/dev/null || true

# Global symlinks
ln -sf /opt/kitsu/bin/kitsu "${DEB_STAGE}/usr/local/bin/kitsu"
ln -sf /opt/kitsu/bin/kitsu-power "${DEB_STAGE}/usr/local/bin/kitsu-power"
ln -sf /opt/kitsu/bin/kitsu-avatar "${DEB_STAGE}/usr/local/bin/kitsu-avatar"
ln -sf /opt/kitsu/bin/kitsu "${DEB_STAGE}/usr/local/bin/qwen-widget"
ln -sf /opt/kitsu/bin/kitsu-power "${DEB_STAGE}/usr/local/bin/qwen-power"

# Desktop entry
cat > "${DEB_STAGE}/usr/share/applications/kitsu.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Kitsu
GenericName=Desktop AI Companion
Comment=Hybrid Lua + C/C++ Desktop AI Companion with embedded llama.cpp and synced lyrics
Exec=/opt/kitsu/bin/kitsu
Icon=/opt/kitsu/assets/icon.png
Terminal=false
StartupNotify=false
Categories=Utility;Office;AudioVideo;
EOF

cat > "${DEB_STAGE}/DEBIAN/control" <<EOF
Package: kitsu
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: ${ARCH}
Depends: lua-lgi, gir1.2-gtk-3.0, gir1.2-gdkpixbuf-2.0, gir1.2-pango-1.0, libc6, libstdc++6, libx11-6, libxfixes3, libxi6, libglib2.0-0, curl
Maintainer: Kitsu Engineering <dev@kitsu.local>
Description: Kitsu - Hybrid Desktop AI Companion & Media Suite (< 500 MB RAM)
 Instant X11/Wayland text selection grammar corrector, YouTube Music
 and Spotify mini-player with synced lyrics, OpenClaw autonomous agent, and
 embedded llama.cpp inference with automatic GGUF model download on first run.
EOF

cat > "${DEB_STAGE}/DEBIAN/postinst" <<'EOF'
#!/usr/bin/env bash
set -e
chmod -R 755 /opt/kitsu/bin /opt/kitsu/lib
mkdir -p /opt/kitsu/models
chmod 777 /opt/kitsu/models
ln -sf /opt/kitsu /opt/qwen-widget 2>/dev/null || true
ln -sf /opt/kitsu/bin/kitsu /usr/local/bin/kitsu 2>/dev/null || true
ln -sf /opt/kitsu/bin/kitsu-power /usr/local/bin/kitsu-power 2>/dev/null || true
ln -sf /opt/kitsu/bin/kitsu-avatar /usr/local/bin/kitsu-avatar 2>/dev/null || true
ln -sf /opt/kitsu/bin/kitsu /usr/local/bin/qwen-widget 2>/dev/null || true
echo "[kitsu] Installed in /opt/kitsu. Default GGUF models will download automatically on first launch if not present."
exit 0
EOF
chmod 755 "${DEB_STAGE}/DEBIAN/postinst"

DEB_OUT="${DIST_DIR}/kitsu_${VERSION}_${ARCH}.deb"
dpkg-deb --build --root-owner-group "${DEB_STAGE}" "${DEB_OUT}" >/dev/null
# Also keep qwen-widget alias deb for backward compatibility
cp -f "${DEB_OUT}" "${DIST_DIR}/qwen-widget_${VERSION}_${ARCH}.deb"
rm -rf "${DEB_STAGE}"
echo "  -> Created: ${DEB_OUT}"

echo "[3/4] Building Universal Portable Tarball (.tar.gz)..."
TAR_STAGE="$(mktemp -d)"
PORTABLE_DIR="${TAR_STAGE}/kitsu-${VERSION}"
mkdir -p "${PORTABLE_DIR}/bin"
mkdir -p "${PORTABLE_DIR}/lib/native"
mkdir -p "${PORTABLE_DIR}/lib/skills"
mkdir -p "${PORTABLE_DIR}/assets"
mkdir -p "${PORTABLE_DIR}/models"

for b in kitsu kitsu-power kitsu-avatar kitsu-bin qwen-widget qwen-power qwen-avatar qwen-widget-bin llama-server; do
    [ -f "${ROOT_DIR}/bin/${b}" ] && cp -a "${ROOT_DIR}/bin/${b}" "${PORTABLE_DIR}/bin/"
done
[ -n "$LUA_BIN" ] && cp -a "$LUA_BIN" "${PORTABLE_DIR}/bin/lua5.3"
chmod 755 "${PORTABLE_DIR}/bin/"*

cp -a "${ROOT_DIR}/lib/"*.lua "${PORTABLE_DIR}/lib/"
cp -a "${ROOT_DIR}/lib/"*.so "${PORTABLE_DIR}/lib/" 2>/dev/null || true
cp -a "${ROOT_DIR}/lib/skills/"*.lua "${PORTABLE_DIR}/lib/skills/"
cp -a "${ROOT_DIR}/lib/native/"* "${PORTABLE_DIR}/lib/native/" 2>/dev/null || true
cp -a "${ROOT_DIR}/assets/"* "${PORTABLE_DIR}/assets/"
mkdir -p "${PORTABLE_DIR}/themes"
cp -a "${ROOT_DIR}/themes/"* "${PORTABLE_DIR}/themes/" 2>/dev/null || true
cp -a "${ROOT_DIR}/install.sh" "${PORTABLE_DIR}/"
cp -a "${ROOT_DIR}/run.sh" "${PORTABLE_DIR}/"
cp -a "${ROOT_DIR}/README.md" "${PORTABLE_DIR}/"

TAR_OUT="${DIST_DIR}/kitsu-${VERSION}-linux-x86_64.tar.gz"
tar -C "${TAR_STAGE}" -czf "${TAR_OUT}" "kitsu-${VERSION}"
cp -f "${TAR_OUT}" "${DIST_DIR}/qwen-widget-${VERSION}-linux-x86_64.tar.gz"
rm -rf "${TAR_STAGE}"
echo "  -> Created: ${TAR_OUT}"

echo "[4/4] Package build complete:"
ls -lh "${DIST_DIR}"
