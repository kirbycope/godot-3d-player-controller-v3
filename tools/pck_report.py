#!/usr/bin/env python3
"""Report what fills an exported .pck: the biggest files, the totals by extension, and the totals by the
source folder each imported file came from (mapped back through the .import files). No dependencies.

Usage, from the project root:
    python tools/pck_report.py docs/index.pck [top_n]
"""
import os
import re
import struct
import sys
from collections import defaultdict


def read_pack(pck_path: str):
    items = []
    with open(pck_path, "rb") as f:
        if f.read(4) != b"GDPC":
            raise SystemExit("Not a Godot pack")
        f.read(16)  # pack version, major, minor, patch
        _flags, _file_base, dir_offset = struct.unpack("<IQQ", f.read(20))
        f.seek(dir_offset)
        (count,) = struct.unpack("<I", f.read(4))
        for _ in range(count):
            (path_len,) = struct.unpack("<I", f.read(4))
            path = f.read(path_len).rstrip(b"\0").decode("utf-8", "replace")
            _offset, size = struct.unpack("<QQ", f.read(16))
            f.read(20)  # md5 and flags
            items.append((size, path))
    return items


def imported_to_source(project_root: str):
    mapping = {}
    for root, dirs, files in os.walk(project_root):
        dirs[:] = [d for d in dirs if d not in (".godot", ".git")]
        for name in files:
            if not name.endswith(".import"):
                continue
            import_path = os.path.join(root, name)
            try:
                text = open(import_path, encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            source = os.path.relpath(import_path[:-7], project_root).replace(os.sep, "/")
            for match in re.finditer(r"res://\.godot/imported/([^\"\]]+)", text):
                mapping[match.group(1)] = source
    return mapping


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    pck_path = sys.argv[1]
    top_n = int(sys.argv[2]) if len(sys.argv) > 2 else 30
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    items = read_pack(pck_path)
    mapping = imported_to_source(project_root)
    by_dir = defaultdict(int)
    tex_by_dir = defaultdict(int)
    by_ext = defaultdict(int)
    rows = []
    for size, path in items:
        rel = path.replace("res://", "")
        ext = os.path.splitext(rel)[1]
        if rel.startswith(".godot/imported/"):
            source = mapping.get(rel[len(".godot/imported/"):], "UNMAPPED/" + rel)
        else:
            source = rel
        parts = source.split("/")
        folder = "/".join(parts[:3]) if parts[0] in ("assets", "addons") else "/".join(parts[:2])
        by_dir[folder] += size
        by_ext[ext] += size
        if ext == ".ctex":
            tex_by_dir[folder] += size
        rows.append((size, source))
    total = sum(size for size, _ in items)
    print(f"{pck_path}: {total / 1e6:.1f} MB in {len(items)} files")
    print("\nBy extension:")
    for ext, size in sorted(by_ext.items(), key=lambda kv: -kv[1])[:10]:
        print(f"{size / 1e6:8.1f} MB  {ext or '(none)'}")
    print("\nBy source folder (total / of which textures):")
    for folder, size in sorted(by_dir.items(), key=lambda kv: -kv[1])[:top_n]:
        print(f"{size / 1e6:8.1f} MB  ({tex_by_dir[folder] / 1e6:5.1f} tex)  {folder}")
    print("\nBiggest sources:")
    for size, source in sorted(rows, reverse=True)[:top_n]:
        print(f"{size / 1e6:8.2f} MB  {source}")


if __name__ == "__main__":
    main()
