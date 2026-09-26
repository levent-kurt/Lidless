#!/usr/bin/env python3
"""
Generates Lidless's AppIcon.appiconset PNGs: a minimalist, side-view,
half-open MacBook silhouette on a dark graphite squircle background.

Requires Pillow: pip install pillow

Usage:
    python3 scripts/generate_app_icon.py
"""

import math
import os

from PIL import Image, ImageDraw, ImageFilter

CANVAS = 1024
OUTPUT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "Resources", "Assets.xcassets", "AppIcon.appiconset",
)

# (filename, pixel size) pairs matching Contents.json exactly.
ICON_SIZES = [
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


def vertical_gradient(size, top_color, bottom_color):
    gradient = Image.new("RGBA", (1, size), color=0)
    for y in range(size):
        t = y / max(size - 1, 1)
        r = round(top_color[0] + (bottom_color[0] - top_color[0]) * t)
        g = round(top_color[1] + (bottom_color[1] - top_color[1]) * t)
        b = round(top_color[2] + (bottom_color[2] - top_color[2]) * t)
        gradient.putpixel((0, y), (r, g, b, 255))
    return gradient.resize((size, size))


def squircle_mask(size, corner_ratio=0.225):
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    radius = round(size * corner_ratio)
    draw.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return mask


def rounded_rect_layer(size, box, radius, fill):
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.rounded_rectangle(box, radius=radius, fill=fill)
    return layer


def inset_quad(points, ratio):
    cx = sum(p[0] for p in points) / len(points)
    cy = sum(p[1] for p in points) / len(points)
    return [(cx + (x - cx) * ratio, cy + (y - cy) * ratio) for x, y in points]


def build_icon():
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))

    # --- Background: dark graphite squircle, matching macOS's own
    # grayscale system-utility icons (Terminal, System Settings, etc). ---
    background = vertical_gradient(CANVAS, (58, 63, 71, 255), (16, 17, 20, 255)).convert("RGBA")
    mask = squircle_mask(CANVAS)
    canvas.paste(background, (0, 0), mask)

    # Subtle top sheen for depth.
    sheen = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    sheen_draw = ImageDraw.Draw(sheen)
    sheen_draw.ellipse(
        [CANVAS * 0.05, -CANVAS * 0.35, CANVAS * 0.95, CANVAS * 0.55],
        fill=(255, 255, 255, 18),
    )
    sheen.putalpha(Image.composite(sheen.split()[3], Image.new("L", (CANVAS, CANVAS), 0), mask))
    canvas = Image.alpha_composite(canvas, sheen)

    # --- Laptop geometry, computed relative to the hinge at the origin,
    # then re-centered on the canvas — see below. ---
    base_half_width = round(CANVAS * 0.235)
    base_height = round(CANVAS * 0.033)
    screen_length = round(CANVAS * 0.375)
    lean_degrees = 28  # from vertical: 0 = fully open, 90 = closed flat.

    lean_radians = math.radians(lean_degrees)
    offset_x = screen_length * math.sin(lean_radians)
    offset_y = -screen_length * math.cos(lean_radians)

    local_bottom_left = (-base_half_width, 0)
    local_bottom_right = (base_half_width, 0)
    local_top_left = (local_bottom_left[0] + offset_x, local_bottom_left[1] + offset_y)
    local_top_right = (local_bottom_right[0] + offset_x, local_bottom_right[1] + offset_y)

    min_x = min(local_bottom_left[0], local_top_left[0], local_top_right[0], local_bottom_right[0])
    max_x = max(local_bottom_left[0], local_top_left[0], local_top_right[0], local_bottom_right[0])
    min_y = min(local_top_left[1], local_top_right[1], 0)
    max_y = base_height

    hinge_x = round(CANVAS * 0.5 - (min_x + max_x) / 2)
    hinge_y = round(CANVAS * 0.52 - (min_y + max_y) / 2)

    def to_canvas(point):
        return (point[0] + hinge_x, point[1] + hinge_y)

    bottom_left = to_canvas(local_bottom_left)
    bottom_right = to_canvas(local_bottom_right)
    top_left = to_canvas(local_top_left)
    top_right = to_canvas(local_top_right)

    shadow = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.ellipse(
        [
            hinge_x - base_half_width * 1.05, hinge_y + base_height * 1.4,
            hinge_x + base_half_width * 1.05, hinge_y + base_height * 4.2,
        ],
        fill=(0, 0, 0, 90),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=CANVAS * 0.018))
    canvas = Image.alpha_composite(canvas, shadow)

    # --- Screen: a parallelogram whose bottom edge is flush with the base's
    # back edge (the hinge line), sheared upward at a "half open" angle —
    # clearly open, clearly not fully upright, and physically attached to
    # the base along a full edge rather than swinging from a single point.
    # Only the two free top corners are rounded; the hinge-side corners sit
    # under the base bar drawn afterward. ---
    bezel = round(CANVAS * 0.024)
    top_corner_radius = round(CANVAS * 0.030)

    outer_quad = [bottom_left, top_left, top_right, bottom_right]

    screen_layer = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    screen_draw = ImageDraw.Draw(screen_layer)

    # Aluminum bezel.
    screen_draw.polygon(outer_quad, fill=(203, 208, 214, 255))
    for corner in (top_left, top_right):
        screen_draw.ellipse(
            [corner[0] - top_corner_radius, corner[1] - top_corner_radius,
             corner[0] + top_corner_radius, corner[1] + top_corner_radius],
            fill=(203, 208, 214, 255),
        )

    # Blacked-out display (the "Lidless" blackout screen), inset from bezel.
    inner_quad = inset_quad(outer_quad, 1 - (bezel / (screen_length / 2)))
    screen_draw.polygon(inner_quad, fill=(6, 7, 9, 255))

    # Camera dot, nudged in from the top edge midpoint toward the display center.
    centroid = (
        sum(p[0] for p in outer_quad) / 4,
        sum(p[1] for p in outer_quad) / 4,
    )
    top_mid = ((top_left[0] + top_right[0]) / 2, (top_left[1] + top_right[1]) / 2)
    dot_center = (
        top_mid[0] + (centroid[0] - top_mid[0]) * 0.16,
        top_mid[1] + (centroid[1] - top_mid[1]) * 0.16,
    )
    dot_radius = round(CANVAS * 0.007)
    screen_draw.ellipse(
        [
            dot_center[0] - dot_radius, dot_center[1] - dot_radius,
            dot_center[0] + dot_radius, dot_center[1] + dot_radius,
        ],
        fill=(90, 95, 102, 255),
    )

    canvas = Image.alpha_composite(canvas, screen_layer)

    # --- Base / keyboard deck, viewed edge-on, lying flat. Drawn last so
    # it cleanly covers the screen's bottom edge at the hinge. ---
    base_layer = rounded_rect_layer(
        CANVAS,
        [
            hinge_x - base_half_width, hinge_y,
            hinge_x + base_half_width, hinge_y + base_height,
        ],
        radius=round(base_height * 0.5),
        fill=(223, 227, 232, 255),
    )
    canvas = Image.alpha_composite(canvas, base_layer)

    # Front lip highlight on the base for a touch of dimensionality.
    lip = rounded_rect_layer(
        CANVAS,
        [
            hinge_x - base_half_width * 0.7, hinge_y + base_height * 0.55,
            hinge_x + base_half_width * 0.7, hinge_y + base_height * 0.85,
        ],
        radius=round(base_height * 0.2),
        fill=(150, 155, 162, 255),
    )
    canvas = Image.alpha_composite(canvas, lip)

    return canvas


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    master = build_icon()

    for filename, size in ICON_SIZES:
        resized = master.resize((size, size), Image.LANCZOS)
        resized.save(os.path.join(OUTPUT_DIR, filename))
        print(f"wrote {filename} ({size}x{size})")


if __name__ == "__main__":
    main()
