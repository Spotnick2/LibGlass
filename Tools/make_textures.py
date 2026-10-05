"""Generate the glass material textures into Media/ as uncompressed 32-bit TGA.

    python Tools/make_textures.py

The generator is the source of truth; the .tga files are committed outputs.
It writes exactly the 23 textures LibGlass.lua names (tests/test_media.lua
checks Media/ against the code): the 15 of r1 and the 8 disc textures of r2.
Lifted from GlassUnitFrames @ 09b6f0d,
without the probe's earlier iterations (rim..rim4, sheen, late), which stay
with GlassProbe. Never rename an output: frames built earlier keep the path.

Conventions, all chosen to avoid edge halos and to keep colour a runtime decision:
- Overlay textures (rim, gloss, sheen, grain, shadow) are a single RGB colour
  everywhere, with the shape carried only in alpha. Colour comes from
  SetVertexColor / SetStatusBarColor at runtime.
- Mask textures are white-on-black in RGB *and* alpha, so they work whichever
  channel the client samples (loaded with CLAMPTOBLACKADDITIVE wrap).
- Rounded-rect textures are designed for 9-slicing: the corner radius sits
  inside the slice margin, noted per texture below and mirrored in the Lua.
- Disc textures (circle_sdf) are never sliced: they stretch with the host.
- Power-of-two sizes, bottom-left origin (the most common TGA layout).
"""

import os
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Media")


def write_tga(name, rgba):
    """rgba: float array (h, w, 4) in 0..1, row 0 = top."""
    h, w, _ = rgba.shape
    assert w & (w - 1) == 0 and h & (h - 1) == 0, f"{name}: not power of two"
    px = (np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8)
    bgra = px[::-1, :, [2, 1, 0, 3]]            # flip to bottom-left origin, RGBA -> BGRA
    header = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    w & 255, w >> 8, h & 255, h >> 8, 32, 0x08])
    with open(os.path.join(OUT, name + ".tga"), "wb") as f:
        f.write(header)
        f.write(bgra.tobytes())
    print(f"  {name}.tga  {w}x{h}")


def rounded_rect_sdf(w, h, inset, radius):
    """Signed distance (px) to a rounded rect inset from the texture edge; negative inside."""
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64) + 0.5
    cx, cy = w / 2.0, h / 2.0
    hx, hy = w / 2.0 - inset, h / 2.0 - inset
    qx = np.abs(xs - cx) - (hx - radius)
    qy = np.abs(ys - cy) - (hy - radius)
    outside = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0))
    inside = np.minimum(np.maximum(qx, qy), 0)
    return outside + inside - radius


def coverage(d, soft=0.75):
    """Antialiased fill from a signed distance: 1 inside, 0 outside."""
    return np.clip(0.5 - d / (2 * soft), 0, 1)


def band(d, lo, hi, soft=0.75):
    """Antialiased band where lo <= d <= hi (d negative inside)."""
    return coverage(d - hi, soft) * (1 - coverage(d - lo, soft))


def white(alpha):
    h, w = alpha.shape
    out = np.ones((h, w, 4))
    out[..., 3] = alpha
    return out


def black(alpha):
    out = white(alpha)
    out[..., :3] = 0
    return out


def mask(alpha):
    out = np.zeros(alpha.shape + (4,))
    out[..., 0] = out[..., 1] = out[..., 2] = out[..., 3] = alpha
    return out


def normals(d):
    gy, gx = np.gradient(d)
    n = np.hypot(gx, gy) + 1e-9
    return gx / n, gy / n


def circle_sdf(size, inset, radius=None, dy=0.0):
    """Signed distance (px) to a circle centred in a size x size texture; negative inside.

    The circle touches the texture inset by `inset`, unless `radius` is given.
    `dy` moves its centre down (a drop shadow's offset).
    """
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float64) + 0.5
    c = size / 2.0
    r = (c - inset) if radius is None else radius
    return np.hypot(xs - c, ys - (c + dy)) - r


def glass_rim(size, radius, k, light=1.0):
    """The style-4 glass rim and its dark companion, at any size.

    k scales every distance (bevel width, lips, glints) from the 64px design,
    so a 32px, radius-7 texture with k=0.5 is the same material, smaller.
    light scales every highlight (not the dark companion).
    Returns (rim, dark) as RGBA float arrays.
    """
    d = rounded_rect_sdf(size, size, 0.5, radius)
    c = 6.5 * k                                   # glint centre: on the top corner arcs, near the outer lip
    return glass_lighting(d, ((c, c), (size - c, c)), k, light)


