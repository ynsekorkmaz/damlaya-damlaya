"""Kanal parcalari icin ortak Blender (5.x) yardimcilari.
Cerceve: Blender X = Dogu, +Y = Kuzey, +Z yukari. glb'ye aktarilinca (Y-yukari) Kuzey = -Z, Guney = +Z olur
(canal_pieces.gd ile ayni). Hucre 2 m x 2 m, orijin hucre merkezi, zemin z=0.
Kesit (ortak, her parcada ayni): dis genislik 0,9 (foot +-0,45), kenar tepesi z=0,28, ic genislik 0,6 (+-0,30),
oluk tabani z=0,05, su yuzeyi z=0,20.
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tool_common import *  # noqa

DENS = 0.8          # doku yogunlugu: metre basina 0,8 doku
CELL = 1.0          # hucre yari boyu
WATER_Z = 0.20
WATER_HALF = 0.299

# Tam kesit (soldan saga, alt-sol kosesinden alt-sag kosesine). (u, h)
PROFILE_HALF = [(-0.45, -0.06), (-0.45, 0.0), (-0.43, 0.10), (-0.395, 0.20), (-0.36, 0.265), (-0.34, 0.28),
                (-0.315, 0.28), (-0.30, 0.265), (-0.30, 0.10), (-0.27, 0.055), (-0.24, 0.05)]
PROFILE = PROFILE_HALF + [(-u, h) for (u, h) in reversed(PROFILE_HALF)]
# Tepe dolgusu (kenar seti, oluk dolu) ve oluk kesici
MOUND = [(-0.45, -0.06), (-0.45, 0.0), (-0.43, 0.10), (-0.395, 0.20), (-0.36, 0.265), (-0.34, 0.28)]
MOUND = MOUND + [(-u, h) for (u, h) in reversed(MOUND)]
CUT_HALF = [(-0.335, 0.60), (-0.335, 0.30), (-0.30, 0.265), (-0.30, 0.10), (-0.27, 0.055), (-0.24, 0.05)]
CUTTER = CUT_HALF + [(-u, h) for (u, h) in reversed(CUT_HALF)]
WATER_SLAB = [(-WATER_HALF, 0.19), (WATER_HALF, 0.19), (WATER_HALF, WATER_Z), (-WATER_HALF, WATER_Z)]

MOUTHS = {  # 0 derecede agiz yonleri (canal_pieces.gd). Blender: N=+Y, E=+X, S=-Y, W=-X
    "straight": "EW", "elbow": "WS", "tee": "WES", "wye": "WNS", "cross": "NESW",
    "gate": "EW", "mill": "EW", "aqueduct": "NESW", "reservoir": "NESW",
}
DIRV = {"N": (0, 1), "E": (1, 0), "S": (0, -1), "W": (-1, 0)}

TEX_DIR = None


def tex_path(name):
    return os.path.join(TEX_DIR, name + ".jpg")


# ---------------------------------------------------------------- yollar
def line_path(p0, p1, n=1):
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    L = math.hypot(dx, dy)
    tx, ty = dx / L, dy / L
    return [(p0[0] + dx * i / n, p0[1] + dy * i / n, tx, ty) for i in range(n + 1)]


def arc_path(center, R, a0, a1, n):
    """Aci a0'dan a1'e (radyan); nokta = c + R(cos a, sin a); teget yonu a1>a0 ise saat yonu tersi."""
    sgn = 1.0 if a1 > a0 else -1.0
    out = []
    for i in range(n + 1):
        a = a0 + (a1 - a0) * i / n
        out.append((center[0] + R * math.cos(a), center[1] + R * math.sin(a), -sgn * math.sin(a), sgn * math.cos(a)))
    return out


def join_paths(*paths):
    out = []
    for p in paths:
        for pt in p:
            if out and abs(out[-1][0] - pt[0]) < 1e-9 and abs(out[-1][1] - pt[1]) < 1e-9:
                continue
            out.append(pt)
    return out


# ---------------------------------------------------------------- tarama (sweep)
def sweep(name, poly, path, caps=True, jitter=None, mat=None, uv=True, bottom_faces=True):
    """poly: kapali kesit (u,h) (u sola dogru +). path: [(x,y,tx,ty)]. Kapali kati cisim doner (Blender nesnesi)."""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.verify()
    rings = []
    n = len(poly)
    # kesit yay uzunlugu (doku icin)
    arc = [0.0]
    for i in range(1, n + 1):
        a, b = poly[i - 1], poly[i % n]
        arc.append(arc[-1] + math.hypot(a[0] - b[0], a[1] - b[1]))
    dist = [0.0]
    for i in range(1, len(path)):
        dist.append(dist[-1] + math.hypot(path[i][0] - path[i - 1][0], path[i][1] - path[i - 1][1]))
    for k, (x, y, tx, ty) in enumerate(path):
        jt = jitter(k, len(path)) if jitter else None
        ring = []
        for i, (u, h) in enumerate(poly):
            uu, hh = u, h
            if jt:
                side = 0 if u < 0 else 1
                if abs(u) > 0.33:
                    uu = u * (1 + jt[side][0])
                if h >= 0.255:
                    hh = h + jt[side][1]
            # sol normal = (-ty, tx); u negatif = sag taraf degil: u pozitif sola
            ring.append(bm.verts.new((x - ty * uu, y + tx * uu, hh)))
        rings.append(ring)
    for k in range(len(rings) - 1):
        for i in range(n):
            if i == n - 1 and not bottom_faces:
                continue
            j = (i + 1) % n
            try:
                f = bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
            except ValueError:
                continue
            if uv:
                for loop, (a, b) in zip(f.loops, ((arc[i], dist[k]), (arc[i + 1], dist[k]),
                                                  (arc[i + 1], dist[k + 1]), (arc[i], dist[k + 1]))):
                    loop[uvl].uv = (a * DENS, b * DENS)
    if caps:
        for ring in (rings[0], rings[-1]):
            f = bm.faces.new(ring)
            if uv:
                for loop in f.loops:
                    loop[uvl].uv = (loop.vert.co.x * DENS, loop.vert.co.z * DENS)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if mat:
        set_material(ob, mat)
    return ob


def spin_solid(name, prof_rz, steps=24, phase=0.0):
    """(r,z) kesitini Z ekseni etrafinda cevirir; kapali kati."""
    bm = bmesh.new()
    vs = [bm.verts.new((r, 0.0, z)) for r, z in prof_rz]
    es = [bm.edges.new((vs[i], vs[(i + 1) % len(vs)])) for i in range(len(vs))]
    bmesh.ops.spin(bm, geom=vs + es, axis=(0, 0, 1), cent=(0, 0, 0), angle=2 * math.pi, steps=steps)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    if phase:
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(phase, 3, 'Z'), verts=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def box_solid(name, lo, hi):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector(((hi[0] + lo[0]) / 2 + v.co.x * (hi[0] - lo[0]),
                       (hi[1] + lo[1]) / 2 + v.co.y * (hi[1] - lo[1]),
                       (hi[2] + lo[2]) / 2 + v.co.z * (hi[2] - lo[2])))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


# ---------------------------------------------------------------- boolean
def bool_apply(target, other, op):
    m = target.modifiers.new("b", "BOOLEAN")
    m.operation = op
    m.solver = "EXACT"
    m.object = other
    bpy.ops.object.select_all(action="DESELECT")
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.modifier_apply(modifier=m.name)


def union_all(objs, name):
    base = objs[0]
    for o in objs[1:]:
        bool_apply(base, o, "UNION")
        bpy.data.objects.remove(o, do_unlink=True)
    base.name = name
    base.data.name = name
    return base


def subtract_all(base, cutters):
    for c in cutters:
        bool_apply(base, c, "DIFFERENCE")
        bpy.data.objects.remove(c, do_unlink=True)


def clip_to_cell(obj):
    box = box_solid("clipbox", (-CELL, -CELL, -1.0), (CELL, CELL, 3.0))
    bool_apply(obj, box, "INTERSECT")
    bpy.data.objects.remove(box, do_unlink=True)


def on_mouth_plane(co, tol=2e-4):
    return abs(abs(co.x) - CELL) < tol or abs(abs(co.y) - CELL) < tol


def clean_and_bevel(obj, bevel=0.02, angle_deg=50.0):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=bm.edges)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    verts = [v for v in bm.verts if not on_mouth_plane(v.co)]
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(0.6), verts=verts, edges=[e for e in bm.edges if not any(on_mouth_plane(v.co) for v in e.verts)],
                             use_dissolve_boundaries=False)
    bm.normal_update()
    th = math.radians(angle_deg)
    edges = []
    for e in bm.edges:
        if len(e.link_faces) != 2:
            continue
        if any(on_mouth_plane(v.co) for v in e.verts):
            continue
        if all(v.co.z < -0.05 for v in e.verts):
            continue
        if e.calc_face_angle(0.0) > th:
            edges.append(e)
    if edges and bevel > 0:
        bmesh.ops.bevel(bm, geom=edges, offset=bevel, offset_type="OFFSET", segments=2, profile=0.5,
                        affect="EDGES", clamp_overlap=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def world_uv(obj, flow_rule):
    """Dunya olcekli izdusum. flow_rule(cx, cy) -> 0 (akis X) ya da 1 (akis Y)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()
    uvl = bm.loops.layers.uv.verify()
    for f in bm.faces:
        c = f.calc_center_median()
        fl = flow_rule(c.x, c.y)
        p = 1 - fl
        n = f.normal
        dom = max(range(3), key=lambda a: abs(n[a]))
        for loop in f.loops:
            co = loop.vert.co
            if dom == 2:
                u, v = co[p], co[fl]
            elif dom == fl:
                u, v = co[p], co[2]
            else:
                u, v = co[2], co[fl]
            loop[uvl].uv = (u * DENS, v * DENS)
    bm.to_mesh(obj.data)
    bm.free()


