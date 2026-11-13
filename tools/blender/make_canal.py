"""Kanal parcalari (straight, elbow, tee, wye, cross, aqueduct, gate, mill, reservoir) - Blender'da modellendi.
Dokular: Poly Haven CC0 (earth=brown_mud_03, wood=brown_planks_03, stone=old_stone_wall) assets/textures/canal/*.jpg.
  blender -b -P tools/blender/make_canal.py -- --tex assets/textures/canal --out assets/models/canal [--only straight,tee] [--png-dir k]
Cerceve ve kesit icin canal_common.py basina bakin. Bu betik her glb'yi sifirdan uretir.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import canal_common as cc
from canal_common import *  # noqa

cc.TEX_DIR = arg("--tex", "assets/textures/canal")
OUT = arg("--out", "assets/models/canal")
ONLY = arg("--only").split(",") if arg("--only") else None
PNG = arg("--png-dir")


def mat_channel():
    return tex_material("Channel", cc.tex_path("wood"), 0.9)


def ew_path(n=4, x0=-1.0, x1=1.0):
    return line_path((x0, 0), (x1, 0), n)


def straight_channel(name="Channel", seed=1, n=4):
    ob = sweep(name, PROFILE, ew_path(n), jitter=wobble(seed), mat=mat_channel())
    return ob


def water_straight(name="Water"):
    return water_from_slabs([sweep("ws", WATER_SLAB, ew_path(1), uv=False)], name, lambda x, y: x, lambda x, y: y)


def finish(obj):
    finish_channel(obj)


# ---------------------------------------------------------------- parcalar
def build_straight():
    ch = straight_channel()
    finish(ch)
    return [ch, water_straight()]


def build_elbow():
    path = arc_path((-1, -1), 1.0, math.pi / 2, 0.0, 8)
    ch = sweep("Channel", PROFILE, path, jitter=wobble(2), mat=mat_channel())
    finish(ch)
    w = water_from_slabs([sweep("ws", WATER_SLAB, path, uv=False)], "Water",
                         lambda x, y: math.atan2(x + 1, y + 1), lambda x, y: math.hypot(x + 1, y + 1) - 1)
    return [ch, w]


def junction(arms, flow_rule, extra_m=(), extra_c=(), extra_w=()):
    Ms = [sweep("m", MOUND, p, uv=False) for p in arms] + list(extra_m)
    Cs = [sweep("c", CUTTER, p, uv=False) for p in arms] + list(extra_c)
    M = union_all(Ms, "Channel")
    C = union_all(Cs, "cutter")
    subtract_all(M, [C])
    clip_to_cell(M)
    clean_and_bevel(M)
    world_uv(M, flow_rule)
    finish_channel(M)
    set_material(M, mat_channel())
    slabs = [sweep("ws", WATER_SLAB, p, uv=False) for p in arms] + list(extra_w)
    return M, slabs


def build_tee():
    arms = [line_path((-1.3, 0), (1.3, 0)), line_path((0, 0), (0, -1.3))]
    M, slabs = junction(arms, lambda cx, cy: 0 if abs(cx) >= abs(cy) else 1)

    def s(y):
        return smoothstep(0.1, 0.6, -y)
    w = water_from_slabs(slabs, "Water", lambda x, y: x * (1 - s(y)) + (-y) * s(y), lambda x, y: y * (1 - s(y)) + x * s(y))
    return [M, w]


def cross_vu():
    def sf(x, y):
        return smoothstep(-0.3, 0.3, abs(y) - abs(x))
    return (lambda x, y: x * (1 - sf(x, y)) + y * sf(x, y)), (lambda x, y: y * (1 - sf(x, y)) + x * sf(x, y))


def build_cross():
    arms = [line_path((-1.3, 0), (1.3, 0)), line_path((0, -1.3), (0, 1.3))]
    M, slabs = junction(arms, lambda cx, cy: 0 if abs(cx) >= abs(cy) else 1)
    vf, uf = cross_vu()
    return [M, water_from_slabs(slabs, "Water", vf, uf)]


WYE_N = 5


def build_wye():
    pn = join_paths(line_path((-1.3, 0), (-1, 0)), arc_path((-1, 1), 1.0, -math.pi / 2, 0.0, WYE_N), line_path((0, 1), (0, 1.3)))
    ps = join_paths(line_path((-1.3, 0), (-1, 0)), arc_path((-1, -1), 1.0, math.pi / 2, 0.0, WYE_N), line_path((0, -1), (0, -1.3)))
    M, slabs = junction([pn, ps], lambda cx, cy: 0 if (abs(cx + 1) >= abs(cy) * 0.8 and cx < -0.2) or abs(cy) < 0.3 else 1)
    def vf(x, y):
        return math.atan2(x + 1, 1 - y) if y >= 0 else math.atan2(x + 1, 1 + y)
    return [M, water_from_slabs(slabs, "Water", vf, lambda x, y: y)]


def build_reservoir():
    arms = [line_path((0, 0), (1.3, 0)), line_path((0, 0), (-1.3, 0)), line_path((0, 0), (0, 1.3)), line_path((0, 0), (0, -1.3))]
    rm = spin_solid("rm", [(0, -0.03), (0.95, -0.03), (0.95, 0.0), (0.93, 0.10), (0.89, 0.20), (0.85, 0.265), (0.83, 0.28), (0, 0.28)], 24, phase=math.pi / 24)
    rc = spin_solid("rc", [(0, 0.05), (0.60, 0.05), (0.63, 0.055), (0.66, 0.10), (0.66, 0.265), (0.695, 0.30), (0.695, 0.6), (0, 0.6)], 24, phase=math.pi / 24)
    rw = spin_solid("rw", [(0, 0.19), (0.655, 0.19), (0.655, 0.20), (0, 0.20)], 24, phase=math.pi / 24)
    M, slabs = junction(arms, lambda cx, cy: 0 if abs(cx) >= abs(cy) else 1, extra_m=[rm], extra_c=[rc], extra_w=[rw])
    vf, uf = cross_vu()
    return [M, water_from_slabs(slabs, "Water", vf, uf)]


# --- su kemeri
def bridge_ring(bm, y, L, b):
    ring = []
    for i, (u, h) in enumerate(PROFILE):
        if i == 0 or i == len(PROFILE) - 1:
            ring.append(bm.verts.new((u, y, b)))
        else:
            ring.append(bm.verts.new((u, y, h + L)))
    return ring


def bridge_solid(name, slices, mat):
    """slices: [(y, L, b)] ayni y'de tekrar yok; kapali kati."""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.verify()
    n = len(PROFILE)
    arc = [0.0]
    for i in range(1, n + 1):
        a, b_ = PROFILE[i - 1], PROFILE[i % n]
        arc.append(arc[-1] + math.hypot(a[0] - b_[0], a[1] - b_[1]))
    rings = [bridge_ring(bm, *s) for s in slices]
    for k in range(len(rings) - 1):
        dy0, dy1 = slices[k][0], slices[k + 1][0]
        for i in range(n):
            j = (i + 1) % n
            f = bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
            for loop, (a, b_) in zip(f.loops, ((arc[i], dy0), (arc[i + 1], dy0), (arc[i + 1], dy1), (arc[i], dy1))):
                loop[uvl].uv = (a * DENS, b_ * DENS)
    for ring in (rings[0], rings[-1]):
        f = bm.faces.new(ring)
        for loop in f.loops:
            loop[uvl].uv = (loop.vert.co.x * DENS, loop.vert.co.z * DENS)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    set_material(ob, mat)
    return ob


