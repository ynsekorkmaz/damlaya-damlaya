"""Kova tutan sag el + onkol (sap kavrayisi): MPFB insan agindan (taban ag CC0), make_hands_mpfb.py'nin yardimcilariyla.

  blender -b -P tools/blender/make_hands_grip.py -- --glb assets/models/hands_grip.glb [--png-dir klasor]

Durus (v2): kol DUZ ve sap eksenine dik (EXT derece geriligi); kodda GRIPS.rot ile kovada bilek/kol asagi doner.
Eski: el sagdaki "el sikisma" kavrayisi (basparmak ustte); dort parmak dikey bir sapin etrafinda yumruk,
basparmak parmaklarin ustunden sarar. Onkol kameraya dogru ve asagidan gelir.
Sozlesme: metre, +Y yukari (glTF); orijin kavrama noktasi (yumrugun icinden gecen sap ekseninin ortasi),
sap ekseni +Y (Blender Z), parmaklar -Z (Blender +Y) yonune bakar, onkol +Z (kameraya) ve asagi dogru.
Ten renkleri hands.glb ile ayni (make_hands_mpfb.py SKIN_*). Sap/kova bu modelde yok; kodda eklenir.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa
import bmesh  # noqa
from mathutils import Matrix, Quaternion, Vector  # noqa
import make_hands_mpfb as M  # noqa

ARGS = M.ARGS
arg = M.arg
log = M.log
GLB = arg("--glb")
PNG_DIR = arg("--png-dir")
MAX_TRIS = 4500
SIDE = "R"

EXT = float(arg("--ext", 25.0))            # onkol, sap eksenine dik duzlemden (yataydan) yukari egimi: bilek geriligi (derece)
REACH = float(arg("--reach", 0.96))        # kolun gerilme orani (1 = tam duz)
OUT = float(arg("--out", 0.10))            # onkolun yan (saga) sapmasi
CURL = {2: (72, 92, 52), 3: (76, 94, 52), 4: (80, 96, 54), 5: (84, 98, 56)}
THUMB_OUT = float(arg("--tout", 0.004))     # basparmak ucu hedefinin cembere dogru payi
THUMB_UP = float(arg("--tup", 0.012))      # basparmak ucu hedefinin yukari (isaret tarafi) payi
THUMB_BLEND = (0.75, 0.95, 1.0)
ROD_R = 0.0135                              # kontrol cubugu (yalnizca goruntu)


def pose_grip(P, F, up, left):
    side = SIDE
    s_i = -1.0
    S = P.head(f"upperarm01.{side}")
    up_b, lo_b, wr_b = f"upperarm01.{side}", f"lowerarm01.{side}", f"wrist.{side}"
    L_all = (P.head(lo_b) - S).length + (P.head(wr_b) - P.head(lo_b)).length
    ext = math.radians(EXT)
    adir = (F * math.cos(ext) + up * math.sin(ext) - left * OUT).normalized()
    W = S + adir * L_all * REACH
    pole = -up * 1.0 - left * 0.5
    Lu = (P.head(lo_b) - S).length
    Lf = (P.head(wr_b) - P.head(lo_b)).length
    d = W - S
    a = min(d.length, Lu + Lf - 1e-3)
    dn = d.normalized()
    x = (Lu * Lu - Lf * Lf + a * a) / (2 * a)
    h = math.sqrt(max(Lu * Lu - x * x, 0.0))
    perp = (pole - dn * pole.dot(dn)).normalized()
    E = S + dn * x + perp * h
    P.rot(up_b, M.aim(P.direction(up_b), E - S))
    # hedef el cercevesi: parmaklar ileri, avuc ici sola (basparmak ustte), yuzuk-isaret ekseni yukari
    n_t = left
    f_t = F
    a_t = (-n_t.cross(f_t)).normalized()
    d_f = (W - E).normalized()
    f0, n0, a0 = M.hand_frame(P, side, s_i)
    R_aim = M.aim(P.direction(lo_b), d_f)
    roll = M.signed_angle(R_aim @ n0, n_t, d_f)
    P.rot(lo_b, M.rot_axis(d_f, roll) @ R_aim)
    f1, n1, a1 = M.hand_frame(P, side, s_i)
    R3 = M.frame_matrix(f_t, n_t, a_t) @ M.frame_matrix(f1, n1, a1).inverted()
    P.rot(wr_b, R3)
    f2, n2, a2 = M.hand_frame(P, side, s_i)
    fore = (P.head(wr_b) - E).normalized()
    log("onkol egimi (yatayla, derece):", round(math.degrees(math.asin(fore.z)), 1),
        "| avuc normali . sol =", round(n2.dot(left), 3), "| bilek hata =", round((P.head(wr_b) - W).length, 4))
    return n2, f2, a2


def fist(P, n, f):
    side = SIDE
    M.close_fingers(P, side, n)
    axis = f.cross(n).normalized()   # sabit bogum ekseni (bitisik parmaklar bu eksen etrafinda duzlemsel kivrilir)
    for fi in (2, 3, 4, 5):
        meta = f"metacarpal{fi - 1}.{side}"
        if meta in P.pb:
            P.rot(meta, M.rot_axis(axis, math.radians(6.0)))
        for j in (1, 2, 3):
            nm = f"finger{fi}-{j}.{side}"
            P.rot(nm, M.rot_axis(axis, math.radians(CURL[fi][j - 1])))


def thumb(P, n, center):
    """Basparmak: isaret-orta parmagin orta kemiginin ustunden (cember disindan) sarar."""
    side = SIDE
    ax = Vector((0, 0, 1))
    # hedef: isaret parmaginin son bogumu, hafifce yukari (basparmak parmak ustune yatar) ve cembere sokulu
    j3 = P.head(f"finger2-3.{side}")
    inward = center - j3
    inward = (inward - ax * inward.dot(ax)).normalized()
    tgt_pt = j3 + ax * THUMB_UP + inward * THUMB_OUT
    for j, bl in zip((1, 2, 3), THUMB_BLEND):
        nm = f"finger1-{j}.{side}"
        want = (tgt_pt - P.head(nm)).normalized()
        q = P.direction(nm).rotation_difference(want)
        P.rot(nm, Quaternion((1, 0, 0, 0)).slerp(q, bl).to_matrix())


def fit_center(P, a_axis):
    """Parmak zincirinin (isaret-yuzuk) kavis merkezi: a_axis'e dik duzlemde cember uydurma."""
    side = SIDE
    pts = []
    for fi in (2, 3, 4):
        for j in (1, 2, 3):
            pts.append(P.head(f"finger{fi}-{j}.{side}"))
        pts.append(P.tail(f"finger{fi}-3.{side}"))
    ax = a_axis.normalized()
    t1 = ax.cross(Vector((1, 0, 0)))
    if t1.length < 1e-3:
        t1 = ax.cross(Vector((0, 1, 0)))
    t1.normalize()
    t2 = ax.cross(t1)
    xy = [(p.dot(t1), p.dot(t2)) for p in pts]
    # Kasa cember uydurma
    n = len(xy)
    sx = sum(p[0] for p in xy)
    sy = sum(p[1] for p in xy)
    sxx = sum(p[0] ** 2 for p in xy)
    syy = sum(p[1] ** 2 for p in xy)
    sxy = sum(p[0] * p[1] for p in xy)
    sz = sum(p[0] ** 2 + p[1] ** 2 for p in xy)
    sxz = sum(p[0] * (p[0] ** 2 + p[1] ** 2) for p in xy)
    syz = sum(p[1] * (p[0] ** 2 + p[1] ** 2) for p in xy)
    A = Matrix(((sxx, sxy, sx), (sxy, syy, sy), (sx, sy, n)))
    b = Vector((sxz, syz, sz))
    sol = A.inverted() @ b
    cx, cy = sol[0] / 2.0, sol[1] / 2.0
    r = math.sqrt(max(sol[2] + cx * cx + cy * cy, 0.0))
    zc = sum(P.head(f"finger{fi}-2.{side}").dot(ax) for fi in (2, 3, 4, 5)) / 4.0
    center = t1 * cx + t2 * cy + ax * zc
    return center, r


