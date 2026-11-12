"""Sirik ve dort kova: sirik + ip = Blender'da modellendi; kovalar Poly Haven wooden_bucket_01 (CC0, James Ray Cock),
https://polyhaven.com/a/wooden_bucket_01 (dusuk cokgenli). Sirik/ip dokusu kova atlasinin duz tahta seridinden alinir (tek doku).
Orijin sirigin omuza oturdugu orta nokta; sirik X ekseninde; her uca 2 kova (on/arka) iple asili; Water, Water.001..003.
  blender -b -P tools/blender/make_tool_yoke.py -- --src <klasor> --glb assets/models/tools/yoke.glb [--png-dir k]
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tool_common import *

SCALE = 0.62
POLE_HALF = 0.80
POLE_R = 0.032
END_X = 0.62           # kova ciftinin sirik uzerindeki x konumu
SPREAD_Y = 0.15        # on/arka kova y ofseti
ROPE_DROP = 0.34       # sirik ekseninden kulp ustune dusey mesafe
# kova atlasinda duz tahta seridi (uv)
U0, U1, V0, V1 = 0.370, 0.432, 0.34, 0.62

reset()
src = arg("--src")
base, w = prepare_bucket(src, SCALE, body_tris=360, handle_tris=100, name="Bucket")
buckets, waters = [], []
k = 0
for sx in (-1, 1):
    for sy in (-1, 1):
        loc = (sx * END_X, sy * SPREAD_Y, -ROPE_DROP)
        if k == 0:
            b = base
            b.location = loc
        else:
            b = duplicate(base, f"Bucket.{k:03d}", loc=loc)
        buckets.append(b)
        nm = "Water" if k == 0 else f"Water.{k:03d}"
        waters.append(make_water(nm, w["r_bottom"], w["r_top"], w["height"], (loc[0], loc[1], loc[2] + w["z_floor"]), segs=12))
        k += 1


def cyl(bm, p0, p1, r, segs, uvf):
    """p0->p1 arasi silindir, uvf(t, aci) -> (u, v)."""
    p0, p1 = Vector(p0), Vector(p1)
    ax = (p1 - p0).normalized()
    ref = Vector((0, 0, 1)) if abs(ax.z) < 0.9 else Vector((1, 0, 0))
    a = ax.cross(ref).normalized()
    b = ax.cross(a).normalized()
    rings = []
    for t, p in ((0.0, p0), (1.0, p1)):
        ring = []
        for i in range(segs):
            ang = 2 * math.pi * i / segs
            ring.append(bm.verts.new(p + (a * math.cos(ang) + b * math.sin(ang)) * r))
        rings.append(ring)
    uv = bm.loops.layers.uv.verify()
    faces = []
    for i in range(segs):
        j = (i + 1) % segs
        faces.append(((rings[0][i], rings[0][j], rings[1][j], rings[1][i]), (0.0, 0.0, 1.0, 1.0),
                      (2 * math.pi * i / segs, 2 * math.pi * j / segs, 2 * math.pi * j / segs, 2 * math.pi * i / segs)))
    for ring, t, rev in ((rings[0], 0.0, True), (rings[1], 1.0, False)):
        vs = list(reversed(ring)) if rev else ring
        faces.append((tuple(vs), tuple([t] * segs), tuple(2 * math.pi * i / segs for i in range(segs))))
    for verts, ts, angs in faces:
        f = bm.faces.new(verts)
        for loop, t, ang in zip(f.loops, ts, angs):
            loop[uv].uv = uvf(t, ang)


def uv_plank(t, ang):
    s = abs(((ang + math.pi) % (2 * math.pi)) - math.pi) / math.pi
    return (U0 + (U1 - U0) * s, V0 + (V1 - V0) * t)


bm = bmesh.new()
cyl(bm, (-POLE_HALF, 0, 0), (POLE_HALF, 0, 0), POLE_R, 10, uv_plank)
# omuz yastigi: ortada biraz kalin
cyl(bm, (-0.16, 0, 0), (0.16, 0, 0), POLE_R * 1.35, 10, uv_plank)
# iplik: kulp ustunden sirik uzerindeki noktaya (v-seklinde)
for sx in (-1, 1):
    for sy in (-1, 1):
        cyl(bm, (sx * END_X, sy * SPREAD_Y, -ROPE_DROP), (sx * END_X, 0.0, 0.0), 0.008, 5,
            lambda t, ang: (U0 + 0.01, V0 + 0.2 * t))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
me = bpy.data.meshes.new("Pole")
bm.to_mesh(me)
bm.free()
pole = bpy.data.objects.new("Pole", me)
bpy.context.scene.collection.objects.link(pole)
set_material(pole, base.data.materials[0])
finish_mesh(pole)
allo = [pole] + buckets + waters
log("UCGEN pole", tri_count(pole), "kova", [tri_count(o) for o in buckets], "su", [tri_count(o) for o in waters], "toplam", total_tris(allo))
if arg("--png-dir"):
    render_views(allo, arg("--png-dir"), "yoke", [
        ("3q", (1.9, 2.4, 0.5), (0, 0, -0.45), 40),
        ("fp", (0.0, -0.30, 0.18), (0, 0.5, -0.45), 100),
        ("ust", (0.0, -0.1, 0.9), (0, 0.0, -0.4), 60)], floor_z=-0.95)
if arg("--glb"):
    export_glb(allo, arg("--glb"))