RAMP_RISE = 0.40
SPAN_Y = 0.5


def lift_at(y):
    t = (1 - abs(y)) / (1 - SPAN_Y)
    return RAMP_RISE * smoothstep(0.0, 1.0, t)


def build_aqueduct():
    mat = mat_channel()
    ew = sweep("Channel", PROFILE, ew_path(2), jitter=wobble(5), mat=mat)
    ys = [-1.0, -0.8, -0.65, -0.5]
    south = bridge_solid("rs", [(y, lift_at(y), -0.06) for y in ys], mat)
    span = bridge_solid("sp", [(-SPAN_Y, RAMP_RISE, RAMP_RISE - 0.05), (0.0, RAMP_RISE, RAMP_RISE - 0.05), (SPAN_Y, RAMP_RISE, RAMP_RISE - 0.05)], mat)
    north = bridge_solid("rn", [(-y, lift_at(y), -0.06) for y in reversed(ys)], mat)
    ns = join([ew, south, span, north], "Channel")
    # tek gozenek: Channel
    finish_channel(ns)
    w1 = water_from_slabs([sweep("ws", WATER_SLAB, ew_path(1), uv=False)], "Water", lambda x, y: x, lambda x, y: y)
    # NS su seridi (rampada egimli)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.verify()
    wys = [-1.0, -0.8, -0.65, -0.5, 0.0, 0.5, 0.65, 0.8, 1.0]
    rows = []
    for y in wys:
        z = WATER_Z + lift_at(y)
        rows.append((bm.verts.new((-WATER_HALF, y, z)), bm.verts.new((WATER_HALF, y, z)), y))
    for a, b in zip(rows[:-1], rows[1:]):
        f = bm.faces.new((a[0], b[0], b[1], a[1]))
        for loop in f.loops:
            loop[uvl].uv = (loop.vert.co.x, loop.vert.co.y)
        f.smooth = False
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        if f.normal.z < 0:
            f.normal_flip()
    bmesh.ops.triangulate(bm, faces=bm.faces)
    me = bpy.data.meshes.new("Water")
    bm.to_mesh(me)
    bm.free()
    w2 = bpy.data.objects.new("Water", me)
    bpy.context.scene.collection.objects.link(w2)
    me.materials.append(water_material())
    return [ns, w1, w2]


