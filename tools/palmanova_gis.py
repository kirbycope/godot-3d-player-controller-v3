#!/usr/bin/env python3
"""Turns open GIS data for Palmanova into the plan tools/make_palmanova.gd builds the scene from.

Inputs (fetched once into the scratchpad, or wherever --osm and --dem point):
  - OpenStreetMap, the ways and relations in the box 45.890 to 45.922 N, 13.285 to 13.335 E, from the Overpass
    API as JSON with `out body geom`: the buildings (nearly all with a `height`), the streets, the city walls
    (`historic=citywalls`), the embankments of the ravelins and lunettes (`man_made=embankment`), the Piazza Grande.
  - The Copernicus DEM GLO-30 tile N45 E013 (public domain COG on AWS), 30 m, for the lie of the land round the town.

Outputs, under assets/palmanova/gis/:
  - plan.json: buildings, roads, the piazza, gate and bastion labels, all in metres round the Piazza Grande's centre
    (x east, z south, the way Godot's XZ plane lies with north at -Z).
  - height.f32: the terrain heightmap, RES x RES float32 little endian, METRES per pixel, row 0 at the north edge,
    with the works stamped on it: the rampart (9 m), its brick scarp, the dry moat (4 m deep) and the ravelins and
    lunettes (6 m), read from the walls and embankments OpenStreetMap draws. Beyond the counterscarp the glacis runs
    down to a seabed, so the town stands as an island in a sea at SEA_LEVEL with the lunettes as islets.
  - normal.png, splat.png, color.png: the HTerrain maps that go with it (grass, dirt, rock and brick by slope
    and place).

    python tools/palmanova_gis.py --osm <overpass.json> --dem <Copernicus tile.tif>

Coordinates: local metres from the piazza centre by an equirectangular projection, which is within a metre over
this 4 km square. Nothing here needs GDAL: the DEM tile is read with tifffile and resampled with numpy.
"""
import argparse
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "palmanova", "gis")

ORIGIN_LAT = 45.905445  # The Piazza Grande's centre (the place=square way's centroid)
ORIGIN_LON = 13.309896
RES = 2049  # HTerrain wants 2^n + 1
METRES = 2.0  # per pixel: a 4096 m square
HALF = (RES - 1) * METRES * 0.5

RAMPART_HEIGHT = 9.0
TERREPLEIN = 16.0  # metres inward from the wall line the rampart top runs
RAMP = 14.0  # the grassed slope down into the town beyond that
SCARP = 4.0  # the brick face leans this much over its height
MOAT_DEPTH = 4.0
MOAT_START = 12.0  # metres out from the wall line the moat floor begins
MOAT_END = 70.0
COUNTERSCARP_END = 80.0
SEA_LEVEL = -6.0  # the town stands on an island: the sea's surface, below the piazza (the moat floor stays dry above it)
SEABED = -12.0  # the flat bed the countryside becomes
SHORE = 120.0  # metres beyond the counterscarp over which the glacis runs down to the seabed
EMBANKMENT_HEIGHT = 6.0
EMBANKMENT_TOP = 5.0  # half width of the crest either side of an embankment line
EMBANKMENT_SLOPE = 9.0
ISLET_SLOPE = 1.5  # metres out per metre down from an embankment's top to the seabed, so a lunette stands as an islet

ROAD_WIDTHS = {
    "motorway": 12.0, "motorway_link": 7.0, "trunk": 10.0, "primary": 9.0, "secondary": 8.0, "tertiary": 7.0,
    "unclassified": 6.0, "residential": 6.0, "service": 4.5, "pedestrian": 5.0, "living_street": 5.0,
    "track": 3.0, "path": 1.8, "footway": 2.0, "cycleway": 2.5, "bridleway": 3.0, "steps": 2.0,
}


def local(lat: float, lon: float) -> tuple:
    """Metres east and south of the origin."""
    x = (lon - ORIGIN_LON) * 111320.0 * math.cos(math.radians(ORIGIN_LAT))
    z = -(lat - ORIGIN_LAT) * 110574.0
    return (round(x, 2), round(z, 2))


