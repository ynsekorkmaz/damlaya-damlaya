"""Su kaynagi kayasi: assets/models/rocks/rock_<n>.glb (Poly Haven CC0, make_rocks.py ciktisi) parcalarindan
dort kayalik bir grup; ortada suyun suzuldugu dikey yarik. Kayalar ayri nesneler (oyunda her biri icin basit
dis bukey cakisma), yarigin arkasina oturan koyu "Crevice" ince seridi yarigin derinlik hissi icin.
  blender -b -P tools/blender/make_spring_rock.py -- --rocks assets/models/rocks --glb assets/models/spring_rock.glb [--png-dir k]
Sozlesme: metre, +Y yukari (glb), yaklasik 2,2 m yukseklik; orijin zeminde grubun ortasi; on yuz (yarik) glb +Z'ye (Blender -Y) bakar.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tool_common import *  # noqa

RK = arg("--rocks", "assets/models/rocks")

# ad, rock_n, konum (x, y, z), donus z (derece), olcek (genislik), yukseklik carpani, yaw
PARTS = [
    ("RockLeft",  3, (-0.95, -0.05, -0.15), 20.0, 1.9, 1.7),
    ("RockRight", 6, (1.12, -0.05, -0.12), 100.0, 1.65, 2.25),
    ("RockBack",  2, (0.0, 0.95, -0.20), 0.0, 2.6, 1.85),
    ("RockFront", 5, (1.0, -1.00, -0.18), 35.0, 1.1, 1.0),
]


def load_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        if o.parent:
            m = o.matrix_world.copy()
            o.parent = None
            o.matrix_world = m
    meshes = [o for o in new if o.type == "MESH"]
    for o in new:
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return meshes[0]


reset()
objs = []
for name, n, loc, rotz, width, hmul in PARTS:
    ob = load_glb(os.path.join(RK, "rock_%d.glb" % n))
    mn, mx = bbox(ob)
    # taban merkezi orijinde (make_rocks cikti sozlesmesi)
    M = (Matrix.Translation(loc) @ Matrix.Rotation(math.radians(rotz), 4, "Z")
         @ Matrix.Diagonal((width, width, width * hmul, 1.0)))
    transform_mesh(ob, M)
    ob.name = ob.data.name = name
    objs.append(ob)

# ---- yarik astari: arka kayaya oturan koyu serit (x: -0.13..0.13, z: 0.12..1.75)
back = [o for o in objs if o.name == "RockBack"][0]
bvh = make_bvh(back)
XS = [-0.18, -0.06, 0.06, 0.18]
ZS = [0.12 + i * (1.70 - 0.12) / 13 for i in range(14)]
bm = bmesh.new()
grid = []
for z in ZS:
    row = []
    for x in XS:
        hit = bvh.ray_cast(Vector((x, -4.0, z)), Vector((0, 1, 0)))
        y = hit[0].y - 0.015 if hit[0] is not None else 0.9
        row.append(bm.verts.new((x, y, z)))
    grid.append(row)
for i in range(len(ZS) - 1):
    for j in range(len(XS) - 1):
        bm.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bmesh.ops.triangulate(bm, faces=bm.faces)
me = bpy.data.meshes.new("Crevice")
bm.to_mesh(me)
bm.free()
crev = bpy.data.objects.new("Crevice", me)
bpy.context.scene.collection.objects.link(crev)
set_material(crev, color_material("CreviceDark", (0.045, 0.035, 0.03), 1.0))
for p in me.polygons:
    p.use_smooth = True
objs.append(crev)

FINAL_SCALE = 0.92   # grup: ~3,7 m genis, ~2,25 m yuksek
for o in objs:
    transform_mesh(o, Matrix.Scale(FINAL_SCALE, 4))
tris = total_tris(objs)
mn = Vector((1e9,) * 3)
mx = Vector((-1e9,) * 3)
for o in objs:
    a, b = bbox(o)
    mn = Vector([min(mn[i], a[i]) for i in range(3)])
    mx = Vector([max(mx[i], b[i]) for i in range(3)])
log("UCGEN", tris, "kutu min", [round(c, 2) for c in mn], "max", [round(c, 2) for c in mx])
if arg("--png-dir"):
    render_views(objs, arg("--png-dir"), "spring", [
        ("on", (0.0, -6.0, 1.6), (0, 0, 1.0), 38),
        ("3q", (4.2, -4.2, 2.4), (0, 0, 0.9), 38),
        ("yan", (-6.0, 0.5, 1.6), (0, 0, 1.0), 38)], res=(700, 560), floor_z=0.0)
if arg("--glb"):
    export_glb(objs, arg("--glb"))