# --- savak
def build_gate():
    ch = straight_channel(seed=3)
    finish(ch)
    wood = tex_material("GateWood", cc.tex_path("wood"), 0.9)
    fr = new_bm()
    for sy in (-1, 1):
        box(fr, (0, sy * 0.335, 0.52), (0.11, 0.075, 0.74), bevel=0.01)       # direk
        box(fr, (0, sy * 0.335, 0.19), (0.17, 0.12, 0.08), bevel=0.012)       # ayak tasi/kiris
        box(fr, (-0.07, sy * 0.30, 0.50), (0.035, 0.03, 0.70), bevel=0.0)    # kilavuz tahta (oyuk kenari)
        box(fr, (0.07, sy * 0.30, 0.50), (0.035, 0.03, 0.70), bevel=0.0)
        box(fr, (0, sy * 0.335, 0.86), (0.15, 0.10, 0.06), bevel=0.01)        # baslik
    box(fr, (0, 0, 0.92), (0.14, 0.92, 0.07), grain=1, bevel=0.012)           # ust kiris
    box(fr, (0, 0, 0.80), (0.07, 0.62, 0.05), grain=1, bevel=0.008)           # alt kiris
    box(fr, (0, 0.0, 0.97), (0.05, 0.28, 0.05), grain=1, bevel=0.0)         # kol
    frame = bm_to_object(fr, "GateFrame", wood)
    pl = new_bm()
    # kapak: alt orta orijin (z=0), kapali konum, genislik 0,64, yukseklik 0,38
    box(pl, (0, 0, 0.19), (0.05, 0.64, 0.38), grain=2, bevel=0.008)
    box(pl, (0.035, 0, 0.09), (0.03, 0.64, 0.06), grain=1, bevel=0.0)
    box(pl, (0.035, 0, 0.29), (0.03, 0.64, 0.06), grain=1, bevel=0.0)
    box(pl, (0, 0, 0.405), (0.07, 0.20, 0.05), grain=1, bevel=0.0)          # tutamak
    gate = bm_to_object(pl, "Gate", wood)
    gate.location = (0, 0, 0.05)
    bpy.context.view_layer.update()
    return [ch, water_straight(), frame, gate]


