#!/bin/bash
# ============================================================
# brave-update.sh  —  Update and rebuild Brave Origin on Void Linux
# Usage: brave-update.sh
# Deps:  curl, jq
# ============================================================
set -euo pipefail
TEMPLATE="/opt/void-packages/srcpkgs/brave/template"
GITHUB_API="https://api.github.com/repos/brave/brave-browser/releases"
SHA_NAME_PATTERN="brave-origin_.*_amd64\.deb\.sha256$"          # ← brave-origin

# ── 1. Fetch latest stable release ──────────────────────────
echo "[*] Querying GitHub API..."
RELEASE_JSON=$(curl -sf -A "Mozilla/5.0 (X11; Linux x86_64; rv:152.0) Gecko/20100101 Firefox/152.0" \
  -H "Accept: application/vnd.github+json" \
  "${GITHUB_API}?per_page=50" \
  | jq '[.[] | select(
        .prerelease == false and
        .draft      == false and
        (.name | test("Nightly|Beta|Dev"; "i") | not)
      )] | first'
)
if [[ -z "$RELEASE_JSON" || "$RELEASE_JSON" == "null" ]]; then
  echo "[!] Failed to fetch stable release." >&2
  exit 1
fi
TAG=$(echo "$RELEASE_JSON" | jq -r '.tag_name')
VERSION="${TAG#v}"
echo "[*] Latest stable version: $VERSION"

# ── 2. Get .deb.sha256 URL ──────────────────────────────────
SHA_URL=$(echo "$RELEASE_JSON" \
  | jq -r --arg pat "$SHA_NAME_PATTERN" \
    '.assets[] | select(.name | test($pat)) | .browser_download_url' \
  | head -1)
if [[ -z "$SHA_URL" ]]; then
  echo "[!] brave-origin .deb.sha256 file not found in release assets." >&2
  echo "    Available assets:"
  echo "$RELEASE_JSON" | jq -r '.assets[].name' | sed 's/^/    - /'
  exit 1
fi
echo "[*] File: $(basename "$SHA_URL")"

# ── 3. Fetch checksum (bytes only, no .deb download) ────────
echo "[*] Fetching checksum..."
SHA_CONTENT=$(curl -A "Mozilla/5.0 (X11; Linux x86_64; rv:152.0) Gecko/20100101 Firefox/152.0" -sfL "$SHA_URL")
if [[ -z "$SHA_CONTENT" ]]; then
  echo "[!] .sha256 file is empty or unreachable: $SHA_URL" >&2
  exit 1
fi
CHECKSUM=$(echo "$SHA_CONTENT" | awk '{print $1}')
if [[ -z "$CHECKSUM" || ${#CHECKSUM} -ne 64 ]]; then
  echo "[!] Invalid checksum (length=${#CHECKSUM}): '$CHECKSUM'" >&2
  echo "    Raw content: $SHA_CONTENT" >&2
  exit 1
fi
echo "[*] SHA256: $CHECKSUM"

# ── 4. Create template if missing ───────────────────────────
mkdir -p "$(dirname "$TEMPLATE")"
if [[ ! -f "$TEMPLATE" ]]; then
  echo "[*] Template not found, creating it..."
  cat > "$TEMPLATE" << EOF
# Template file for 'brave' (brave-origin build)
pkgname=brave
version=${VERSION}
revision=2
only_for_archs="x86_64"
short_desc="Secure, fast and private web browser (Origin build)"
maintainer="drak void <drakvoidlinux@gmail.com>"
hostmakedepends="tar xz"
license="Mozilla Public License Version 2.0"
homepage="https://brave.com"
distfiles="https://github.com/brave/brave-browser/releases/download/v\${version}/brave-origin_\${version}_amd64.deb"
checksum=${CHECKSUM}
nostrip=yes
do_extract() {
	mkdir -p \${DESTDIR}
	ar x \${XBPS_SRCDISTDIR}/\${pkgname}-\${version}/brave-origin_\${version}_amd64.deb
}
do_install() {
	tar xf data.tar.xz -C \${DESTDIR}
	# Install the icons
	for size in 24 32 48 64 128 256; do
		mkdir -p \${DESTDIR}/usr/share/icons/hicolor/\${size}x\${size}/apps
		mv \${DESTDIR}/opt/brave.com/brave-origin/product_logo_\${size}.png \
		\${DESTDIR}/usr/share/icons/hicolor/\${size}x\${size}/apps/brave-browser.png
	done
	# Remove the Debian/Ubuntu crontab
	rm -rf \${DESTDIR}/etc
	rm -rf \${DESTDIR}/opt/brave.com/brave/cron
	rm -rf \${DESTDIR}/usr/share/doc
	rm -rf \${DESTDIR}/usr/lib
}
EOF
  echo "[✓] Template created: $TEMPLATE"
else
  # ── 5. Check if already up to date ────────────────────────
  OLD_VERSION=$(grep -E '^version=' "$TEMPLATE" | cut -d= -f2)
  if [[ "$OLD_VERSION" == "$VERSION" ]]; then
    echo "[=] Already up to date ($VERSION). Nothing to do."
    exit 0
  fi
  echo "[*] Updating: $OLD_VERSION → $VERSION"

  # ── 6. Patch version=, checksum=, et nom du .deb ──────────
  # Le dernier sed migre aussi un ancien template brave-browser → brave-origin
  sed -i.bak \
    -e "s|^version=.*|version=${VERSION}|" \
    -e "s|^checksum=.*|checksum=${CHECKSUM}|" \
    -e "s|brave-browser_\${version}|brave-origin_\${version}|g" \
    "$TEMPLATE"
  echo "[✓] Template updated!"
  echo ""
  echo "── Diff ──────────────────────────────────────────────"
  diff "${TEMPLATE}.bak" "$TEMPLATE" || true
  rm -f "${TEMPLATE}.bak"
  echo "──────────────────────────────────────────────────────"
fi

# ── 7. Build and install ─────────────────────────────────────
echo ""
echo "[*] Building package..."
cd /opt/void-packages && ./xbps-src -A x86_64 -f pkg brave
echo "[*] Installing..."
doas xi -Syuf brave
echo "[✓] Brave Origin $VERSION successfully installed!"
