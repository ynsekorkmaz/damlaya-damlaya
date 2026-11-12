"""Avuc (iki el + onkol) ve su hacmi: MPFB (MakeHuman, taban ag CC0) insan agindan. Blender 5.x:

  blender -b -P tools/blender/make_hands_mpfb.py -- --glb assets/models/hands.glb [--png-dir klasor]

Gereken: MPFB eklentisi (extensions.blender.org, v2.0.18; kullanici eklentisi "user_default").
Akis: varsayilan insan -> varsayilan iskelet -> kollar (iki kemikli IK ile) ve parmaklar kemik
donusleriyle avuc durusuna -> poz uygulanmis ag -> sadece onkol+el -> dirsek altindan kes, kapat
-> vertex color -> glb. Sahne cikisi: metre, +Y yukari (glTF), parmak uclari -Z, orijin bileklerin ortasi.
Not: bu betik avuc durusunu uretir; MPFB'nin insan aginin kendisi CC0'dir (base.obj basligi).
"""
import math
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    return ARGS[ARGS.index(name) + 1] if name in ARGS else default


GLB = arg("--glb")
PNG_DIR = arg("--png-dir")
MAX_TRIS_TOTAL = 7200          # iki el + onkol (su disinda)

# ---- durus ayarlari (derece / metre) ----
WRIST_X = 0.036                # her bilek orta cizgiden
FORWARD = 0.30                 # omuzdan bilege ileri
DROP = 0.12                    # omuzdan bilege asagi
TOP_LIFT = 0.014               # ustteki elin ek yuksekligi
BOWL_ROLL = 22.0               # avuc ici ice yatis (cukur)
HAND_PITCH = 8.0               # el bilekte yukari
YAW_TOP = 26.0                 # ustteki el parmaklari ice cok
YAW_BOT = 4.0
CUT_FRAC = 0.30                # dirsekten kesme (onkol boyunun orani)
CURL = {2: (20, 32, 20), 3: (22, 36, 22), 4: (25, 40, 24), 5: (28, 42, 26)}
META_CURL = 6.0
TOP_SIDE = "L"

SKIN_BACK = (0.74, 0.55, 0.44)
SKIN_PALM = (0.82, 0.64, 0.53)
SKIN_TIP = (0.80, 0.58, 0.48)


def log(*a):
    print("[MPFB]", *a, flush=True)


def smooth(t):
    return t * t * (3.0 - 2.0 * t)


# ---------------------------------------------------------------- insan
def make_human():
    try:
        bpy.ops.preferences.addon_enable(module="bl_ext.user_default.mpfb")
    except Exception as e:  # zaten acik olabilir
        log("addon_enable:", e)
    from bl_ext.user_default.mpfb.services.humanservice import HumanService
    from bl_ext.user_default.mpfb.services.rigservice import RigService
    base = HumanService.create_human(mask_helpers=False)
    rig = HumanService.add_builtin_rig(base, "default_no_toes", import_weights=True)
    if not any(m.type == "ARMATURE" for m in base.modifiers):
        RigService.ensure_armature_modifier(base, rig)
    bpy.context.view_layer.update()
    log("insan:", base.name, len(base.data.vertices), "kose; iskelet:", rig.name, len(rig.pose.bones), "kemik")
    log("iskelet donusu:", [round(x, 4) for x in rig.matrix_world.translation], rig.matrix_world.to_scale())
    return base, rig


# ---------------------------------------------------------------- poz
class Posing:
    def __init__(self, rig):
        self.rig = rig
        self.aw = rig.matrix_world.copy()
        self.pb = rig.pose.bones

    def head(self, name):
        return self.aw @ self.pb[name].head

    def tail(self, name):
        return self.aw @ self.pb[name].tail

    def direction(self, name):
        return (self.tail(name) - self.head(name)).normalized()

    def rot(self, name, R3, pivot=None):
        """R3 (dunya uzayi 3x3) donusunu kemige uygula (pivot: dunya uzayi, varsayilan kemik basi)."""
        pb = self.pb[name]
        pv = self.head(name) if pivot is None else pivot
        T = Matrix.Translation(pv) @ R3.to_4x4() @ Matrix.Translation(-pv)
        pb.matrix = self.aw.inverted() @ T @ (self.aw @ pb.matrix)
        bpy.context.view_layer.update()


def aim(a, b):
    return a.normalized().rotation_difference(b.normalized()).to_matrix()


def signed_angle(a, b, axis):
    a = (a - axis * a.dot(axis)).normalized()
    b = (b - axis * b.dot(axis)).normalized()
    ang = a.angle(b)
    return ang if a.cross(b).dot(axis) >= 0 else -ang


def rot_axis(axis, ang):
    return Matrix.Rotation(ang, 3, axis)