# --- degirmen
def build_mill():
    ch = straight_channel(seed=4)
    finish(ch)
    mwood = tex_material("MillWood", cc.tex_path("wood"), 0.9)
    mstone = tex_material("MillStone", cc.tex_path("stone"), 0.95)
    random.seed(11)
    Y0, Y1 = 0.55, 1.20
    YC = (Y0 + Y1) / 2
    st = new_bm()
    box(st, (0, YC, 0.45), (2.2, Y1 - Y0, 0.90), bevel=0.035)
    box(st, (0, YC, 0.93), (2.28, Y1 - Y0 + 0.08, 0.06), bevel=0.02)         # saray silmesi
    box(st, (0.78, 1.00, 2.45), (0.24, 0.24, 0.70), bevel=0.02)             # baca
    box(st, (-0.55, Y0 - 0.12, 0.08), (0.45, 0.16, 0.16), bevel=0.02)       # basamak
    stone = bm_to_object(st, "MillStoneBody", mstone)
    wd = new_bm()
    box(wd, (0, YC, 1.43), (2.0, Y1 - Y0 - 0.1, 1.0), bevel=0.012)           # ust katin duvari
    for sx in (-1.0, -0.33, 0.33, 1.0):
        box(wd, (sx, Y0 - 0.005, 1.43), (0.09, 0.06, 1.02), bevel=0.01)      # kiris dikmeler on
        box(wd, (sx, Y1 + 0.005, 1.43), (0.09, 0.06, 1.02), bevel=0.01)
    box(wd, (0, Y0 - 0.005, 0.97), (2.05, 0.06, 0.07), grain=0, bevel=0.01)
    box(wd, (0, Y0 - 0.005, 1.93), (2.05, 0.06, 0.07), grain=0, bevel=0.01)
    box(wd, (0, Y1 + 0.005, 1.93), (2.05, 0.06, 0.07), grain=0, bevel=0.01)
    # capraz destek
    for sx in (-0.67, 0.67):
        box(wd, (sx, Y0 - 0.005, 1.45), (0.07, 0.05, 1.15), bevel=0.008, rot=Matrix.Rotation(0.75 if sx < 0 else -0.75, 3, "Y"))
    # cati (iki egimli levha, mahya X boyunca)
    ridge_z, eave_z, half = 2.70, 1.95, 0.60
    dz, dy = ridge_z - eave_z, half
    L = math.hypot(dy, dz) + 0.12
    th = math.atan2(dz, dy)
    box(wd, (0, YC - half / 2 - 0.03, (ridge_z + eave_z) / 2 + 0.03), (2.34, L, 0.07), grain=0, bevel=0.012, rot=Matrix.Rotation(th, 3, "X"))
    box(wd, (0, YC + half / 2 + 0.03, (ridge_z + eave_z) / 2 + 0.03), (2.34, L, 0.07), grain=0, bevel=0.012, rot=Matrix.Rotation(-th, 3, "X"))
    box(wd, (0, YC, ridge_z + 0.05), (2.36, 0.10, 0.08), grain=0, bevel=0.015)
    # alin ucgenleri (x=+-1.0)
    uvl = wd.loops.layers.uv.verify()
    for sx in (-1.0, 1.0):
        pts = [(Y0 + 0.05, 1.93), (Y1 - 0.05, 1.93), (YC, ridge_z)]
        vs = [wd.verts.new((sx, y, z)) for y, z in pts]
        f = wd.faces.new(vs if sx > 0 else vs[::-1])
        for loop in f.loops:
            loop[uvl].uv = (loop.vert.co.y * DENS, loop.vert.co.z * DENS)
    # kapi (bati yuz) ve pencere (guney yuz)
    box(wd, (-1.03, YC, 0.37), (0.05, 0.34, 0.74), grain=2, bevel=0.01)
    box(wd, (-1.045, YC, 0.78), (0.06, 0.42, 0.06), grain=1, bevel=0.01)
    for wx in (-0.55, 0.62):
        box(wd, (wx, Y0 - 0.03, 1.48), (0.34, 0.04, 0.34), bevel=0.01)
        box(wd, (wx - 0.24, Y0 - 0.035, 1.48), (0.14, 0.03, 0.34), bevel=0.008)
        box(wd, (wx + 0.24, Y0 - 0.035, 1.48), (0.14, 0.03, 0.34), bevel=0.008)
    # cuval tasima kirisi (kuzey cati ucu) ve sandik
    box(wd, (0.3, Y1 + 0.08, 2.08), (0.07, 0.22, 0.07), grain=1, bevel=0.008)
    box(wd, (-0.7, Y0 - 0.15, 0.10), (0.22, 0.22, 0.20), bevel=0.012)
    # tekerlek destegi: guney banka dayali
    box(wd, (0, -0.335, 0.52), (0.12, 0.08, 0.84), bevel=0.01)
    box(wd, (0, -0.335, 0.12), (0.2, 0.14, 0.12), bevel=0.012)
    box(wd, (0, -0.335, 0.95), (0.14, 0.10, 0.06), bevel=0.01)
    box(wd, (0, Y0 - 0.05, 0.62), (0.14, 0.12, 0.14), bevel=0.01)          # yatak
    body = bm_to_object(wd, "MillWoodBody", mwood)
    # cark: eksen Y (glb'de Z), orijin cark ekseninde
    wb = new_bm()
    CZ = 0.64
    R_OUT, R_IN = 0.50, 0.43
    rim = spin_solid("rim", [(R_IN, -0.02), (R_OUT, -0.02), (R_OUT, 0.02), (R_IN, 0.02)], 16)
    hub = spin_solid("hub", [(0.0, -0.17), (0.085, -0.17), (0.085, 0.17), (0.0, 0.17)], 10)
    ax = spin_solid("axle", [(0.0, -0.50), (0.04, -0.50), (0.04, 0.62), (0.0, 0.62)], 8)
    parts = []
    for ob, off in ((rim, -0.19), (rim, 0.19)):
        pass
    bpy.data.objects.remove(rim, do_unlink=True)

    def spin_part(prof, y_off, steps):
        o = spin_solid("p", prof, steps)
        # spin yapi Z ekseni; Y eksenine cevir
        o.data.transform(Matrix.Rotation(-math.pi / 2, 4, "X"))
        o.data.transform(Matrix.Translation((0, y_off, 0)))
        parts.append(o)
    spin_part([(R_IN, -0.02), (R_OUT, -0.02), (R_OUT, 0.02), (R_IN, 0.02)], -0.19, 16)
    spin_part([(R_IN, -0.02), (R_OUT, -0.02), (R_OUT, 0.02), (R_IN, 0.02)], 0.19, 16)
    spin_part([(0.0, -0.17), (0.085, -0.17), (0.085, 0.17), (0.0, 0.17)], 0.0, 10)
    spin_part([(0.0, -0.50), (0.04, -0.50), (0.04, 0.62), (0.0, 0.62)], 0.0, 8)
    bpy.data.objects.remove(hub, do_unlink=True)
    bpy.data.objects.remove(ax, do_unlink=True)
    for k in range(12):
        a = 2 * math.pi * k / 12
        rot = Matrix.Rotation(a, 3, "Y")       # X-Z duzleminde don
        box(wb, rot @ Vector((0.47, 0, 0)), (0.13, 0.40, 0.025), grain=1, bevel=0.0, rot=rot)
    for side in (-0.19, 0.19):
        for k in range(8):
            a = 2 * math.pi * (k + 0.5) / 8
            rot = Matrix.Rotation(a, 3, "Y")
            c = rot @ Vector((0.26, 0, 0)) + Vector((0, side, 0))
            box(wb, c, (0.36, 0.04, 0.035), grain=0, bevel=0.0, rot=rot)
    wheel_a = bm_to_object(wb, "wheel_a", mwood)
    allw = join([wheel_a] + parts, "Wheel")
    for p in allw.data.polygons:
        p.use_smooth = True
    set_material(allw, mwood)
    world_uv_cyl = None  # spin parcalari icin dunya izdusumu
    bmx = bmesh.new()
    bmx.from_mesh(allw.data)
    bmx.normal_update()
    uvx = bmx.loops.layers.uv.verify()
    for f in bmx.faces:
        if all(l[uvx].uv.length == 0 for l in f.loops):
            n = f.normal
            dom = max(range(3), key=lambda a: abs(n[a]))
            t = [a for a in range(3) if a != dom]
            for l in f.loops:
                l[uvx].uv = (l.vert.co[t[0]] * DENS * 1.5, l.vert.co[t[1]] * DENS * 1.5)
    bmx.to_mesh(allw.data)
    bmx.free()
    allw.data.transform(Matrix.Translation((0, 0, CZ)))
    center_origin_at(allw, (0, 0, CZ))
    bpy.context.view_layer.update()
    return [ch, water_straight(), stone, body, allw]


