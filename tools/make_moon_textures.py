#!/usr/bin/env python3
"""Build the Moon's colour and normal maps from NASA's own published data.

`scenes/moon.tscn` used to be textured from a 512x256 colour map with a normal map generated out
of that same colour image by a browser tool, then saved as a 256 colour palette PNG. A normal map
stores surface directions rather than colours, so quantising one to a palette is a much worse loss
than it sounds, and 512x256 across the whole sphere put roughly 21 km of Moon in every texel. It
looked exactly as bad as that suggests.

Both maps are rebuilt here from NASA's Scientific Visualization Studio CGI Moon Kit
(<https://svs.gsfc.nasa.gov/4720/>), which is public domain:

  lroc_color_poles_4k.tif   4096x2048   the LROC WAC colour mosaic, used as the albedo directly
  ldem_16_uint.tif          5760x2880   LOLA elevation, 16 bit unsigned, half metre units

The normal map comes from the *elevation*, not from the colour image. That is the real difference:
a colour derived normal map invents relief wherever the surface merely changes brightness, so mare
basalt reads as a dent and ray systems read as ridges, while real craters barely register. Slopes
here are the ones LOLA measured.

    python3 tools/make_moon_textures.py                  # downloads to a cache and writes both maps
    python3 tools/make_moon_textures.py --cache /tmp/x   # keep the 46 MB of source elsewhere

The two source TIFFs are not committed: they are 46 MB of intermediate that this script can fetch
again, and only what the game loads belongs in the repository.
"""

import argparse
import math
import sys
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image

Image.MAX_IMAGE_PIXELS = None

ROOT = Path(__file__).resolve().parent.parent
DESTINATION = ROOT / "assets" / "nasa"

SVS = "https://svs.gsfc.nasa.gov/vis/a000000/a004700/a004720"
COLOUR_SOURCE = "lroc_color_poles_4k.tif"
ELEVATION_SOURCE = "ldem_16_uint.tif"

COLOUR_OUTPUT = "lroc_color_poles_4k.png"
NORMAL_OUTPUT = "ldem_normal_4k.png"

# The map is equirectangular over the whole Moon, so one texel spans the same ground distance in
# both directions: the circumference over the width, and half of it over the height.
MOON_RADIUS_M = 1_737_400.0
# ldem_*_uint.tif stores elevation in half metres above a reference radius. Only the gradient is
# used, so the reference cancels and just the unit matters.
ELEVATION_UNIT_M = 0.5


def fetch(name: str, cache: Path) -> Path:
    """Download one SVS file into the cache, or reuse what is already there."""
    path = cache / name
    if path.exists():
        print(f"  {name}: already cached ({path.stat().st_size // 1024 // 1024} MB)")
        return path
    cache.mkdir(parents=True, exist_ok=True)
    print(f"  {name}: downloading")
    urllib.request.urlretrieve(f"{SVS}/{name}", path)
    print(f"  {name}: {path.stat().st_size // 1024 // 1024} MB")
    return path


def normal_map_from_elevation(elevation: Path, width: int, height: int) -> Image.Image:
    """Turn an equirectangular elevation map into a tangent space normal map at width x height.

    The gradient is taken with the map wrapped east to west, because the Moon has no seam there
    and a clamped edge would draw a meridian-long ridge down the far side.
    """
    source = Image.open(elevation)
    if source.size != (width, height):
        # Resampling the elevation is not a loss of fidelity in the sense that matters here: the
        # output normal map is width x height either way, and LANCZOS over a 5760 px source keeps
        # more real slope than sampling a smaller DEM would.
        source = source.resize((width, height), Image.LANCZOS)

    metres = np.asarray(source, dtype=np.float32) * ELEVATION_UNIT_M

    texel_m: float = 2.0 * math.pi * MOON_RADIUS_M / width
    # Central differences: east minus west, and south minus north.
    d_east = (np.roll(metres, -1, axis=1) - np.roll(metres, 1, axis=1)) / (2.0 * texel_m)
    d_south = (np.roll(metres, -1, axis=0) - np.roll(metres, 1, axis=0)) / (2.0 * texel_m)
    # The poles have no row beyond them to difference against, so the wrap there is meaningless.
    d_south[0, :] = 0.0
    d_south[-1, :] = 0.0

    # Tangent space, OpenGL convention: +X east, +Y up the texture, +Z out of the surface. Godot
    # reads green as up, so the southward slope is negated to face north.
    x = -d_east
    y = d_south
    z = np.ones_like(x)
    length = np.sqrt(x * x + y * y + z * z)

    rgb = np.empty((height, width, 3), dtype=np.uint8)
    for channel, component in enumerate((x, y, z)):
        rgb[:, :, channel] = np.clip(np.rint((component / length * 0.5 + 0.5) * 255.0), 0, 255)
    return Image.fromarray(rgb, mode="RGB")


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--cache", type=str, default=None, help="Where to keep the downloaded TIFFs")
    parser.add_argument("--destination", type=str, default=str(DESTINATION), help="Where to write the two maps")
    args = parser.parse_args()

    cache = Path(args.cache) if args.cache else ROOT / ".moon_cache"
    destination = Path(args.destination)
    destination.mkdir(parents=True, exist_ok=True)

    print("NASA SVS CGI Moon Kit")
    colour_tif: Path = fetch(COLOUR_SOURCE, cache)
    elevation_tif: Path = fetch(ELEVATION_SOURCE, cache)

    colour = Image.open(colour_tif).convert("RGB")
    width, height = colour.size
    colour_path = destination / COLOUR_OUTPUT
    colour.save(colour_path, optimize=True)
    print(f"{COLOUR_OUTPUT}: {width}x{height}, {colour_path.stat().st_size // 1024} KB")

    normal = normal_map_from_elevation(elevation_tif, width, height)
    normal_path = destination / NORMAL_OUTPUT
    normal.save(normal_path, optimize=True)
    print(f"{NORMAL_OUTPUT}: {width}x{height}, {normal_path.stat().st_size // 1024} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
