"""Kanal glb'lerini yan yana dizip kontrol goruntusu alir (3x3 ag ve ozel parcalar).
  blender -b -P tools/blender/montage_canal.py -- --glb-dir assets/models/canal --png-dir klasor [--set net|special|mill|build]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tool_common import *  # noqa

GLB = arg("--glb-dir")
PNG = arg("--png-dir")
SET = arg("--set", "net")


def load(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    return new


def place(proto, loc, rot):
    out = []
    for o in proto:
        if o.type != "MESH":
            continue
        c = o.copy()
        c.data = o.data
        bpy.context.scene.collection.objects.link(c)
        # protonun yerel donusumu korunur: once parca donusu, sonra konum
        m = Matrix.Translation((loc[0], loc[1], 0)) @ Matrix.Rotation(-rot * math.pi / 2, 4, "Z") @ o.matrix_world
        c.matrix_world = m
        out.append(c)
    return out


reset()
placed = []
if SET == "net":
    protos = {k: load(os.path.join(GLB, k + ".glb")) for k in ("straight", "elbow", "tee", "wye", "cross")}
    grid = {(0, 0): ("elbow", 3), (1, 0): ("tee", 0), (2, 0): ("elbow", 0),
            (0, 1): ("tee", 3), (1, 1): ("cross", 0), (2, 1): ("tee", 1),
            (0, 2): ("elbow", 2), (1, 2): ("wye", 1), (2, 2): ("elbow", 1)}
    for (cx, cy), (k, r) in grid.items():
        placed += place(protos[k], (2.0 * (cx - 1), -2.0 * (cy - 1)), r)
    for o in protos.values():
        for x in o:
            x.hide_render = True
    views = [("3q", (0.0, -4.6, 5.6), (0, -0.4, 0), 50), ("ust", (0, 0, 9.5), (0, 0, 0), 40)]
elif SET == "special":
    protos = {k: load(os.path.join(GLB, k + ".glb")) for k in ("aqueduct", "gate", "reservoir")}
    for i, k in enumerate(("aqueduct", "gate", "reservoir")):
        placed += place(protos[k], (2.0 * (i - 1), 0), 0)
    for o in protos.values():
        for x in o:
            x.hide_render = True
    views = [("3q", (0.0, -3.4, 4.6), (0, 0.1, 0.2), 62)]
elif SET == "mill":
    p = load(os.path.join(GLB, "mill.glb"))
    placed = [o for o in p if o.type == "MESH"]
    views = [("3q", (4.3, -4.6, 3.4), (0, 0.3, 0.9), 45), ("yan", (-3.8, 3.8, 3.0), (0, 0, 0.9), 45)]
else:
    protos = {k: load(os.path.join(GLB, "..", "build", k)) for k in ("tree_shade.glb", "reeds.glb")}
    protos["h"] = load(os.path.join(GLB, "..", "tools", "hammer.glb"))
    placed = []
    for i, k in enumerate(protos):
        placed += place(protos[k], (3.0 * i - 3.0 if k != "h" else 1.0, 0), 0) if k != "h" else []
    # kamis ve cekic: agacin yanina
    for o in protos["reeds.glb"]:
        pass
    views = [("hepsi", (0.0, -9.0, 3.2), (0, 0, 1.8), 45)]
    # cekic kamisin yanina yerlestirilir (olcek karsilastirma)
    for x in protos["h"]:
        if x.type == "MESH":
            x.location = (1.2, -0.5, 0.2)
            x.rotation_euler = (0, 0, 0)
render_views(placed if SET != "build" else [o for v in protos.values() for o in v if o.type == "MESH"],
             PNG, SET, views, res=(1100, 800), floor_z=0.0)