def to_pixel(x: float, z: float) -> tuple:
    return ((x + HALF) / METRES, (z + HALF) / METRES)


def parse_height(tags: dict) -> float:
    text = tags.get("height", "")
    try:
        return float(text.replace("m", "").strip())
    except ValueError:
        pass
    try:
        return float(tags.get("building:levels", "")) * 3.2 + 1.0
    except ValueError:
        return 8.0


def way_polygon(element: dict) -> list:
    return [local(p["lat"], p["lon"]) for p in element.get("geometry", [])]


def relation_outer(element: dict) -> list:
    """The first outer ring of a multipolygon relation, joined from its member ways."""
    rings = [m.get("geometry", []) for m in element.get("members", []) if m.get("role") == "outer" and m.get("geometry")]
    if not rings:
        return []
    ring = list(rings[0])
    rest = rings[1:]
    while rest and (ring[0]["lat"] != ring[-1]["lat"] or ring[0]["lon"] != ring[-1]["lon"]):
        tail = ring[-1]
        for i, piece in enumerate(rest):
            if piece[0]["lat"] == tail["lat"] and piece[0]["lon"] == tail["lon"]:
                ring += piece[1:]
                rest.pop(i)
                break
            if piece[-1]["lat"] == tail["lat"] and piece[-1]["lon"] == tail["lon"]:
                ring += list(reversed(piece))[1:]
                rest.pop(i)
                break
        else:
            break
    return [local(p["lat"], p["lon"]) for p in ring]


def read_dem(path: str) -> np.ndarray:
    """The DEM resampled to the terrain grid, in metres above the piazza."""
    import tifffile
    page = tifffile.TiffFile(path).pages[0]
    data = page.asarray()
    scale = page.tags["ModelPixelScaleTag"].value
    tie = page.tags["ModelTiepointTag"].value
    lon0, lat0 = tie[3], tie[4]
    rows = np.arange(RES)
    cols = np.arange(RES)
    z = (rows - (RES - 1) / 2.0) * METRES
    x = (cols - (RES - 1) / 2.0) * METRES
    lat = ORIGIN_LAT - z / 110574.0
    lon = ORIGIN_LON + x / (111320.0 * math.cos(math.radians(ORIGIN_LAT)))
    fr = (lat0 - lat) / scale[1]
    fc = (lon - lon0) / scale[0]
    r0 = np.clip(np.floor(fr).astype(int), 0, data.shape[0] - 2)
    c0 = np.clip(np.floor(fc).astype(int), 0, data.shape[1] - 2)
    tr = (fr - r0)[:, None]
    tc = (fc - c0)[None, :]
    a = data[r0][:, c0]
    b = data[r0][:, c0 + 1]
    c = data[r0 + 1][:, c0]
    d = data[r0 + 1][:, c0 + 1]
    grid = (a * (1 - tc) + b * tc) * (1 - tr) + (c * (1 - tc) + d * tc) * tr
    origin_r = (lat0 - ORIGIN_LAT) / scale[1]
    origin_c = (ORIGIN_LON - lon0) / scale[0]
    ir, ic = int(origin_r), int(origin_c)
    t_r, t_c = origin_r - ir, origin_c - ic
    origin_h = (data[ir, ic] * (1 - t_c) + data[ir, ic + 1] * t_c) * (1 - t_r) + (data[ir + 1, ic] * (1 - t_c) + data[ir + 1, ic + 1] * t_c) * t_r
    return (grid - origin_h).astype(np.float32)


def draw_lines(lines: list, width: int = 1) -> np.ndarray:
    image = Image.new("L", (RES, RES), 0)
    draw = ImageDraw.Draw(image)
    for line in lines:
        pts = [to_pixel(x, z) for x, z in line]
        if len(pts) >= 2:
            draw.line(pts, fill=255, width=width)
    return np.array(image) > 0


def fill_polygons(polygons: list) -> np.ndarray:
    image = Image.new("L", (RES, RES), 0)
    draw = ImageDraw.Draw(image)
    for poly in polygons:
        pts = [to_pixel(x, z) for x, z in poly]
        if len(pts) >= 3:
            draw.polygon(pts, fill=255)
    return np.array(image) > 0