def finish_channel(obj, sharp_deg=50.0):
    """Yumusak gosterim; keskin kenarlar (alt, kapaklar) sert."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    th = math.radians(sharp_deg)
    for e in bm.edges:
        if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > th:
            e.smooth = False
        else:
            e.smooth = True
    for f in bm.faces:
        f.smooth = True
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


# ---------------------------------------------------------------- su
def water_from_slabs(slabs, name, vfunc, ufunc):
    """Ince plakalarin birlesiminden ust yuzu cikarir; UV: V akis yonunde."""
    w = union_all(slabs, name) if len(slabs) > 1 else slabs[0]
    clip_to_cell(w)
    bm = bmesh.new()
    bm.from_mesh(w.data)
    bm.normal_update()
    drop = [f for f in bm.faces if f.normal.z < 0.9]
    bmesh.ops.delete(bm, geom=drop, context="FACES_ONLY")
    loose_e = [e for e in bm.edges if not e.link_faces]
    bmesh.ops.delete(bm, geom=loose_e, context="EDGES")
    loose_v = [v for v in bm.verts if not v.link_edges]
    bmesh.ops.delete(bm, geom=loose_v, context="VERTS")
    for v in bm.verts:
        v.co.z = WATER_Z
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(0.6), verts=bm.verts, edges=bm.edges)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    uvl = bm.loops.layers.uv.verify()
    for f in bm.faces:
        f.smooth = False
        for loop in f.loops:
            x, y = loop.vert.co.x, loop.vert.co.y
            loop[uvl].uv = (ufunc(x, y), vfunc(x, y))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(w.data)
    bm.free()
    w.data.materials.clear()
    w.data.materials.append(water_material())
    w.name = name
    w.data.name = name
    return w


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def wobble(seed):
    rnd = random.Random(seed)

    def j(k, n):
        if k == 0 or k == n - 1:
            return None
        return [(rnd.uniform(-0.012, 0.0), rnd.uniform(-0.012, 0.0)),
                (rnd.uniform(-0.012, 0.0), rnd.uniform(-0.012, 0.0))]
    return j


# ---------------------------------------------------------------- yapi kutulari (tahta/tas)
def new_bm():
    bm = bmesh.new()
    bm.loops.layers.uv.verify()
    return bm


def assign_uv_box(bm, faces, grain, off, dens=DENS):
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
            loop[uv].uv = (u * dens + off[0], v * dens + off[1])


def box(bm, center, size, grain=2, rot=None, bevel=0.008, dens=DENS):
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
    assign_uv_box(bm, faces, grain, (random.random(), random.random()), dens)
    vs = {v for f in faces for v in f.verts}
    R = rot.to_4x4() if rot is not None else Matrix.Identity(4)
    for v in vs:
        v.co = R @ v.co + Vector(center)
    return faces


def bm_to_object(bm, name, mat, smooth=True):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    set_material(ob, mat)
    triangulate(ob)
    if smooth:
        finish_mesh(ob)
    return ob


def center_origin_at(obj, point):
    """Nesne konumunu 'point'e tasir (mesh dunyada ayni kalir)."""
    p = Vector(point)
    obj.data.transform(Matrix.Translation(-p))
    obj.location = p
    obj.data.update()


def stats(objs):
    mn = Vector((1e9,) * 3)
    mx = Vector((-1e9,) * 3)
    for o in objs:
        a, b = bbox(o)
        mn = Vector([min(mn[i], a[i]) for i in range(3)])
        mx = Vector([max(mx[i], b[i]) for i in range(3)])
    return total_tris(objs), [round(c, 3) for c in mn], [round(c, 3) for c in mx]