def paint_grip(obj, n_dir):
    me = obj.data
    if "Color" in me.color_attributes:
        me.color_attributes.remove(me.color_attributes["Color"])
    attr = me.color_attributes.new("Color", "FLOAT_COLOR", "POINT")
    me.color_attributes.active_color = attr
    for v in me.vertices:
        t = M.smooth(min(1.0, max(0.0, (v.normal.dot(n_dir) + 0.1) / 0.8)))
        c = [M.SKIN_BACK[i] + (M.SKIN_PALM[i] - M.SKIN_BACK[i]) * t for i in range(3)]
        attr.data[v.index].color = (c[0], c[1], c[2], 1.0)


ARM_CUT = float(arg("--armcut", 0.35))      # ust kolun dirsekten omuza dogru kesim orani


def build_arm_object(base, rig, P, final_T):
    """M.build_hand_object gibi ama ust kolun ortasina kadar: kesik uc ekranin disinda kalir."""
    side = SIDE
    M.HAND_PREFIX = ("lowerarm", "wrist", "metacarpal", "finger", "upperarm")
    deps = bpy.context.evaluated_depsgraph_get()
    ev = base.evaluated_get(deps)
    me = bpy.data.meshes.new_from_object(ev)
    keep = M.side_vertex_set(base, rig, side)
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    mw = base.matrix_world
    for v in bm.verts:
        v.co = mw @ v.co
    bm.verts.ensure_lookup_table()
    drop = [v for v in bm.verts if v.index not in keep]
    bmesh.ops.delete(bm, geom=drop, context="VERTS")
    s_h = P.head(f"upperarm01.{side}")
    e_h = P.head(f"lowerarm01.{side}")
    uvec = e_h - s_h
    cut_pt = s_h + uvec * ARM_CUT
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], dist=1e-5,
                           plane_co=cut_pt, plane_no=uvec.normalized(), clear_inner=False, clear_outer=False)
    # omuz tarafini (kesim duzleminin geri tarafi) at
    dropv = [v for v in bm.verts if (v.co - cut_pt).dot(uvec) < -1e-5]
    bmesh.ops.delete(bm, geom=dropv, context="VERTS")
    boundary = [e for e in bm.edges if len(e.link_faces) == 1]
    if boundary:
        bmesh.ops.holes_fill(bm, edges=boundary, sides=96)
    bm.verts.ensure_lookup_table()
    seen, comps = set(), []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack, comp = [v], []
        seen.add(v.index)
        while stack:
            x = stack.pop()
            comp.append(x)
            for e in x.link_edges:
                o = e.other_vert(x)
                if o.index not in seen:
                    seen.add(o.index)
                    stack.append(o)
        comps.append(comp)
    comps.sort(key=len, reverse=True)
    for c in comps[1:]:
        bmesh.ops.delete(bm, geom=c, context="VERTS")
    for v in bm.verts:
        v.co = final_T @ v.co
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    out = bpy.data.meshes.new("Arm" + side)
    bm.to_mesh(out)
    bm.free()
    bpy.data.meshes.remove(me)
    for p in out.polygons:
        p.use_smooth = True
    obj = bpy.data.objects.new("Arm" + side, out)
    bpy.context.scene.collection.objects.link(obj)
    log("kol kose", len(out.vertices), "cokgen", len(out.polygons), "bilesen", len(comps))
    return obj


