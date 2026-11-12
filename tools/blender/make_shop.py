"""Dukkan: kucuk ahsap tezgah/kulube (3 m x ~2,6 m yukseklik). Yapi Blender'da modellendi (duz tahta kutular,
cerceve, cati, tente); kovalar ve canaklar Poly Haven'dan dusuk cokgenli:
  wooden_bucket_01 (CC0, James Ray Cock) https://polyhaven.com/a/wooden_bucket_01
  wooden_bowl_02   (CC0, Kuutti Siitonen) https://polyhaven.com/a/wooden_bowl_02
  brown_planks_03  (CC0, Rob Tuytel; doku) https://polyhaven.com/a/brown_planks_03
Orijin zeminde, tezgahin on orta noktasi; on yuz Blender +Y (glTF -Z) tarafina bakar. Su nesnesi yok.
  blender -b -P tools/blender/make_shop.py -- --src <klasor> --glb assets/models/shop/shop.glb [--png-dir k]
"""
import os, random, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tool_common import *

reset()
src = arg("--src")
random.seed(7)
DENS = 0.8                       # doku yogunlugu (1 m = 0.8 doku)

mat_wood = tex_material("ShopWood", os.path.join(src, "brown_planks_03", "brown_planks_03_diff_1k.jpg"))
mat_awn_a = color_material("AwningA", (0.70, 0.36, 0.20))
mat_awn_b = color_material("AwningB", (0.86, 0.80, 0.66))


def new_bm():
    bm = bmesh.new()
    bm.loops.layers.uv.verify()
    return bm


def assign_uv(bm, faces, grain, off):
    uv = bm.loops.layers.uv.verify()
    for f in faces:
        n = f.normal
        dom = max(range(3), key=lambda a: abs(n[a]))
        for loop in f.loops:
            co = loop.vert.co
            if dom != grain:
                v = co[grain]
                u = co[[a for a in range(3) if a not in (dom, grain)][0]]
            else:
                t = [a for a in range(3) if a != dom]
                u, v = co[t[0]], co[t[1]]
            loop[uv].uv = (u * DENS + off[0], v * DENS + off[1])


def box(bm, center, size, grain=2, rot=None, bevel=0.008, textured=True):
    before = set(bm.faces)
    ret = bmesh.ops.create_cube(bm, size=1.0)
    verts = ret["verts"]
    for v in verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    edges = list({e for v in verts for e in v.link_edges})
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=edges, offset=bevel, offset_type="OFFSET", segments=1, profile=0.5, affect="EDGES")
    faces = [f for f in bm.faces if f not in before]
    bm.normal_update()
    if textured:
        assign_uv(bm, faces, grain, (random.random(), random.random()))
    vs = {v for f in faces for v in f.verts}
    R = rot.to_4x4() if rot is not None else Matrix.Identity(4)
    for v in vs:
        v.co = R @ v.co + Vector(center)
    return faces


def to_object(bm, name, mat):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    set_material(ob, mat)
    triangulate(ob)
    finish_mesh(ob)
    return ob


# ---------------------------------------------------------------- tahta yapi
wood = new_bm()
W = 1.45          # ic yari genislik (kose direkleri)
FRONT_Y, BACK_Y = -0.10, -1.50
# zemin tahtasi
box(wood, (0, (FRONT_Y + BACK_Y) / 2, 0.025), (2 * W, FRONT_Y - BACK_Y, 0.05), grain=1)
# tezgah govdesi (dikey tahtalar) ve ustu (yatay levha)
box(wood, (0, -0.30, 0.46), (2.6, 0.50, 0.90), grain=2)
box(wood, (0, -0.31, 0.975), (2.8, 0.62, 0.05), grain=0, bevel=0.012)
# on kenar siritlari
for x in (-1.2, -0.4, 0.4, 1.2):
    box(wood, (x, 0.012, 0.46), (0.07, 0.03, 0.88), grain=2, bevel=0.006)
box(wood, (0, 0.012, 0.88), (2.6, 0.03, 0.06), grain=0, bevel=0.006)
box(wood, (0, 0.012, 0.07), (2.6, 0.03, 0.06), grain=0, bevel=0.006)
# direkler
for x in (-W, W):
    box(wood, (x, FRONT_Y, 1.23), (0.11, 0.11, 2.46), grain=2)
    box(wood, (x, BACK_Y, 1.10), (0.11, 0.11, 2.20), grain=2)
