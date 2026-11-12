"""Avuc (iki el + onkol) ve su hacmi uretici. Blender 5.x, arka planda:

  blender -b -P tools/blender/make_hands.py -- --glb assets/models/hands.glb [--png-dir klasor]

Yontem: her el ve onkol metaball kuresi zincirlerinden (avuc tabani, parmaklar, bas parmak, onkol)
olusur; mesh'e cevrilir, normaller disa cevrilir, Decimate ile hedef ucgen sayisina indirilir.
Sahne Z-yukari (Blender); glTF disa aktarimi +Y yukari yapar: Blender +Y (parmak ucu) -> glTF -Z.
Model orijini iki bilegin ortasi. Olcu: metre.
"""
import math
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

# ---------------------------------------------------------------- ayarlar
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    return ARGS[ARGS.index(name) + 1] if name in ARGS else default


GLB = arg("--glb")
PNG_DIR = arg("--png-dir")
TARGET_TRIS_PER_HAND = 2500   # iki el ~5200 + su ~200 < 6000

META_RES = 0.0017             # metaball cozunurlugu (m)
SURF_K = 0.55                 # tek kure icin yuzey yaricapi / eleman yaricapi
ROLL_DEG = 30.0               # bas parmak tarafi yukari yatis (cukur V)
YAW_DEG = 16.0                # parmaklar ice dogru
HAND_SHIFT_X = 0.0385         # serce kenarlari ortada birlesir
RIGHT_LIFT_Z = 0.009          # sag el parmaklari solun ustune biner
CURL = [12.0, 28.0, 30.0]     # eklem basina kivrilma (derece), toplam ~86

SKIN_BACK = (0.74, 0.55, 0.44)
SKIN_PALM = (0.82, 0.64, 0.53)
SKIN_TIP = (0.80, 0.58, 0.48)

# parmak: (x, bogum y, uzunluk, taban yaricap)
FINGERS = [
    (-0.03525, 0.080, 0.062, 0.0105),   # serce
    (-0.01175, 0.088, 0.079, 0.0110),   # yuzuk
    (0.01175, 0.090, 0.086, 0.0112),    # orta
    (0.03525, 0.087, 0.078, 0.0110),    # isaret
]


# ---------------------------------------------------------------- geometri
def smooth(t):
    return t * t * (3 - 2 * t)


def finger_chain(x, y0, length, radius, z0=0.0):
    """Parmak: (y,z) duzleminde kivrilan, uca dogru ince kure zinciri. Yaricaplar yuzey yaricapi."""
    pts = []
    seg = [0.40, 0.33, 0.27]
    pos = Vector((x, y0, z0))
    ang = 0.0
    for s in range(3):
        ang += math.radians(CURL[s])
        d = Vector((0.0, math.cos(ang), math.sin(ang)))
        seglen = length * seg[s]
        steps = max(3, int(seglen / (radius * 0.55)))
        for i in range(steps):
            t = (s + i / steps) / 3.0
            r = radius * (1.0 - 0.12 * t)
            pts.append((pos + d * (seglen * i / steps), r))
        pos = pos + d * seglen
    # yuvarlak uc
    pts.append((pos, radius * 0.86))
    return pts


def dish_z(x, y):
    """Avuc tabani yuksekligi: ortada cukur."""
    return -0.004 + 0.0 * x