def decimate_grip(obj, max_tris, center):
    total = len(obj.data.polygons)
    log("ucgen (dusurmeden once):", total)
    if total <= max_tris:
        return
    vg = obj.vertex_groups.new(name="hand")
    for v in obj.data.vertices:
        dist = (v.co - center).length
        t = M.smooth(min(1.0, max(0.0, (dist - 0.07) / 0.10)))   # el yakini 1, koldan uzaklastikca 0,15
        vg.add([v.index], 1.0 - 0.85 * t, "REPLACE")
    mod = obj.modifiers.new("dec", "DECIMATE")
    mod.ratio = max_tris / total * 0.88
    mod.vertex_group = "hand"
    mod.vertex_group_factor = 1.0
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.vertex_groups.remove(vg)
    M.triangulate(obj)
    log("ucgen (dusurunce):", len(obj.data.polygons))


def render(objs, outdir, rod):
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_WORKBENCH"
    sh = scn.display.shading
    sh.light = "STUDIO"
    sh.color_type = "VERTEX"
    sh.show_cavity = False
    scn.render.resolution_x = 900
    scn.render.resolution_y = 700
    scn.world = bpy.data.worlds.new("w")
    scn.world.color = (0.45, 0.62, 0.74)
    shots = {
        # Godot'da oyuncu bakisi: kamera onkolun arkasinda ve ustunde (Blender: -Y geri, +Z yukari)
        "fp": (Vector((0.10, -0.35, 0.18)), Vector((0.0, 0.0, -0.02)), 60),
        "side": (Vector((0.45, 0.02, 0.05)), Vector((0.0, 0.0, 0.0)), 35),
        "front": (Vector((0.0, 0.40, 0.08)), Vector((0.0, 0.0, 0.0)), 40),
        "top": (Vector((0.0, -0.005, 0.40)), Vector((0.0, 0.0, 0.0)), 25),
    }
    for key, (loc, target, fov) in shots.items():
        cam = bpy.data.cameras.new("c")
        cam.angle = math.radians(fov)
        co = bpy.data.objects.new("c", cam)
        scn.collection.objects.link(co)
        co.location = loc
        co.rotation_euler = (target - loc).to_track_quat("-Z", "Y").to_euler()
        scn.camera = co
        scn.render.filepath = f"{outdir}/grip_{key}.png"
        bpy.ops.render.render(write_still=True)
        scn.collection.objects.unlink(co)