def hand_frame(P, side, s_i):
    """(f, n, a): parmak yonu, avuc ici normali, serceden isarete."""
    wr = P.head(f"wrist.{side}")
    f = (P.head(f"finger3-1.{side}") - wr).normalized()
    a = (P.head(f"finger2-1.{side}") - P.head(f"finger5-1.{side}")).normalized()
    a = (a - f * a.dot(f)).normalized()
    n = f.cross(a) if side == "L" else -f.cross(a)
    return f, n.normalized(), a


def target_frame(F, up, left, s_i, yaw_deg):
    """Hedef (f, n, a). s_i: +1 sol el (merkezin soluna), -1 sag."""
    n = (up * math.cos(math.radians(BOWL_ROLL)) - left * s_i * math.sin(math.radians(BOWL_ROLL))).normalized()
    f = (F * math.cos(math.radians(HAND_PITCH)) + up * math.sin(math.radians(HAND_PITCH)))
    f = (f - n * f.dot(n)).normalized()
    # parmaklar merkeze dogru yaw (n etrafinda): hangi isaret merkeze yaklastirir?
    inward = -left * s_i
    for sg in (1, -1):
        f2 = rot_axis(n, sg * math.radians(yaw_deg)) @ f
        if f2.dot(inward) > f.dot(inward):
            f = f2
            break
    a = n.cross(f) if s_i > 0 else -n.cross(f)
    return f, n, a.normalized()


def frame_matrix(f, n, a):
    return Matrix((f, n, a)).transposed()


def pose_arm(P, side, F, up, left, wrist_target, yaw_deg, pole):
    s_i = 1.0 if side == "L" else -1.0
    up_b = f"upperarm01.{side}"
    lo_b = f"lowerarm01.{side}"
    wr_b = f"wrist.{side}"
    S = P.head(up_b)
    Lu = (P.head(lo_b) - S).length
    Lf = (P.head(wr_b) - P.head(lo_b)).length
    # iki kemikli IK: dirsek konumu
    d = wrist_target - S
    a = d.length
    a = min(a, Lu + Lf - 1e-3)
    dn = d.normalized()
    x = (Lu * Lu - Lf * Lf + a * a) / (2 * a)
    h = math.sqrt(max(Lu * Lu - x * x, 0.0))
    perp = (pole - dn * pole.dot(dn)).normalized()
    E = S + dn * x + perp * h
    # ust kol
    P.rot(up_b, aim(P.direction(up_b), E - S))
    # on kol: hedef yone cevir + avuc normaline gore roll
    f_t, n_t, a_t = target_frame(F, up, left, s_i, yaw_deg)
    d_f = (wrist_target - E).normalized()
    f0, n0, a0 = hand_frame(P, side, s_i)
    R_aim = aim(P.direction(lo_b), d_f)
    n_aim = R_aim @ n0
    roll = signed_angle(n_aim, n_t, d_f)
    P.rot(lo_b, rot_axis(d_f, roll) @ R_aim)
    # bilek: eli hedef cercevesine
    f1, n1, a1 = hand_frame(P, side, s_i)
    R3 = frame_matrix(f_t, n_t, a_t) @ frame_matrix(f1, n1, a1).inverted()
    P.rot(wr_b, R3)
    f2, n2, a2 = hand_frame(P, side, s_i)
    log(side, "avuc normali . yukari =", round(n2.dot(up), 3), "| parmak . ileri =", round(f2.dot(F), 3),
        "| bilek konumu hata =", round((P.head(wr_b) - wrist_target).length, 4), "| dirsek =", [round(c, 3) for c in E])
    return n2, f2, a2


def close_fingers(P, side, n):
    """Parmaklari orta parmaga paralel ve bitisik yap (avuc duzleminde n etrafinda)."""
    ref = P.direction(f"finger3-1.{side}")
    for fi in (2, 4, 5):
        nm = f"finger{fi}-1.{side}"
        d = P.direction(nm)
        ang = signed_angle(d, ref, n)
        P.rot(nm, rot_axis(n, ang * 0.95))
        if fi in (4, 5):  # yuzuk/serce biraz daha iceri (orta parmaga yasla)
            P.rot(f"metacarpal{fi - 1}.{side}", rot_axis(n, ang * 0.15))


