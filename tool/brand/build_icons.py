#!/usr/bin/env python3
"""Rasterise the Homeroom brand into every master the icon pipeline needs.

`flutter_launcher_icons` cuts the per-density ladders from the 1024px masters
this writes; it has no launch-screen support, so the launch art is written here
too, and the store graphics alongside it.

Sources live in assets/brand/src/ and are the designer's files:
  app-icon.svg          the finished icon — cream mark on #171717, rounded
  mark-black.svg        the mark alone, black on transparent (H + sparkle)
  mark-cream-nostar.svg the mark WITHOUT the sparkle; not used for icons
  wordmark.svg          the wordmark, cream on black (mark + "Homeroom")

Re-run after changing any of them. Requires rsvg-convert (brew install librsvg)
and Pillow.
"""
import io
import os
import re
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "assets/brand/src"
OUT = ROOT / "assets/brand"          # bundled into the app
MASTERS = ROOT / "assets/launcher"   # consumed by flutter_launcher_icons only
STORE = pathlib.Path(os.path.expanduser("~/Desktop/homeroom/play"))

INK = (23, 23, 23, 255)        # #171717 — the icon ground
CREAM = (255, 254, 244, 255)   # #FFFEF4 — the mark on that ground
WHITE = (255, 255, 255, 255)
BLACK = (0, 0, 0, 255)

# Fraction of the canvas width the mark spans.
#   FULL is measured from app-icon.svg so every variant matches the artwork.
#   SAFE clears Android's 66/108dp circle after the launcher crops.
SAFE = 0.46


def render(svg: pathlib.Path, width: int):
    """Rasterise `svg` to `width` px wide, preserving aspect, as RGBA."""
    from PIL import Image
    png = subprocess.run(
        ["rsvg-convert", "-w", str(width), "-f", "png", str(svg)],
        check=True, capture_output=True).stdout
    return Image.open(io.BytesIO(png)).convert("RGBA")


def recolour(img, rgba):
    """Replace RGB everywhere, keeping the source's alpha."""
    from PIL import Image
    solid = Image.new("RGBA", img.size, rgba)
    solid.putalpha(img.getchannel("A"))
    return solid


def mark_fraction(icon):
    """How wide the mark sits inside the finished icon, as a fraction.

    Taken from the artwork rather than guessed, so the standalone variants
    line up with what the designer drew.
    """
    from PIL import Image
    w, h = icon.size
    # The ground is opaque everywhere inside the rounded rect, so isolate the
    # mark by colour distance from the ground rather than by alpha.
    px = icon.convert("RGB").load()
    xs = [x for y in range(0, h, 4) for x in range(0, w, 4)
          if sum(abs(a - b) for a, b in zip(px[x, y], INK[:3])) > 90]
    return (max(xs) - min(xs)) / w if xs else 0.62