def Rz_pre(F):
    return F.rotation_difference(Vector((0, 1, 0))).to_matrix()


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    base, rig = M.make_human()
    P = M.Posing(rig)
    up = Vector((0, 0, 1))
    fwd = P.tail("foot.L") - P.head("foot.L")
    fwd.z = 0
    F = fwd.normalized() if fwd.length > 1e-4 else Vector((0, -1, 0))
    left = up.cross(F).normalized()
    if (P.head("upperarm01.L") - P.head("upperarm01.R")).dot(left) < 0:
        left = -left
    n, f, a = pose_grip(P, F, up, left)
    fist(P, n, f)
    a_axis = up
    center, rad = fit_center(P, a_axis)
    thumb(P, n, center)
    for j in (1, 2, 3):
        log("orta parmak eklem", j, [round(c, 4) for c in (Rz_pre(F) @ (P.head(f"finger3-{j}.{SIDE}") - center))])
    log("orta parmak ucu", [round(c, 4) for c in (Rz_pre(F) @ (P.tail(f"finger3-3.{SIDE}") - center))])
    log("kavis merkezi (rig):", [round(c, 4) for c in center], "yaricap:", round(rad, 4))
    Rz = F.rotation_difference(Vector((0, 1, 0))).to_matrix().to_4x4()
    c_final = Rz @ center
    final_T = Matrix.Translation(-c_final) @ Rz
    hand = build_arm_object(base, rig, P, final_T)
    M.triangulate(hand)
    decimate_grip(hand, MAX_TRIS, Vector((0, 0, 0)))
    mat = M.make_material()
    n_dir = (final_T.to_3x3() @ n).normalized()
    paint_grip(hand, n_dir)
    hand.data.materials.append(mat)
    hand.name = hand.data.name = "HandGrip"
    bpy.data.objects.remove(base, do_unlink=True)
    bpy.data.objects.remove(rig, do_unlink=True)
    mn = Vector([min(v.co[i] for v in hand.data.vertices) for i in range(3)])
    mx = Vector([max(v.co[i] for v in hand.data.vertices) for i in range(3)])
    log("UCGEN", len(hand.data.polygons), "kutu (Blender) min", [round(c, 3) for c in mn], "max", [round(c, 3) for c in mx])
    # kontrol cubugu (yalnizca goruntu)
    rod = None
    if PNG_DIR:
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=ROD_R, radius2=ROD_R, depth=0.24)
        me = bpy.data.meshes.new("rod")
        bm.to_mesh(me)
        bm.free()
        rod = bpy.data.objects.new("rod", me)
        bpy.context.scene.collection.objects.link(rod)
        rmat = bpy.data.materials.new("rod")
        rmat.diffuse_color = (0.9, 0.2, 0.2, 1.0)
        me.materials.append(rmat)
        render([hand], PNG_DIR, rod)
        bpy.data.objects.remove(rod, do_unlink=True)
    if GLB:
        bpy.ops.object.select_all(action="DESELECT")
        hand.select_set(True)
        bpy.context.view_layer.objects.active = hand
        bpy.ops.export_scene.gltf(
            filepath=GLB, export_format="GLB", use_selection=True, export_yup=True,
            export_normals=True, export_vertex_color="ACTIVE",
            export_active_vertex_color_when_no_material=True,
            export_cameras=False, export_lights=False, export_apply=False,
            export_image_format="NONE", export_skins=False, export_animations=False)
        log("GLB yazildi:", GLB)


if __name__ == "__main__":
    main()