def curl_fingers(P, side, n, f_dir, s_i):
    close_fingers(P, side, n)
    for fi in (2, 3, 4, 5):
        meta = f"metacarpal{fi - 1}.{side}"
        if meta in P.pb:
            d = P.direction(meta)
            P.rot(meta, rot_axis(d.cross(n).normalized(), math.radians(META_CURL)))
        for j in (1, 2, 3):
            nm = f"finger{fi}-{j}.{side}"
            d = P.direction(nm)
            axis = d.cross(n).normalized()
            P.rot(nm, rot_axis(axis, math.radians(CURL[fi][j - 1])))
    # bas parmak: isaret parmagina yaslan (n etrafinda), hafif kivrim
    plan = {1: (16.0, 6.0), 2: (4.0, 16.0), 3: (0.0, 14.0)}
    for j in (1, 2, 3):
        nm = f"finger1-{j}.{side}"
        yaw, cu = plan[j]
        d = P.direction(nm)
        tgt = P.direction(f"finger2-1.{side}")
        sg = 1.0 if d.cross(tgt).dot(n) > 0 else -1.0
        P.rot(nm, rot_axis(n, sg * math.radians(yaw)))
        d = P.direction(nm)
        P.rot(nm, rot_axis(d.cross(n).normalized(), math.radians(cu)))


# ---------------------------------------------------------------- mesh
HAND_PREFIX = ("lowerarm", "wrist", "metacarpal", "finger")


def side_vertex_set(base, rig, side):
    bone_names = {b.name for b in rig.data.bones}
    gname = {vg.index: vg.name for vg in base.vertex_groups}
    keep = set()
    for v in base.data.vertices:
        best, bw = None, 0.0
        for g in v.groups:
            nm = gname.get(g.group)
            if nm in bone_names and g.weight > bw:
                best, bw = nm, g.weight
        if best and best.endswith("." + side) and best.startswith(HAND_PREFIX):
            keep.add(v.index)
    return keep


def build_hand_object(base, rig, P, side, final_T):
    deps = bpy.context.evaluated_depsgraph_get()
    ev = base.evaluated_get(deps)
    me = bpy.data.meshes.new_from_object(ev)
    keep = side_vertex_set(base, rig, side)
    assert len(me.vertices) == len(base.data.vertices), "kose sayisi degisti (mask?)"
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    mw = base.matrix_world
    for v in bm.verts:
        v.co = mw @ v.co
    drop = [v for v in bm.verts if v.index not in keep]
    bmesh.ops.delete(bm, geom=drop, context="VERTS")
    # dirsegin biraz alti
    lo_h = P.head(f"lowerarm01.{side}")
    wr_h = P.head(f"wrist.{side}")
    dvec = (wr_h - lo_h)
    cut_pt = lo_h + dvec * CUT_FRAC
    res = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], dist=1e-5,
                                 plane_co=cut_pt, plane_no=dvec.normalized(), clear_inner=True)
    boundary = [e for e in bm.edges if len(e.link_faces) == 1]
    if boundary:
        bmesh.ops.holes_fill(bm, edges=boundary, sides=96)
    # kucuk kopuk parcalari at: en buyuk bagli bileseni tut
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
    nm = "Hand" + side
    out = bpy.data.meshes.new(nm)
    bm.to_mesh(out)
    bm.free()
    bpy.data.meshes.remove(me)
    for p in out.polygons:
        p.use_smooth = True
    obj = bpy.data.objects.new(nm, out)
    bpy.context.scene.collection.objects.link(obj)
    log(nm, "kose", len(out.vertices), "cokgen", len(out.polygons), "bilesen", len(comps))
    return obj


def triangulate(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    for p in obj.data.polygons:
        p.use_smooth = True


def decimate_to(objs, max_total):
    total = sum(len(o.data.polygons) for o in objs)
    log("ucgen (dusurmeden once):", total)
    if total <= max_total:
        return
    ratio = max_total / total
    for o in objs:
        # parmaklarda ayrinti: el bolgesi (bilekten ileri, y > bilek) agirlik 1, onkol 0
        vg = o.vertex_groups.new(name="hand")
        ys = [v.co.y for v in o.data.vertices]
        ymin, ymax = min(ys), max(ys)
        for v in o.data.vertices:
            t = smooth(min(1.0, max(0.0, (v.co.y - (-0.05)) / 0.05)))
            vg.add([v.index], 0.15 + 0.85 * t, "REPLACE")
        mod = o.modifiers.new("dec", "DECIMATE")
        mod.ratio = ratio * 0.85
        mod.vertex_group = "hand"
        mod.vertex_group_factor = 1.0
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=mod.name)
        o.vertex_groups.remove(vg)
        triangulate(o)
    log("ucgen (dusurunce):", sum(len(o.data.polygons) for o in objs))


def paint(obj):
    me = obj.data
    if "Color" in me.color_attributes:
        me.color_attributes.remove(me.color_attributes["Color"])
    attr = me.color_attributes.new("Color", "FLOAT_COLOR", "POINT")
    me.color_attributes.active_color = attr
    for v in me.vertices:
        nz = v.normal.z
        t = smooth(min(1.0, max(0.0, (nz + 0.1) / 0.8)))
        c = [SKIN_BACK[i] + (SKIN_PALM[i] - SKIN_BACK[i]) * t for i in range(3)]
        if v.co.y > 0.14:
            k = min(1.0, (v.co.y - 0.14) / 0.05) * 0.5
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