def stamp_works(base: np.ndarray, walls: list, embankments: list, closed_embankments: list) -> tuple:
    """The heightmap with the works on it, and the signed distance from the wall line (outward positive)."""
    wall_mask = draw_lines(walls, 1)
    distance, (near_r, near_c) = ndimage.distance_transform_edt(~wall_mask, return_indices=True)
    distance = distance * METRES
    rr, cc = np.mgrid[0:RES, 0:RES]
    radius = np.hypot((cc - (RES - 1) / 2.0) * METRES, (rr - (RES - 1) / 2.0) * METRES)
    wall_radius = radius[near_r, near_c]
    s = np.where(radius >= wall_radius, distance, -distance)  # outward positive
    h = np.zeros_like(base)
    # Inside the town: flat at the piazza's level. The rampart, scarp, moat and counterscarp by profile.
    h = np.where(s < -(TERREPLEIN + RAMP), 0.0, h)
    ramp = (s + TERREPLEIN + RAMP) / RAMP
    h = np.where((s >= -(TERREPLEIN + RAMP)) & (s < -TERREPLEIN), RAMPART_HEIGHT * ramp, h)
    h = np.where((s >= -TERREPLEIN) & (s < 0.0), RAMPART_HEIGHT, h)
    h = np.where((s >= 0.0) & (s < SCARP), RAMPART_HEIGHT * (1.0 - s / SCARP), h)
    h = np.where((s >= SCARP) & (s < MOAT_START), -MOAT_DEPTH * (s - SCARP) / (MOAT_START - SCARP), h)
    h = np.where((s >= MOAT_START) & (s < MOAT_END), -MOAT_DEPTH, h)
    h = np.where((s >= MOAT_END) & (s < COUNTERSCARP_END), -MOAT_DEPTH * (COUNTERSCARP_END - s) / (COUNTERSCARP_END - MOAT_END), h)
    # Beyond the counterscarp the glacis runs down to the seabed, with a little of the DEM's own relief kept on it
    shore = np.clip((s - COUNTERSCARP_END) / SHORE, 0.0, 1.0)
    h = np.where(s >= COUNTERSCARP_END, (1.0 - shore) * 0.0 + shore * (SEABED + base * 0.2), h)
    # Ravelins and lunettes: closed embankments are plateaus, open ones crests, at their own height above the town,
    # falling away at the islet slope, so the lunettes out in the water stand as islets and never sink with the bed
    plateau = fill_polygons(closed_embankments)
    plateau_distance = ndimage.distance_transform_edt(~plateau) * METRES
    mound = np.where(plateau, EMBANKMENT_HEIGHT, EMBANKMENT_HEIGHT - plateau_distance / ISLET_SLOPE)
    crest_mask = draw_lines(embankments, 1)
    crest_distance = ndimage.distance_transform_edt(~crest_mask) * METRES
    crest = EMBANKMENT_HEIGHT - np.maximum(crest_distance - EMBANKMENT_TOP, 0.0) / ISLET_SLOPE
    outside = s > SCARP + 2.0
    works = np.maximum(mound, crest)
    h = np.where(outside, np.maximum(h, works), h)
    return h.astype(np.float32), s.astype(np.float32)


