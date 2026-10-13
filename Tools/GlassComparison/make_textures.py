"""Generate ONLY the probe's outer shadows; standard library, no dependencies.

Run from any directory. The library's Media/ and generator are untouched.
The interior is transparent; a soft exterior ring fades to zero at the bounds.
Margins include the padding plus the full rounded corner, so slicing preserves
the boundary at the host edge. No vertical offset: that would shift the cutout.
"""

import math
from pathlib import Path
import struct


def smoothstep(value):
    value = max(0.0, min(1.0, value))
    return value * value * (3.0 - 2.0 * value)


def generate(size, pad, radius, spread):
    pixels = bytearray()
    for y in reversed(range(size)):  # uncompressed BGRA, bottom-left origin
        for x in range(size):
            qx = abs(x + 0.5 - size / 2) - (size / 2 - pad - radius)
            qy = abs(y + 0.5 - size / 2) - (size / 2 - pad - radius)
            distance = math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - radius
            exterior = max(0.0, distance)
            boundary = min(x + 0.5, y + 0.5, size - x - 0.5, size - y - 0.5)
            alpha = (0.34 * math.exp(-exterior / spread)
                     * smoothstep(exterior / 1.25) * smoothstep((boundary - 0.5) / 3))
            pixels.extend((0, 0, 0, int(alpha * 255 + 0.5)))
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 8)
    return header + pixels


if __name__ == "__main__":
    output = Path(__file__).resolve().parent / "Media"
    output.mkdir(exist_ok=True)
    for name, size, pad, radius, spread in (
        ("outer_shadow", 128, 16, 14, 5),
        ("outer_shadow_small", 64, 8, 7, 2.5),
    ):
        path = output / (name + ".tga")
        path.write_bytes(generate(size, pad, radius, spread))
        print(path)