WATER_RX = 0.040
WATER_RY = 0.044
WATER_H = 0.026


def make_water(loc):
    rx, ry, h = WATER_RX, WATER_RY, WATER_H
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
    for p in me.polygons:
        p.use_smooth = False
    obj = bpy.data.objects.new("Water", me)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = loc
    wmat = bpy.data.materials.new("Water")
    wmat.diffuse_color = (0.55, 0.78, 0.92, 1.0)
    me.materials.append(wmat)
    return obj


# ---------------------------------------------------------------- ana
def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    base, rig = make_human()
    P = Posing(rig)
    up = Vector((0, 0, 1))
    fwd = P.tail("foot.L") - P.head("foot.L")
    fwd.z = 0
    F = fwd.normalized() if fwd.length > 1e-4 else Vector((0, -1, 0))
    left = up.cross(F).normalized()
    log("ileri yon:", [round(c, 3) for c in F], "sol:", [round(c, 3) for c in left],
        "sol omuz x:", round(P.head("upperarm01.L").x, 3))
    # sol (+left) omuz gercekten sol tarafta mi
    if (P.head("upperarm01.L") - P.head("upperarm01.R")).dot(left) < 0:
        left = -left
        log("sol yon cevrildi")
    S_mid = (P.head("upperarm01.L") + P.head("upperarm01.R")) * 0.5
    frames = {}
    wrist_t = {}
    for side in ("L", "R"):
        s_i = 1.0 if side == "L" else -1.0
        W = S_mid + left * (s_i * WRIST_X) + F * FORWARD + up * (-DROP + (TOP_LIFT if side == TOP_SIDE else 0.0))
        wrist_t[side] = W
        pole = -up * 1.0 + left * s_i * 0.35 - F * 0.4
        yaw = YAW_TOP if side == TOP_SIDE else YAW_BOT
        n, f, a = pose_arm(P, side, F, up, left, W, yaw, pole)
        curl_fingers(P, side, n, f, s_i)
        frames[side] = (n, f, a)
    # nihai donusum: F -> +Y, bilek ortasi orijin
    Rz = F.rotation_difference(Vector((0, 1, 0))).to_matrix().to_4x4()
    mid = Rz @ ((P.head("wrist.L") + P.head("wrist.R")) * 0.5)
    final_T = Matrix.Translation(-mid) @ Rz
    objs = [build_hand_object(base, rig, P, s, final_T) for s in ("R", "L")]
    # su konumu: avuc kemiklerinin ortasi
    pts = [final_T @ P.head(f"metacarpal{i}.{s}") for i in (1, 2, 3, 4) for s in ("L", "R")]
    cen = sum(pts, Vector()) / len(pts)
    log("avuc merkezi (metacarpal basi ort.):", [round(c, 4) for c in cen])
    tip = [final_T @ P.tail(f"finger{i}-3.{s}") for i in (2, 3, 4, 5) for s in ("L", "R")]
    tc = sum(tip, Vector()) / len(tip)
    log("parmak ucu ort.:", [round(c, 4) for c in tc])
    water_loc = Vector((0.0, float(arg("--wy", 0.060)), float(arg("--wz", 0.002))))

    # cok yuksek cozunurluklu ag: ucgenle, dusur
    for o in objs:
        triangulate(o)
    decimate_to(objs, MAX_TRIS_TOTAL)
    mat = make_material()
    for o in objs:
        paint(o)
        o.data.materials.append(mat)
    water = make_water(water_loc)
    # insan ve iskeleti at
    bpy.data.objects.remove(base, do_unlink=True)
    bpy.data.objects.remove(rig, do_unlink=True)
    tris = [len(o.data.polygons) for o in objs]
    log("UCGEN_TOPLAM", sum(tris), tris, "su", len(water.data.polygons))
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
            export_image_format="NONE", export_skins=False, export_animations=False)
        log("GLB yazildi:", GLB)


def render(objs, outdir):
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_WORKBENCH"
    sh = scn.display.shading
    sh.light = "STUDIO"
    sh.color_type = "VERTEX"
    sh.show_cavity = False
    scn.render.resolution_x = 1100
    scn.render.resolution_y = 760
    scn.world = bpy.data.worlds.new("w")
    scn.world.color = (0.45, 0.62, 0.74)
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
            scn.render.filepath = f"{outdir}/mp_{key}{variant}.png"
            bpy.ops.render.render(write_still=True)
        scn.collection.objects.unlink(co)


main()