def disc_rim(size, k, light=1.0):
    """The same rim material on a circle filling the texture (never sliced).

    Light from the top, as on the rect rim: the outer lip is brightest at 12
    o'clock, the inner catch-light at 6. The glints sit where the rect rim's
    sit, on the arc 45 degrees either side of the top (10:30 and 1:30), just
    inside the outer edge. Returns (rim, dark).
    """
    d = circle_sdf(size, 0.5)
    c = size / 2.0
    r = (c - 0.5) - 0.15 * k                      # the rect glints' depth below the edge
    s = r * np.sqrt(0.5)
    return glass_lighting(d, ((c - s, c - s), (c + s, c - s)), k, light)


def disc_shadow(size, outset, sigma, drop, alpha):
    """A soft drop shadow for a disc whose texture is outset on every side by
    `outset` times the disc's diameter (SIZES.shadowOutset in the Lua): the
    disc is centred, `drop` px lower, with a logistic falloff, and faded to 0
    before the texture's edge so no hard circle or square shows."""
    r = size / 2.0 / (1 + 2 * outset)
    d = circle_sdf(size, 0, radius=r, dy=drop)
    shadow = alpha / (1 + np.exp(d / (sigma * 0.55)))
    edge = -circle_sdf(size, 0)                   # distance in from the inscribed circle
    return black(shadow * np.clip(edge / sigma, 0, 1))


def glass_lighting(d, glints, k, light):
    """The rim's four alpha layers and its dark companion, from any shape's SDF
    `d` (square texture) and the centres of its two glints."""
    size = d.shape[0]
    nx, ny = normals(d)
    top, bottom, left = np.maximum(-ny, 0), np.maximum(ny, 0), np.maximum(-nx, 0)
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float64) + 0.5
    outer = band(d, -1.4 * k, -0.3 * k, 0.5) * (0.28 + 0.72 * top ** 0.5 + 0.35 * left ** 1.5 + 0.30 * bottom ** 2)
    inner = band(d, -7.6 * k, -6.6 * k, 0.5) * (0.14 + 0.45 * bottom ** 0.7 + 0.18 * top ** 2)
    vert = 1 - ys / size                          # 1 at the top, 0 at the bottom
    slab = band(d, -7.0 * k, -0.5 * k, 0.6) * (0.05 + 0.13 * vert ** 1.5 + 0.06 * top)
    glint = np.zeros_like(d)
    for gx, gy in glints:
        glint += np.exp(-(((xs - gx) ** 2 + (ys - gy) ** 2) / (2 * (2.2 * k) ** 2))) * 0.85
    glint *= band(d, -3.5 * k, -0.2 * k, 0.6)
    rim = white(np.clip(np.maximum.reduce([outer, inner, slab, glint]) * light, 0, 1))
    dark = black(np.clip(band(d, -0.6 * k, 0.3 * k, 0.5) * 0.45 + band(d, -8.8 * k, -7.6 * k, 0.6) * 0.18, 0, 1))
    return rim, dark