def normal_map(h: np.ndarray) -> np.ndarray:
    dzdx = np.zeros_like(h)
    dzdy = np.zeros_like(h)
    dzdx[:, 1:-1] = (h[:, 2:] - h[:, :-2]) / (2.0 * METRES)
    dzdy[1:-1, :] = (h[2:, :] - h[:-2, :]) / (2.0 * METRES)
    n = np.stack([-dzdx, np.ones_like(h), -dzdy], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    encoded = np.stack([n[..., 0], n[..., 2], n[..., 1]], axis=-1) * 0.5 + 0.5  # HTerrain's encode_normal: (x, z, y)
    return (encoded * 255.0).astype(np.uint8)


def slope_degrees(h: np.ndarray) -> np.ndarray:
    gy, gx = np.gradient(h, METRES)
    return np.degrees(np.arctan(np.hypot(gx, gy)))


def splat_map(h: np.ndarray, s: np.ndarray) -> np.ndarray:
    """Slot weights: 0 grass, 1 dirt (the moat floor), 2 rock (steep ground), 3 brick (the scarp)."""
    slope = slope_degrees(h)
    brick = np.clip((slope - 30.0) / 15.0, 0.0, 1.0) * ((s > -3.0) & (s < SCARP + 3.0))
    rock = np.clip((slope - 35.0) / 15.0, 0.0, 1.0) * (brick == 0.0)
    dirt = np.clip(1.0 - np.abs(s - (MOAT_START + MOAT_END) * 0.5) / ((MOAT_END - MOAT_START) * 0.5), 0.0, 1.0) * (h < -MOAT_DEPTH + 0.5)
    dirt = np.maximum(dirt, np.clip((SEA_LEVEL + 1.0 - h) / 3.0, 0.0, 1.0))  # the seabed and the strand are bare
    grass = np.clip(1.0 - brick - rock - dirt, 0.0, 1.0)
    weights = np.stack([grass, dirt, rock, brick], axis=-1)
    weights /= np.maximum(weights.sum(axis=-1, keepdims=True), 1e-6)
    return (weights * 255.0).astype(np.uint8)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--osm", required=True, help="Overpass JSON with geometry for the Palmanova box")
    parser.add_argument("--dem", required=True, help="Copernicus GLO-30 tile N45 E013 GeoTIFF")
    parser.add_argument("--out", default=OUT_DIR)
    parser.add_argument("--debug-png", default="", help="write a plan overview PNG here")
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)
    with open(args.osm, encoding="utf-8") as handle:
        elements = json.load(handle)["elements"]

    buildings = []
    roads = []
    walls = []
    embankments = []
    closed_embankments = []
    piazza = []
    gates = []
    for element in elements:
        tags = element.get("tags", {})
        kind = element["type"]
        if kind == "way":
            poly = way_polygon(element)
        elif kind == "relation":
            poly = relation_outer(element)
        else:
            continue
        if len(poly) < 2:
            continue
        closed = len(poly) >= 4 and poly[0] == poly[-1]
        if "building" in tags and closed:
            entry = {"outline": poly[:-1], "height": round(parse_height(tags), 1), "kind": tags["building"]}
            if tags.get("name"):
                entry["name"] = tags["name"]
            if tags.get("roof:shape"):
                entry["roof"] = tags["roof:shape"]
            if tags.get("historic") == "city_gate" or tags.get("amenity") == "place_of_worship":
                entry["landmark"] = tags.get("historic") or tags.get("amenity")
            buildings.append(entry)
            if tags.get("historic") == "city_gate":
                cx = sum(p[0] for p in poly[:-1]) / (len(poly) - 1)
                cz = sum(p[1] for p in poly[:-1]) / (len(poly) - 1)
                gates.append({"name": tags.get("name", "Porta"), "x": round(cx, 1), "z": round(cz, 1)})
        elif tags.get("highway") in ROAD_WIDTHS and kind == "way":
            roads.append({"line": poly, "width": ROAD_WIDTHS[tags["highway"]], "kind": tags["highway"], "name": tags.get("name", "")})
        if tags.get("historic") == "citywalls" or tags.get("barrier") == "city_wall":
            walls.append(poly)
        if tags.get("man_made") == "embankment":
            (closed_embankments if closed else embankments).append(poly)
        if tags.get("place") == "square" and tags.get("name", "").startswith("Piazza Grande") and closed:
            piazza = poly[:-1]

    base = read_dem(args.dem)
    h, s = stamp_works(base, walls, embankments, closed_embankments)
    h.astype("<f4").tofile(os.path.join(args.out, "height.f32"))
    Image.fromarray(normal_map(h), "RGB").save(os.path.join(args.out, "normal.png"))
    Image.fromarray(splat_map(h, s), "RGBA").save(os.path.join(args.out, "splat.png"))
    Image.fromarray(np.full((RES, RES, 4), 255, np.uint8), "RGBA").save(os.path.join(args.out, "color.png"))

    # The nine salients: the farthest wall point of the first ring in each 40 degree sector (the lunettes' walls lie
    # a kilometre out and are left aside), named the way the town names them, counter-clockwise from Porta Cividale:
    # Donato, Barbaro, Grimani, Savorgnan, Foscarini, Villachiara, Contarini, Garzoni, Monte.
    wall_points = [p for line in walls for p in line if math.hypot(*p) < 745.0]
    salients = []
    for i in range(9):
        lo = (40.0 * i) % 360.0
        best = None
        for x, z in wall_points:
            bearing = (math.degrees(math.atan2(x, -z)) + 360.0) % 360.0
            if (bearing - lo) % 360.0 < 40.0:
                r = math.hypot(x, z)
                if best is None or r > best[0]:
                    best = (r, x, z, bearing)
        if best:
            salients.append(best)
    cividale = next((g for g in gates if g["name"] == "Porta Cividale"), None)
    gate_bearing = (math.degrees(math.atan2(cividale["x"], -cividale["z"])) + 360.0) % 360.0 if cividale else 65.0
    order = sorted(salients, key=lambda b: (gate_bearing - b[3]) % 360.0)  # counter-clockwise from the gate
    names = ["Donato", "Barbaro", "Grimani", "Savorgnan", "Foscarini", "Villachiara", "Contarini", "Garzoni", "Monte"]
    bastions = [{"name": names[i], "x": round(b[1], 1), "z": round(b[2], 1)} for i, b in enumerate(order)]

    plan = {
        "origin": {"lat": ORIGIN_LAT, "lon": ORIGIN_LON},
        "terrain": {"resolution": RES, "metres_per_pixel": METRES, "sea_level": SEA_LEVEL},
        "buildings": buildings, "roads": roads, "piazza": piazza, "gates": gates, "bastions": bastions,
    }
    with open(os.path.join(args.out, "plan.json"), "w", encoding="utf-8", newline="\n") as handle:
        json.dump(plan, handle, ensure_ascii=False, separators=(",", ":"))
    print("buildings %d, roads %d, walls %d, embankments %d open %d closed, gates %d, bastions %d" % (
        len(buildings), len(roads), len(walls), len(embankments), len(closed_embankments), len(gates), len(bastions)))
    print("height range %.1f to %.1f m, DEM range %.1f to %.1f m" % (h.min(), h.max(), base.min(), base.max()))

    if args.debug_png:
        overview = Image.new("RGB", (RES, RES), (40, 60, 30))
        shade = np.clip((h + 5.0) / 20.0, 0.0, 1.0)
        overview = Image.fromarray(np.stack([shade * 90 + 40, shade * 120 + 60, shade * 60 + 30], axis=-1).astype(np.uint8), "RGB")
        draw = ImageDraw.Draw(overview)
        for road in roads:
            draw.line([to_pixel(x, z) for x, z in road["line"]], fill=(230, 230, 230), width=max(1, int(road["width"] / METRES)))
        for building in buildings:
            draw.polygon([to_pixel(x, z) for x, z in building["outline"]], fill=(200, 120, 90))
        for line in walls:
            draw.line([to_pixel(x, z) for x, z in line], fill=(255, 40, 40), width=2)
        for line in embankments + closed_embankments:
            draw.line([to_pixel(x, z) for x, z in line], fill=(60, 120, 255), width=2)
        if piazza:
            draw.polygon([to_pixel(x, z) for x, z in piazza], fill=(250, 240, 200))
        for gate in gates:
            draw.ellipse([to_pixel(gate["x"] - 12, gate["z"] - 12), to_pixel(gate["x"] + 12, gate["z"] + 12)], outline=(255, 255, 0), width=3)
        for bastion in bastions:
            draw.ellipse([to_pixel(bastion["x"] - 16, bastion["z"] - 16), to_pixel(bastion["x"] + 16, bastion["z"] + 16)], outline=(0, 255, 255), width=3)
        overview.crop((RES // 2 - 600, RES // 2 - 600, RES // 2 + 600, RES // 2 + 600)).save(args.debug_png)
    return 0


if __name__ == "__main__":
    sys.exit(main())
