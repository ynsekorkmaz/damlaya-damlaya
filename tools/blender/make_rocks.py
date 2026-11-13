"""Vadi kayalari: Poly Haven kaya modelleri (CC0), Blender'da <=800 ucgene indirilir.
  blender -b -P tools/blender/make_rocks.py -- --src <klasor> --out assets/models/rocks [--png-dir k] [--only 1,2]
--src icinde <varlik>/<varlik>.gltf + .bin + textures/<varlik>_diff_1k.jpg olmali (Poly Haven 1k gltf, CC0):
  https://api.polyhaven.com/files/<varlik> -> gltf 1k; yalnizca diffuse dokusu alinir.
Sozlesme: metre; yatay en buyuk boyut = 1 m (oyunda olcekle buyur), yukseklik 0,55..0,95 m;
orijin taban merkezinde (z=0 en alt nokta), +Y yukari (glb), yumusak golgeleme, model basina tek doku (1024).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tool_common import *  # noqa

# glb sirasi -> (varlik kimligi, hedef yukseklik/genislik orani ya da None = dogal oran, kisitli)
ROCKS = [
    ("namaqualand_boulder_02", None),
    ("namaqualand_boulder_03", None),
    ("namaqualand_boulder_04", None),
    ("namaqualand_boulder_05", None),
    ("namaqualand_boulder_06", None),
    ("rock_07", None),
]
TRIS = 800
H_MIN, H_MAX = 0.55, 0.95


def build(n, asset, src):
    reset()
    meshes = import_ph(src, asset)
    ob = join(meshes, "Rock%d" % n)
    # zemin duzlemine donuk degil: ham z yukari
    mn, mx = bbox(ob)
    size = mx - mn
    log(asset, "ham boyut", [round(c, 3) for c in size], "ucgen", tri_count(ob))
    decimate(ob, TRIS)
    s = 1.0 / max(size.x, size.y)
    h = size.z * s
    hz = min(max(h, H_MIN), H_MAX) / h
    cx, cy = (mn.x + mx.x) / 2, (mn.y + mx.y) / 2
    M = Matrix.Diagonal((s, s, s * hz, 1.0)) @ Matrix.Translation((-cx, -cy, -mn.z))
    transform_mesh(ob, M)
    set_material(ob, tex_material("RockTex%d" % n, diffuse_path(src, asset), roughness=1.0))
    finish_mesh(ob)
    log("rock", n, "ucgen", tri_count(ob), "boyut", [round(c, 3) for c in bbox(ob)[1] - bbox(ob)[0]])
    return ob


only = [int(x) for x in arg("--only").split(",")] if arg("--only") else None
src = arg("--src")
out = arg("--out", "assets/models/rocks")
png = arg("--png-dir")
for i, (asset, _) in enumerate(ROCKS, start=1):
    if only and i not in only:
        continue
    ob = build(i, asset, src)
    if png:
        render_views([ob], png, "rock%d" % i, [("a", (1.6, -1.6, 1.0), (0, 0, 0.35), 40)], res=(500, 400))
    export_glb([ob], os.path.join(out, "rock_%d.glb" % i))