def main():
    os.makedirs(OUT, exist_ok=True)
    print("Writing", OUT)

    # Body mask: 64x64, radius 14, slice margins 16.
    d = rounded_rect_sdf(64, 64, 0.5, 14)
    write_tga("body_mask", mask(coverage(d)))

    # Bar mask: 32x32, radius 5, slice margins 8.
    d = rounded_rect_sdf(32, 32, 0.5, 5)
    write_tga("bar_mask", mask(coverage(d)))

    # Thin edge for the bars: 32x32, radius 5, slice margins 8, lit from the top-left.
    lx, ly = -0.70710678, -0.70710678           # light from top-left (y grows downward)
    d = rounded_rect_sdf(32, 32, 0.5, 5)
    nx, ny = normals(d)
    facing = nx * lx + ny * ly
    edge = band(d, -1.2, 0.0) * (0.25 + 0.45 * np.maximum(facing, 0))
    write_tga("bar_edge", white(edge))

    # Drop shadow: 128x128, rect inset 32 with radius 14, blurred; slice margins 48.
    d = rounded_rect_sdf(128, 128, 32, 14)
    sigma = 9.0
    shadow = 1 / (1 + np.exp(d / (sigma * 0.55)))    # logistic falloff ~ gaussian-blurred edge
    write_tga("shadow", black(shadow * 0.55))

    # Gloss: 64x64, bright at the top, gone by ~55% height, plus a soft lip.
    ys = (np.arange(64) + 0.5) / 64.0
    g = np.clip(1 - ys / 0.55, 0, 1) ** 1.8 * 0.85
    lip = np.exp(-((ys - 0.08) / 0.05) ** 2) * 0.35
    col = np.maximum(g, lip)
    write_tga("gloss", white(np.tile(col[:, None], (1, 64))))

    # Bar fill: 64x16 grayscale ramp (alpha 1), lighter at the top. Colour comes
    # from SetStatusBarColor, which multiplies RGB.
    ys = (np.arange(16) + 0.5) / 16.0
    ramp = 1.0 - 0.22 * ys
    fill = np.ones((16, 64, 4))
    fill[..., 0] = fill[..., 1] = fill[..., 2] = np.tile(ramp[:, None], (1, 64))
    write_tga("bar_fill", fill)

    # Track fade: 256x8 horizontal alpha ramp for a bar's missing part, as in
    # the mockup: full for the first 30% of the bar, easing (smoothstep) to
    # clear at 85%, clear after. Colour comes from SetVertexColor.
    xs = (np.arange(256) + 0.5) / 256.0
    t = np.clip((xs - 0.3) / 0.55, 0, 1)
    ramp = 1 - (3 * t ** 2 - 2 * t ** 3)
    write_tga("track_fade", white(np.tile(ramp[None, :], (8, 1))))

    # Grain: 128x128 tileable noise, white with tiny alpha.
    rng = np.random.default_rng(1601)
    noise = rng.random((128, 128))
    write_tga("grain", white((noise ** 3) * 0.10))

    # Small body mask and shadow, for frames too short for 16px slice margins
    # (cast pill, pet, target-of-target): 32x32, radius 7, slice margins 8.
    write_tga("body_mask_small", mask(coverage(rounded_rect_sdf(32, 32, 0.5, 7))))
    d = rounded_rect_sdf(64, 64, 16, 7)
    write_tga("shadow_small", black(0.50 / (1 + np.exp(d / (5.0 * 0.55)))))

    # Style 5 = style 4 after an outside design review (2026-09-27): "thick and
    # bright enough to look like a clear plastic case". Same material, bevel at
    # 0.72x width and highlights at 0.8x. The glass content inset follows the
    # bevel: 6px on large frames, 3px on small (SIZES in LibGlass.lua).
    for name, size, radius, k in (("rim5", 64, 14, 0.72), ("rim5_small", 32, 7, 0.36)):
        rim, dark = glass_rim(size, radius, k, light=0.8)
        write_tga(name, rim)
        write_tga(name.replace("rim5", "rim_dark5"), dark)

    # Softer, narrower sheen that does not wash out text.
    ys, xs = np.mgrid[0:64, 0:256].astype(np.float64) + 0.5
    t = (xs - 128) + (ys - 32) * 0.6
    streak = np.exp(-(t / 16.0) ** 2) * 0.32 + np.exp(-((t - 22) / 4.0) ** 2) * 0.22
    write_tga("sheen2", white(streak * np.exp(-((ys - 32) / 40.0) ** 2)))

    # Discs (r2, Glass.Disc): the same material on a circle, never sliced, so
    # each texture stretches with its square host. 256px for hosts from ~96px
    # up, 64px below. k is chosen so the bevel reads like the rect rims' at
    # typical sizes: ~5.6 texture px (7 px at a 320px host), ~3.5 texture px
    # on the small one (2.2 px at 40, 3.5 at 64). The shadow's texture covers
    # the host plus 0.125 of its size on every side (SIZES.shadowOutset).
    for suffix, size, k, sigma, drop in (("", 256, 0.8, 7.0, 3.0), ("_small", 64, 0.5, 2.5, 1.0)):
        write_tga("disc_mask" + suffix, mask(coverage(circle_sdf(size, 0.5))))
        rim, dark = disc_rim(size, k, light=0.8)
        write_tga("disc_rim" + suffix, rim)
        write_tga("disc_rim_dark" + suffix, dark)
        write_tga("disc_shadow" + suffix, disc_shadow(size, 0.125, sigma, drop, 0.55 if size == 256 else 0.50))


if __name__ == "__main__":
    main()