def build_hand_points(finger_yaw=0.0, finger_lift=0.0):
    """Sag el (bas parmak +X), avuc yukari (+Z), parmaklar +Y. Yerel uzay, bilek orijinde."""
    balls = []
    # avuc tabani: yassi, ortasi cukur
    for iy in range(0, 8):
        y = -0.004 + iy * 0.0125
        for ix in range(-3, 4):
            x = ix * 0.0135
            # ortada cukur: kenarlar ve on kenar biraz yuksek
            edge = abs(x) / 0.0405
            front = max(0.0, (y - 0.05) / 0.045)
            z = -0.012 + 0.012 * edge * edge + 0.006 * front
            balls.append((Vector((x, y, z)), 0.0155))
    # baslica tumsekler (dolgun): bas parmak koku, serce tarafi
    for i in range(4):
        t = i / 3.0
        balls.append((Vector((0.030 - 0.004 * t, 0.012 + 0.030 * t, 0.002 + 0.004 * t)), 0.0185 - 0.003 * t))
    for i in range(3):
        t = i / 2.0
        balls.append((Vector((-0.036, 0.020 + 0.050 * t, -0.002)), 0.0145))
    # bilek
    for i in range(3):
        balls.append((Vector((0.0, -0.014 - i * 0.012, -0.012)), 0.0265))
    # parmaklar (taban avuc on kenarindan baslar)
    fy = Matrix.Rotation(math.radians(finger_yaw), 3, "Z")
    pivot = Vector((0.0, 0.085, 0.0))
    for (x, y0, length, r) in FINGERS:
        for p, rr in finger_chain(x, y0, length, r, z0=-0.002):
            balls.append((fy @ (p - pivot) + pivot + Vector((0.0, 0.0, finger_lift)), rr))
    # bas parmak: koku tumsekte, disa dogru sonra ileri/yukari kivrilir, isaretin yanina yaslanir
    thumb = [
        (0.038, 0.018, -0.002, 0.0140), (0.049, 0.034, 0.002, 0.0133),
        (0.056, 0.050, 0.006, 0.0125), (0.058, 0.066, 0.011, 0.0118),
        (0.057, 0.080, 0.016, 0.0112), (0.055, 0.091, 0.022, 0.0106),
        (0.052, 0.099, 0.028, 0.0100),
    ]
    prev = None
    for (x, y, z, r) in thumb:
        p = Vector((x, y, z))
        if prev is not None:
            n = 3
            for k in range(1, n):
                balls.append((prev[0].lerp(p, k / n), prev[1] + (r - prev[1]) * k / n))
        balls.append((p, r))
        prev = (p, r)
    return balls


def build_forearm(wrist, direction, length, r0, r1):
    balls = []
    n = int(length / (r0 * 0.7))
    for i in range(n + 1):
        t = i / n
        balls.append((wrist + direction * (length * t), r0 + (r1 - r0) * smooth(t) * 0.9 + (r1 - r0) * 0.1 * t))
    return balls


def place_hand(balls, mirror):
    roll = Matrix.Rotation(math.radians(-ROLL_DEG), 3, "Y")
    shift = Vector((HAND_SHIFT_X, 0.0, 0.0))
    out = []
    for p, r in balls:
        q = roll @ p + shift
        out.append((q, r))
    # canak dibi: iki avucun birlestigi yeri kapatan orta serit
    sz = 0.0
    for i in range(9):
        out.append((Vector((0.001, 0.0 + i * 0.011, -0.021 + sz)), 0.0150))
    # onkol: bilekten geriye, disa ve asagi
    wrist = roll @ Vector((0.0, -0.012, -0.012)) + shift
    d = Vector((0.20, -0.93, -0.30)).normalized()
    out += build_forearm(wrist + d * 0.02, d, 0.29, 0.0262, 0.0375)
    if mirror:
        out = [(Vector((-p.x, p.y, p.z)), r) for p, r in out]
    return out


# ---------------------------------------------------------------- Blender
def make_meta(name, balls):
    mb = bpy.data.metaballs.new(name)
    mb.resolution = META_RES
    mb.render_resolution = META_RES
    mb.threshold = 0.6
    for p, r in balls:
        e = mb.elements.new(type="BALL")
        e.co = p
        e.radius = r / SURF_K
        e.stiffness = 2.0
    obj = bpy.data.objects.new(name, mb)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def to_mesh(obj):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    return bpy.context.view_layer.objects.active


def finish_mesh(obj, target_tris):
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    tris = len(me.polygons)
    if tris > target_tris:
        mod = obj.modifiers.new("dec", "DECIMATE")
        mod.ratio = target_tris / tris
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    # normaller disa baksin (merkeze gore degil, hacim isaretine gore)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()


def paint(obj):
    """Vertex color: normali yukari bakan (avuc ici) acik, sirt koyu; parmak ucu hafif pembe."""
    me = obj.data
    if "Color" in me.color_attributes:
        me.color_attributes.remove(me.color_attributes["Color"])
    attr = me.color_attributes.new("Color", "FLOAT_COLOR", "POINT")
    me.color_attributes.active_color = attr
    for v in me.vertices:
        nz = v.normal.z
        t = smooth(min(1.0, max(0.0, (nz + 0.1) / 0.8)))
        c = [SKIN_BACK[i] + (SKIN_PALM[i] - SKIN_BACK[i]) * t for i in range(3)]
        # parmak ucu: ileri (+Y) ve yukari kivrik bolge
        if v.co.y > 0.15:
            k = min(1.0, (v.co.y - 0.15) / 0.05) * 0.5
            c = [c[i] + (SKIN_TIP[i] - c[i]) * k for i in range(3)]
        attr.data[v.index].color = (c[0], c[1], c[2], 1.0)


