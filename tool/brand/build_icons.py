#!/usr/bin/env python3
"""Rasterise the Homeroom mark into every master asset the icon pipeline needs.

`flutter_launcher_icons` cuts the per-density ladders from the 1024px masters
this writes; it has no launch-screen support, so the launch images are written
here too. Re-run after changing anything in assets/brand/src/.

Requires: rsvg-convert (brew install librsvg), Pillow.
"""
import json, subprocess, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
# Launcher masters are NOT bundled into the app; only OUT/ ships.
SRC = ROOT / "assets/brand/src"
OUT = ROOT / "assets/brand"
MASTERS = ROOT / "assets/launcher"

CREAM = (255, 254, 234, 255)   # #FFFEEA
BLACK = (0, 0, 0, 255)

# Fraction of the 1024 canvas the glyph's WIDTH occupies.
#   full   - iOS/macOS/Windows/web, where the OS masks the corners itself
#   safe   - Android adaptive & monochrome, which must clear the 66/108dp
#            safe circle even after the launcher crops to a circle
FULL, SAFE = 0.62, 0.46


def render(svg: pathlib.Path, width: int) -> "Image.Image":
    """Rasterise `svg` to `width` px wide, preserving aspect, as RGBA."""
    from PIL import Image
    import io
    png = subprocess.run(
        ["rsvg-convert", "-w", str(width), "-f", "png", str(svg)],
        check=True, capture_output=True).stdout
    return Image.open(io.BytesIO(png)).convert("RGBA")


def square(glyph, canvas: int, frac: float, bg):
    """Centre `glyph` on a `canvas`px square, scaled to `frac` of the width."""
    from PIL import Image
    g = glyph.resize(
        (round(canvas * frac),
         round(canvas * frac * glyph.height / glyph.width)),
        Image.LANCZOS)
    out = Image.new("RGBA", (canvas, canvas), bg)
    out.alpha_composite(g, ((canvas - g.width) // 2, (canvas - g.height) // 2))
    return out


def recolour(img, rgba):
    """Replace RGB with `rgba` everywhere, keeping the glyph's alpha."""
    from PIL import Image
    solid = Image.new("RGBA", img.size, rgba)
    solid.putalpha(img.getchannel("A"))
    return solid


def main():
    try:
        from PIL import Image
    except ImportError:
        sys.exit("Pillow is required: pip install pillow")

    OUT.mkdir(parents=True, exist_ok=True)
    MASTERS.mkdir(parents=True, exist_ok=True)
    black = render(SRC / "mark-black.svg", 2048)
    cream = render(SRC / "mark-cream.svg", 2048)
    white = recolour(black, (255, 255, 255, 255))

    masters = {
        # iOS light, macOS, Windows, web: opaque cream ground, black mark.
        "icon-light-1024.png":      square(black, 1024, FULL, CREAM),
        # iOS 18 dark: transparent — the system paints its own dark ground.
        "icon-dark-1024.png":       square(cream, 1024, FULL, (0, 0, 0, 0)),
        # iOS 18 tinted: already grayscale, so no desaturation pass needed.
        "icon-tinted-1024.png":     square(white, 1024, FULL, BLACK),
        # Android adaptive: foreground rides on a cream background layer.
        "icon-adaptive-fg-1024.png": square(black, 1024, SAFE, (0, 0, 0, 0)),
        # Android 13 themed: the launcher tints this white glyph itself.
        "icon-monochrome-1024.png": square(white, 1024, SAFE, (0, 0, 0, 0)),
    }
    for name, img in masters.items():
        img.save(MASTERS / name)
        print(f"  {name:<30} {img.width}x{img.height}")

    # In-app splash mark, tinted at runtime -> ship black on transparent.
    for suffix, scale in (("", 1), ("@2x", 2), ("@3x", 3)):
        h = 128 * scale
        w = round(h * black.width / black.height)
        d = OUT / (f"{scale}.0x" if scale > 1 else "")
        d.mkdir(exist_ok=True)
        black.resize((w, h), Image.LANCZOS).save(d / "mark.png")
        print(f"  {str((d / 'mark.png').relative_to(OUT)):<30} {w}x{h}")

    # Launch screens. The mark is black on the light ground and cream on the
    # dark one, so every surface needs both appearances or one of them is an
    # invisible mark on its own colour.
    ios = ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
    images = []
    for glyph, appearance in ((black, None), (cream, "dark")):
        for scale in (1, 2, 3):
            h = 128 * scale
            w = round(h * glyph.width / glyph.height)
            stem = "LaunchImage" + ("-dark" if appearance else "")
            name = f"{stem}{'@%dx' % scale if scale > 1 else ''}.png"
            glyph.resize((w, h), Image.LANCZOS).save(ios / name)
            entry = {"idiom": "universal", "filename": name,
                     "scale": f"{scale}x"}
            if appearance:
                entry["appearances"] = [
                    {"appearance": "luminosity", "value": "dark"}]
            images.append(entry)
    (ios / "Contents.json").write_text(json.dumps(
        {"images": images, "info": {"version": 1, "author": "xcode"}},
        indent=2) + "\n")
    print(f"  LaunchImage*.png               6 (light + dark, @1x/2x/3x)")

    # Android: drawable-<density> is the light ground, drawable-night-* the
    # dark one; the resource system picks the appearance for us.
    for glyph, night in ((black, ""), (cream, "night-")):
        for density, px in (("mdpi", 96), ("hdpi", 144), ("xhdpi", 192),
                            ("xxhdpi", 288), ("xxxhdpi", 384)):
            d = ROOT / f"android/app/src/main/res/drawable-{night}{density}"
            d.mkdir(parents=True, exist_ok=True)
            w = round(px * glyph.width / glyph.height)
            glyph.resize((w, px), Image.LANCZOS).save(d / "launch_mark.png")
    print("  drawable[-night]-*/launch_mark.png  10 (5 densities x 2)")


if __name__ == "__main__":
    main()
