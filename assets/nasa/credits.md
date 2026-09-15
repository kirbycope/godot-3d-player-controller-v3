# NASA

Public domain, credited to NASA's Scientific Visualization Studio.

| File | Source |
| --- | --- |
| `lroc_color_poles_4k.png` | `lroc_color_poles_4k.tif`, the LROC WAC colour mosaic from the CGI Moon Kit, <https://svs.gsfc.nasa.gov/4720/> |
| `ldem_normal_4k.png` | Derived from `ldem_16_uint.tif`, LOLA elevation from the same kit, by `tools/make_moon_textures.py` |

Both are 4096x2048 equirectangular. `tools/make_moon_textures.py` fetches the two source TIFFs and
rebuilds these from them, so the 46 MB of source is not committed.