def make_material():
    mat = bpy.data.materials.new("Skin")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    col = nt.nodes.new("ShaderNodeVertexColor")
    col.layer_name = "Color"
    nt.links.new(col.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    return mat


def make_water():
    """Alt yari elipsoid, ustu duz; orijin alt orta; z in [0,H]."""
    rx, ry, h = 0.035, 0.040, 0.026
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=12, radius=1.0)
    for v in bm.verts:
        z = v.co.z
        v.co = Vector((v.co.x * rx, v.co.y * ry, (min(z, 0.0) * h) + h))
        if z > 0.0:
            v.co.z = h
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("Water")
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = False
    obj = bpy.data.objects.new("Water", me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mat = make_material()
    objs = []
    for name, mirror in (("HandR", False), ("HandL", True)):
        meta = make_meta(name, place_hand(build_hand_points(YAW_DEG if not mirror else 0.0, RIGHT_LIFT_Z if not mirror else 0.0), mirror))
        mesh_obj = to_mesh(meta)
        mesh_obj.name = name
        finish_mesh(mesh_obj, TARGET_TRIS_PER_HAND)
        paint(mesh_obj)
        mesh_obj.data.materials.append(mat)
        objs.append(mesh_obj)
    water = make_water()
    # bowl ic boslugu: bilekten ileri, cukur tabaninin biraz ustu
    water.location = Vector((0.0, 0.092, WATER_BASE_Z))
    wmat = bpy.data.materials.new("Water")
    wmat.diffuse_color = (0.55, 0.78, 0.92, 1.0)
    water.data.materials.append(wmat)
    tris = sum(len(o.data.polygons) for o in objs) + len(water.data.polygons)
    print("UCGEN_TOPLAM", tris, [len(o.data.polygons) for o in objs], "su", len(water.data.polygons))

    if PNG_DIR:
        render(objs + [water], PNG_DIR)
    if GLB:
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs + [water]:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.export_scene.gltf(
            filepath=GLB, export_format="GLB", use_selection=True, export_yup=True,
            export_normals=True, export_vertex_color="ACTIVE",
            export_active_vertex_color_when_no_material=True,
            export_cameras=False, export_lights=False, export_apply=False,
            export_image_format="NONE")
        print("GLB yazildi:", GLB)


WATER_BASE_Z = -0.016


def render(objs, outdir):
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_WORKBENCH"
    sh = scn.display.shading
    sh.light = "STUDIO"
    sh.color_type = "VERTEX"
    sh.show_cavity = False
    scn.render.resolution_x = 1100
    scn.render.resolution_y = 760
    scn.render.film_transparent = False
    scn.world = bpy.data.worlds.new("w")
    scn.world.color = (0.45, 0.62, 0.74)
    # su: saydam goruntu icin workbench'te alfa yok; ayri tur
    shots = {
        "fp": (Vector((0.0, -0.35, 0.25)), Vector((0.0, 0.09, 0.0)), 70),
        "top": (Vector((0.0, 0.02, 0.75)), Vector((0.0, 0.05, 0.0)), 35),
        "side": (Vector((0.5, 0.05, 0.1)), Vector((0.0, 0.05, 0.0)), 35),
    }
    for key, (loc, target, fov) in shots.items():
        cam = bpy.data.cameras.new("c")
        cam.angle = math.radians(fov)
        co = bpy.data.objects.new("c", cam)
        scn.collection.objects.link(co)
        co.location = loc
        co.rotation_euler = (target - loc).to_track_quat("-Z", "Y").to_euler()
        scn.camera = co
        for variant in ("", "_nosu"):
            for o in objs:
                if o.name == "Water":
                    o.hide_render = (variant == "_nosu")
            scn.render.filepath = f"{outdir}/blender_{key}{variant}.png"
            bpy.ops.render.render(write_still=True)
        scn.collection.objects.unlink(co)


main()