def square(glyph, canvas: int, frac: float, bg):
    """Centre `glyph` on a `canvas`px square at `frac` of its width."""
    from PIL import Image
    g = glyph.resize(
        (round(canvas * frac),
         round(canvas * frac * glyph.height / glyph.width)), Image.LANCZOS)
    out = Image.new("RGBA", (canvas, canvas), bg)
    out.alpha_composite(g, ((canvas - g.width) // 2, (canvas - g.height) // 2))
    return out


def main():
    try:
        from PIL import Image
    except ImportError:
        sys.exit("Pillow is required: pip install pillow")

    OUT.mkdir(parents=True, exist_ok=True)
    MASTERS.mkdir(parents=True, exist_ok=True)

    icon_art = render(SRC / "app-icon.svg", 1024)
    black = render(SRC / "mark-black.svg", 2048)
    cream = recolour(black, CREAM)
    white = recolour(black, WHITE)
    full = mark_fraction(icon_art)
    print(f"  mark spans {full:.1%} of the icon — measured from app-icon.svg\n")

    # The artwork carries iOS-style rounded corners; every platform applies its
    # own mask, so the corners are filled and the masters ship square.
    squared = Image.new("RGBA", icon_art.size, INK)
    squared.alpha_composite(icon_art)

    masters = {
        # iOS light/default, macOS, Windows, web.
        "icon-light-1024.png": squared,
        # iOS 18 dark: transparent, the system paints its own ground.
        "icon-dark-1024.png": square(cream, 1024, full, (0, 0, 0, 0)),
        # iOS 18 tinted: already grayscale, so no desaturation pass.
        "icon-tinted-1024.png": square(white, 1024, full, BLACK),
        # Android adaptive foreground, over an #171717 background layer.
        "icon-adaptive-fg-1024.png": square(cream, 1024, SAFE, (0, 0, 0, 0)),
        # Android 13 themed: the launcher tints this itself.
        "icon-monochrome-1024.png": square(white, 1024, SAFE, (0, 0, 0, 0)),
    }
    for name, img in masters.items():
        img.save(MASTERS / name)
        print(f"  launcher/{name:<28} {img.width}x{img.height}")

    # In-app splash mark: tinted at runtime, so it ships black on transparent.
    for scale in (1, 2, 3):
        h = 128 * scale
        w = round(h * black.width / black.height)
        d = OUT / (f"{scale}.0x" if scale > 1 else "")
        d.mkdir(exist_ok=True)
        black.resize((w, h), Image.LANCZOS).save(d / "mark.png")
    print(f"  brand/mark.png {'':<21} 1x/2x/3x")

    # wordmark.svg paints its own pure-black ground. Drop that rect so the
    # lettering is usable on any ground, then crop to the lettering.
    svg = (SRC / "wordmark.svg").read_text()
    stripped = SRC.parent / ".wordmark-nobg.svg"
    stripped.write_text(
        re.sub(r'<rect[^>]*fill="black"[^>]*/>', "", svg, count=1))
    try:
        word = render(stripped, 4096)
    finally:
        stripped.unlink(missing_ok=True)
    word = word.crop(word.getchannel("A").getbbox())

    # In-app resume splash wordmark: tinted at runtime like mark.png.
    word_black = recolour(word, BLACK)
    for scale in (1, 2, 3):
        h = 64 * scale
        w = round(h * word.width / word.height)
        d = OUT / (f"{scale}.0x" if scale > 1 else "")
        word_black.resize((w, h), Image.LANCZOS).save(d / "wordmark.png")
    print(f"  brand/wordmark.png {'':<17} 1x/2x/3x")

    # Launch screens. Black mark on the light ground, cream on the dark one:
    # a single colour would be invisible in one of the two appearances.
    import json
    ios = ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
    images = []
    for glyph, dark in ((black, False), (cream, True)):
        for scale in (1, 2, 3):
            h = 128 * scale
            w = round(h * glyph.width / glyph.height)
            name = f"LaunchImage{'-dark' if dark else ''}{f'@{scale}x' if scale > 1 else ''}.png"
            glyph.resize((w, h), Image.LANCZOS).save(ios / name)
            entry = {"idiom": "universal", "filename": name, "scale": f"{scale}x"}
            if dark:
                entry["appearances"] = [{"appearance": "luminosity", "value": "dark"}]
            images.append(entry)
    (ios / "Contents.json").write_text(json.dumps(
        {"images": images, "info": {"version": 1, "author": "xcode"}}, indent=2) + "\n")
    print(f"  ios/LaunchImage*.png {'':<15} 6 (light + dark)")

    for glyph, night in ((black, ""), (cream, "night-")):
        for density, px in (("mdpi", 96), ("hdpi", 144), ("xhdpi", 192),
                            ("xxhdpi", 288), ("xxxhdpi", 384)):
            d = ROOT / f"android/app/src/main/res/drawable-{night}{density}"
            d.mkdir(parents=True, exist_ok=True)
            w = round(px * glyph.width / glyph.height)
            glyph.resize((w, px), Image.LANCZOS).save(d / "launch_mark.png")
    print(f"  android/launch_mark.png {'':<12} 10 (5 densities x 2)")

    # Store graphics, written outside the repo — they are uploaded, not built.
    if STORE.is_dir():
        squared.resize((512, 512), Image.LANCZOS).convert("RGB").save(
            STORE / "play-icon-512.png")
        target_w = round(1024 * 0.62)
        word = word.resize(
            (target_w, round(target_w * word.height / word.width)), Image.LANCZOS)
        canvas = Image.new("RGBA", (1024, 500), INK)
        canvas.alpha_composite(
            word, ((1024 - word.width) // 2, (500 - word.height) // 2))
        canvas.convert("RGB").save(STORE / "play-feature-1024x500.png")
        print(f"\n  {STORE}/play-icon-512.png")
        print(f"  {STORE}/play-feature-1024x500.png")


if __name__ == "__main__":
    main()
