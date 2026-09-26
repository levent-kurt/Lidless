#!/usr/bin/env python3
"""
Builds Lidless's AppIcon.appiconset and menu bar icon from the canonical
source artwork at Resources/AppIconSource.png (a black glyph on a
transparent background).

Requires Pillow: pip install pillow

Usage:
    python3 scripts/generate_app_icon.py
"""

import os

from PIL import Image

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE_PATH = os.path.join(ROOT_DIR, "Resources", "AppIconSource.png")
APPICON_DIR = os.path.join(ROOT_DIR, "Resources", "Assets.xcassets", "AppIcon.appiconset")
MENUBAR_DIR = os.path.join(ROOT_DIR, "Resources", "Assets.xcassets", "MenuBarIcon.imageset")

# (filename, pixel size) pairs matching AppIcon.appiconset/Contents.json exactly.
APPICON_SIZES = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

# Status bar glyphs are small; NSStatusItem draws them at ~18-22pt.
MENUBAR_SIZES = [
    ("menubar_icon.png", 44),
    ("menubar_icon@2x.png", 88),
    ("menubar_icon@3x.png", 132),
]


def main():
    master = Image.open(SOURCE_PATH).convert("RGBA")

    os.makedirs(APPICON_DIR, exist_ok=True)
    for filename, size in APPICON_SIZES:
        resized = master.resize((size, size), Image.LANCZOS)
        resized.save(os.path.join(APPICON_DIR, filename))
        print(f"wrote {os.path.join('AppIcon.appiconset', filename)} ({size}x{size})")

    os.makedirs(MENUBAR_DIR, exist_ok=True)
    for filename, size in MENUBAR_SIZES:
        resized = master.resize((size, size), Image.LANCZOS)
        resized.save(os.path.join(MENUBAR_DIR, filename))
        print(f"wrote {os.path.join('MenuBarIcon.imageset', filename)} ({size}x{size})")


if __name__ == "__main__":
    main()