BUILDERS = {
    "straight": build_straight, "elbow": build_elbow, "tee": build_tee, "wye": build_wye, "cross": build_cross,
    "aqueduct": build_aqueduct, "gate": build_gate, "mill": build_mill, "reservoir": build_reservoir,
}
BUDGET = {"straight": 500, "elbow": 500, "tee": 500, "wye": 500, "cross": 500, "aqueduct": 900, "gate": 900,
          "mill": 4000, "reservoir": 1200}

if __name__ == "__main__":
    for pid, fn in BUILDERS.items():
        if ONLY and pid not in ONLY:
            continue
        reset()
        import tool_common
        tool_common._WATER_MAT = None
        random.seed(3)
        objs = fn()
        for o in objs:
            o.data.update()
        bpy.context.view_layer.update()
        tris, mn, mx = stats(objs)
        log("PARCA", pid, "ucgen", tris, "/", BUDGET[pid], "kutu", mn, mx, "nesneler", [o.name for o in objs])
        if arg("--glb-dir", OUT):
            export_glb(objs, os.path.join(OUT, pid + ".glb"))
        if PNG:
            render_views(objs, PNG, pid, [("ust", (0.0, -1.6, 3.0), (0, 0, 0.1), 45)], res=(700, 700), floor_z=0.0)
