#!/bin/bash
# =============================================================================
# ATLAZES OS - Asset Generator
# Generates placeholder branding assets using ImageMagick or Python
# Run this on your build machine to generate PNG assets
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}"

echo "[ATLAZES] Generating branding assets..."

# Check for ImageMagick
if command -v convert &>/dev/null; then
    USE_IMAGEMAGICK=true
else
    USE_IMAGEMAGICK=false
    echo "[!] ImageMagick not found. Install with: sudo apt install imagemagick"
    echo "[!] Generating SVG files only."
fi

# ─── Logo SVG ─────────────────────────────────────────────────────────────────
cat > "${OUTPUT_DIR}/logo.svg" << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
  <defs>
    <linearGradient id="grad1" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#1f6feb;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#388bfd;stop-opacity:1" />
    </linearGradient>
  </defs>
  <!-- Background circle -->
  <circle cx="256" cy="256" r="240" fill="#0d1117" stroke="url(#grad1)" stroke-width="8"/>
  <!-- Shield shape -->
  <path d="M256 80 L380 140 L380 260 Q380 360 256 430 Q132 360 132 260 L132 140 Z"
        fill="none" stroke="url(#grad1)" stroke-width="12" stroke-linejoin="round"/>
  <!-- A letter -->
  <text x="256" y="310" font-family="monospace" font-size="160" font-weight="bold"
        fill="url(#grad1)" text-anchor="middle">A</text>
  <!-- Bottom text -->
  <text x="256" y="480" font-family="monospace" font-size="28" font-weight="bold"
        fill="#58a6ff" text-anchor="middle" letter-spacing="4">ATLAZES</text>
</svg>
EOF

echo "[+] logo.svg created"

# ─── Wallpaper SVG (1920x1080) ────────────────────────────────────────────────
cat > "${OUTPUT_DIR}/wallpaper-1920x1080.svg" << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#0d1117" />
      <stop offset="100%" style="stop-color:#161b22" />
    </linearGradient>
    <linearGradient id="accent" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" style="stop-color:#1f6feb" />
      <stop offset="100%" style="stop-color:#388bfd" />
    </linearGradient>
  </defs>
  <rect width="1920" height="1080" fill="url(#bg)"/>

  <!-- Subtle grid -->
  <g stroke="#1f6feb" stroke-width="0.3" opacity="0.08">
    <line x1="0" y1="108" x2="1920" y2="108"/>
    <line x1="0" y1="216" x2="1920" y2="216"/>
    <line x1="0" y1="324" x2="1920" y2="324"/>
    <line x1="0" y1="432" x2="1920" y2="432"/>
    <line x1="0" y1="540" x2="1920" y2="540"/>
    <line x1="0" y1="648" x2="1920" y2="648"/>
    <line x1="0" y1="756" x2="1920" y2="756"/>
    <line x1="0" y1="864" x2="1920" y2="864"/>
    <line x1="0" y1="972" x2="1920" y2="972"/>
    <line x1="192" y1="0" x2="192" y2="1080"/>
    <line x1="384" y1="0" x2="384" y2="1080"/>
    <line x1="576" y1="0" x2="576" y2="1080"/>
    <line x1="768" y1="0" x2="768" y2="1080"/>
    <line x1="960" y1="0" x2="960" y2="1080"/>
    <line x1="1152" y1="0" x2="1152" y2="1080"/>
    <line x1="1344" y1="0" x2="1344" y2="1080"/>
    <line x1="1536" y1="0" x2="1536" y2="1080"/>
    <line x1="1728" y1="0" x2="1728" y2="1080"/>
  </g>

  <!-- Glow effect -->
  <circle cx="960" cy="540" r="300" fill="#1f6feb" opacity="0.03"/>
  <circle cx="960" cy="540" r="200" fill="#1f6feb" opacity="0.04"/>

  <!-- Logo shield outline -->
  <path d="M960 340 L1060 390 L1060 490 Q1060 560 960 600 Q860 560 860 490 L860 390 Z"
        fill="none" stroke="url(#accent)" stroke-width="3" opacity="0.6"/>

  <!-- Main title -->
  <text x="960" y="510" font-family="monospace" font-size="64" font-weight="bold"
        fill="url(#accent)" text-anchor="middle" letter-spacing="10">ATLAZES OS</text>

  <!-- Subtitle -->
  <text x="960" y="565" font-family="monospace" font-size="18"
        fill="#58a6ff" text-anchor="middle" letter-spacing="8" opacity="0.7">
    SECURE · PRIVATE · PROFESSIONAL
  </text>

  <!-- Version -->
  <text x="960" y="600" font-family="monospace" font-size="13"
        fill="#8b949e" text-anchor="middle" letter-spacing="4" opacity="0.5">
    VERSION 1.0 HORIZON
  </text>

  <!-- Accent line -->
  <rect x="810" y="625" width="300" height="1" fill="url(#accent)" opacity="0.4"/>

  <!-- Corner decorations -->
  <g stroke="#1f6feb" stroke-width="2" fill="none" opacity="0.3">
    <path d="M40 40 L40 80 L80 80"/>
    <path d="M1880 40 L1880 80 L1840 80"/>
    <path d="M40 1040 L40 1000 L80 1000"/>
    <path d="M1880 1040 L1880 1000 L1840 1000"/>
  </g>
</svg>
EOF

echo "[+] wallpaper-1920x1080.svg created"

# ─── Convert SVG to PNG if ImageMagick available ──────────────────────────────
if $USE_IMAGEMAGICK; then
    convert -background none "${OUTPUT_DIR}/logo.svg" \
            -resize 512x512 "${OUTPUT_DIR}/logo.png"
    echo "[+] logo.png created (512x512)"

    convert "${OUTPUT_DIR}/wallpaper-1920x1080.svg" \
            "${OUTPUT_DIR}/wallpaper-1920x1080.png"
    echo "[+] wallpaper-1920x1080.png created"

    # Create additional sizes
    convert -background none "${OUTPUT_DIR}/logo.svg" \
            -resize 256x256 "${OUTPUT_DIR}/logo-256.png"
    convert -background none "${OUTPUT_DIR}/logo.svg" \
            -resize 128x128 "${OUTPUT_DIR}/logo-128.png"
    convert -background none "${OUTPUT_DIR}/logo.svg" \
            -resize 64x64 "${OUTPUT_DIR}/logo-64.png"
    convert -background none "${OUTPUT_DIR}/logo.svg" \
            -resize 48x48 "${OUTPUT_DIR}/logo-48.png"
    echo "[+] Logo variants created"

    # Login wallpaper (darker)
    convert "${OUTPUT_DIR}/wallpaper-1920x1080.png" \
            -modulate 70 "${OUTPUT_DIR}/wallpaper-login.png"
    echo "[+] wallpaper-login.png created"
fi

echo ""
echo "[ATLAZES] Asset generation complete."
echo "Files created in: ${OUTPUT_DIR}"
echo ""
echo "To use in the build, copy PNG files to:"
echo "  assets/ (primary source for build.sh)"
echo "  calamares/branding/atlazes/ (installer branding generated during build)"
