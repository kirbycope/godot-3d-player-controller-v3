#!/usr/bin/env python3
"""List what an exported .pck should carry but does not: every res:// path a packed script names in a string (a
preload, a load, a scene path) and every ext_resource a packed scene or resource references, that is neither in
the pack nor imported into it. A scene-filtered export walks only the scenes it lists, so a scene reached through
a .tres (an ammunition's projectile_scene) or a clip preloaded by a script shows up here; add those to the preset's
export_files (scenes) or hang them on an exported scene (other resources). No dependencies.

Usage, from the project root:
    python tools/pck_missing.py [docs/index.pck]
"""
import os,re,sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pck_report import read_pack
packed=set(p.replace('res://','') for _,p in read_pack(sys.argv[1] if len(sys.argv)>1 else 'docs/index.pck'))
def in_pack(rel):
    return rel in packed or (rel+'.import') in packed or (rel+'.remap') in packed or rel.replace('.gd','.gdc') in packed
missing={}
skip=('tests/','addons/gut/','scratch/','.godot/','addons/godotsteam/editor/','tools/')
for root,dirs,files in os.walk('.'):
    dirs[:]=[d for d in dirs if d not in ('.godot','.git','scratch','.venv','docs','.mcp')]
    for n in files:
        p=os.path.join(root,n).replace(os.sep,'/')[2:]
        if any(s in p for s in skip): continue
        if n.endswith('.gd'):
            if not in_pack(p): continue
            t=open(p,encoding='utf-8',errors='replace').read()
            for m in re.finditer(r'"(res://[^"]+\.(?:tscn|tres|ogg|wav|mp3|png|jpg|webp|gdshader|svg|gd))"',t):
                rel=m.group(1)[6:]
                if not in_pack(rel): missing.setdefault(rel,set()).add(p)
        elif n.endswith(('.tres','.tscn')) and in_pack(p):
            t=open(p,encoding='utf-8',errors='replace').read()
            for m in re.finditer(r'path="(res://[^"]+)"',t):
                rel=m.group(1)[6:]
                if not in_pack(rel): missing.setdefault(rel,set()).add(p)
for rel in sorted(missing):
    print(rel, '<-', ', '.join(sorted(missing[rel]))[:150])
print(len(missing),'missing')