# arka duvar ve yan duvarlar (yarim boy)
box(wood, (0, BACK_Y + 0.03, 1.10), (2 * W - 0.1, 0.05, 2.15), grain=2, bevel=0.006)
for sx in (-1, 1):
    box(wood, (sx * W, (FRONT_Y + BACK_Y) / 2, 0.58), (0.05, FRONT_Y - BACK_Y - 0.12, 1.12), grain=2, bevel=0.006)
# rafalar
for z, y in ((1.40, -1.27), (1.88, -1.27)):
    box(wood, (0, y, z), (2.5, 0.42, 0.04), grain=0, bevel=0.006)
    for x in (-1.2, 0.0, 1.2):
        box(wood, (x, y + 0.02, z - 0.07), (0.05, 0.30, 0.10), grain=1, bevel=0.005)
# cati (on yuksek, arkaya egimli)
fz, bz = 2.56, 2.20
f_pt, b_pt = Vector((0, 0.20, fz)), Vector((0, -1.75, bz))
roof_len = (f_pt - b_pt).length
theta = math.atan2(f_pt.z - b_pt.z, f_pt.y - b_pt.y)
mid = (f_pt + b_pt) / 2
box(wood, tuple(mid), (3.3, roof_len, 0.07), grain=1, rot=Matrix.Rotation(theta, 3, "X"), bevel=0.01)
box(wood, (0, FRONT_Y, 2.44), (3.0, 0.10, 0.10), grain=0, bevel=0.006)
box(wood, (0, BACK_Y, 2.14), (3.0, 0.10, 0.10), grain=0, bevel=0.006)
# yer esyalari: sandik
box(wood, (-1.05, 0.55, 0.20), (0.50, 0.42, 0.40), grain=2, bevel=0.012)
box(wood, (-1.05, 0.55, 0.412), (0.52, 0.44, 0.025), grain=0, bevel=0.008)
box(wood, (-1.05, 0.55, 0.60), (0.36, 0.34, 0.34), grain=2, rot=Matrix.Rotation(0.35, 3, "Z"), bevel=0.012)

# varil (govde: 5 halka, cevresel uv)
barrel_center = Vector((1.1, 0.55, 0.0))
SEG = 14
heights = [(0.0, 0.23), (0.22, 0.29), (0.45, 0.31), (0.68, 0.29), (0.90, 0.23)]
uvl = wood.loops.layers.uv.verify()
rings = []
for h, r in heights:
    rings.append([wood.verts.new(barrel_center + Vector((r * math.cos(2 * math.pi * i / SEG),
                                                         r * math.sin(2 * math.pi * i / SEG), h))) for i in range(SEG)])
for k in range(len(rings) - 1):
    for i in range(SEG):
        j = (i + 1) % SEG
        f = wood.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
        for loop, (uu, vv) in zip(f.loops, ((i, k), (i + 1, k), (i + 1, k + 1), (i, k + 1))):
            loop[uvl].uv = (uu * 0.14 * DENS * 1.6, vv * 0.22 * DENS)
for ring, rev in ((rings[0], True), (rings[-1], False)):
    f = wood.faces.new(list(reversed(ring)) if rev else ring)
    for loop in f.loops:
        loop[uvl].uv = (0.5 + 0.3 * (loop.vert.co.x - barrel_center.x), 0.5 + 0.3 * (loop.vert.co.y - barrel_center.y))
shop_wood = to_object(wood, "ShopWood", mat_wood)

# ---------------------------------------------------------------- tente (iki renk dilim)
awn = {"A": new_bm(), "B": new_bm()}
A_pt, B_pt = Vector((0, 0.20, 2.52)), Vector((0, 1.00, 2.08))
alen = (B_pt - A_pt).length
atheta = math.atan2(B_pt.z - A_pt.z, B_pt.y - A_pt.y)
amid = (A_pt + B_pt) / 2
N = 8
sw = 3.2 / N
for i in range(N):
    key = "A" if i % 2 == 0 else "B"
    x = -1.6 + sw * (i + 0.5)
    box(awn[key], (x, amid.y, amid.z), (sw, alen, 0.015), rot=Matrix.Rotation(atheta, 3, "X"), bevel=0.002, textured=False)
    box(awn[key], (x, B_pt.y + 0.005, B_pt.z - 0.07), (sw, 0.015, 0.15), bevel=0.002, textured=False)
awn_a = to_object(awn["A"], "AwningA", mat_awn_a)
awn_b = to_object(awn["B"], "AwningB", mat_awn_b)

# ---------------------------------------------------------------- Poly Haven kova ve canak
bucket, _w = prepare_bucket(src, 0.72, body_tris=250, handle_tris=80, name="BucketProto")
bmn = bbox(bucket)[0]
bowl = import_ph(src, "wooden_bowl_02")[0]
b0, b1 = bbox(bowl)
ctr = Vector(((b0.x + b1.x) / 2, (b0.y + b1.y) / 2, b0.z))
bs = 0.21 / max(b1.x - b0.x, b1.y - b0.y)
decimate(bowl, 260)
transform_mesh(bowl, Matrix.Scale(bs, 4) @ Matrix.Translation(-ctr))
bowl.name = bowl.data.name = "BowlProto"
set_material(bowl, tex_material("ShopBowl", diffuse_path(src, "wooden_bowl_02")))
finish_mesh(bowl)


def put(proto, name, x, y, surface_z, yaw, bottom_off=0.0):
    o = proto.copy()
    o.data = proto.data            # ayni mesh (glb'de paylasilir)
    o.name = name
    bpy.context.scene.collection.objects.link(o)
    o.location = (x, y, surface_z + bottom_off)
    o.rotation_euler = (0, 0, yaw)
    return o


props = []
bkt_off = -bmn.z
top = 1.0
props.append(put(bucket, "BucketA", -0.95, -0.25, top, 0.4, bkt_off))
props.append(put(bucket, "BucketB", -0.45, -0.38, top, 2.1, bkt_off))
props.append(put(bucket, "BucketC", 0.80, -0.30, top, -0.6, bkt_off))
props.append(put(bowl, "BowlA", 0.25, -0.28, top, 0.9))
props.append(put(bowl, "BowlB", 0.52, -0.42, top, 2.4))
props.append(put(bowl, "BowlC", -0.05, -0.40, top, 4.0))
props.append(put(bucket, "BucketD", -0.55, -1.27, 1.42, 1.1, bkt_off))
props.append(put(bucket, "BucketE", 0.35, -1.25, 1.42, 3.0, bkt_off))
props.append(put(bowl, "BowlD", -0.1, -1.28, 1.42, 0.2))
props.append(put(bowl, "BowlE", 0.9, -1.27, 1.90, 1.7))
props.append(put(bowl, "BowlF", -0.9, -1.27, 1.90, 0.9))
props.append(put(bucket, "BucketG", 0.0, -1.27, 1.90, 2.5, bkt_off))
props.append(put(bucket, "BucketH", 1.40, 0.62, 0.0, 0.7, bkt_off))
props.append(put(bucket, "BucketI", -0.40, 0.72, 0.0, 2.0, bkt_off))
bpy.data.objects.remove(bucket, do_unlink=True)
bpy.data.objects.remove(bowl, do_unlink=True)

allo = [shop_wood, awn_a, awn_b] + props
bpy.context.view_layer.update()


def inst_tris(o):
    return tri_count(o)


total = sum(inst_tris(o) for o in allo)
mn = Vector((1e9,) * 3)
mx = Vector((-1e9,) * 3)
for o in allo:
    a, b = bbox(o)
    mn = Vector([min(mn[i], a[i]) for i in range(3)])
    mx = Vector([max(mx[i], b[i]) for i in range(3)])
log("UCGEN toplam", total, "yapi", tri_count(shop_wood), "tente", tri_count(awn_a) + tri_count(awn_b),
    "kutu", [round(c, 3) for c in mn], [round(c, 3) for c in mx])
if arg("--png-dir"):
    render_views(allo, arg("--png-dir"), "shop", [
        ("3q", (4.6, 5.0, 2.4), (0, -0.5, 1.15), 45),
        ("on", (0.0, 4.5, 1.6), (0, -0.5, 1.2), 50),
        ("yan", (6.0, -0.4, 1.4), (0, -0.4, 1.2), 40),
        ("arka", (-3.5, -5.0, 2.4), (0, -0.5, 1.2), 45)], res=(1000, 760), floor_z=0.0)
if arg("--glb"):
    export_glb(allo, arg("--glb"))
