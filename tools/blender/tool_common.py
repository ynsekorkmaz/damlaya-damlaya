"""Alet ve dukkan modelleri icin ortak Blender (5.x) yardimcilari.

Kullanim (her make_*.py icinden):
  blender -b -P tools/blender/make_tool_bucket.py -- --src <indirilen_klasor> --glb assets/models/tools/bucket.glb [--png-dir klasor]

--src: Poly Haven dosyalarinin acildigi klasor; icinde varlik adiyla alt klasorler olur
  (wooden_bucket_01/wooden_bucket_01.gltf + .bin + textures/..._diff_1k.jpg).
Indirme adresleri (CC0, Poly Haven):
  https://dl.polyhaven.org/file/ph-assets/Models/gltf/1k/<id>/<id>_1k.gltf
  https://dl.polyhaven.org/file/ph-assets/Models/gltf/8k/<id>/<id>.bin   (gltf'in .bin dosyasi)
  https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/<id>/<id>_diff_1k.jpg
  https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/<id>/<id>_diff_1k.jpg (doku varliklari)
Yalnizca diffuse (base color) dokusu kullanilir; normal/roughness/arm indirilmez.

Sozlesme: birim metre, glTF +Y yukari; Blender'da Z yukari, aletin "onu" Blender +Y (glTF -Z).
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    return ARGS[ARGS.index(name) + 1] if name in ARGS else default


def log(*a):
    print("[ARAC]", *a, flush=True)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


# ------------------------------------------------------------ iceri aktarma
def import_ph(src, asset):
    """Poly Haven gltf'i ice aktar; mesh nesneleri, ebeveynsiz, donusumleri uygulanmis (Blender Z yukari)."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(src, asset, asset + ".gltf"))
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
    return meshes


def diffuse_path(src, asset):
    folder = os.path.join(src, asset)
    textures = os.path.join(folder, "textures")
    if os.path.isdir(textures):
        folder = textures
    for f in os.listdir(folder):
        if "_diff_" in f:
            return os.path.join(folder, f)
    raise FileNotFoundError(asset)


# ------------------------------------------------------------ mesh yardimcilari
def tri_count(obj):
    me = obj.data
    me.calc_loop_triangles()
    return len(me.loop_triangles)


def total_tris(objs):
    return sum(tri_count(o) for o in objs)


def transform_mesh(obj, matrix):
    obj.data.transform(matrix)
    obj.data.update()


def triangulate(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()


def decimate(obj, target_tris):
    triangulate(obj)
    cur = len(obj.data.polygons)
    if cur <= target_tris:
        return
    mod = obj.modifiers.new("dec", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = target_tris / cur
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)


def finish_mesh(obj):
    """Normaller disa, yumusak gosterim."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    for p in obj.data.polygons:
        p.use_smooth = True
    obj.data.update()


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    out = bpy.context.view_layer.objects.active
    out.name = name
    out.data.name = name
    return out


def duplicate(obj, name, loc=(0, 0, 0), rot_z=0.0):
    o = obj.copy()
    o.data = obj.data.copy()
    o.name = name
    o.data.name = name
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = (0, 0, rot_z)
    return o


def bake_object_transform(obj):
    """Nesne donusumunu mesh'e isle (orijin sahnede 0,0,0 kalir)."""
    transform_mesh(obj, obj.matrix_world)
    obj.location = (0, 0, 0)
    obj.rotation_euler = (0, 0, 0)
    obj.scale = (1, 1, 1)


def bbox(obj):
    mw = obj.matrix_world
    pts = [mw @ v.co for v in obj.data.vertices]
    mn = Vector([min(p[i] for p in pts) for i in range(3)])
    mx = Vector([max(p[i] for p in pts) for i in range(3)])
    return mn, mx


# ------------------------------------------------------------ malzeme
def tex_material(name, image_path, roughness=0.9):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    img = bpy.data.images.load(image_path)
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.extension = "REPEAT"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = 0.0
    return mat


def color_material(name, rgb, roughness=0.9):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = 0.0
    mat.diffuse_color = (rgb[0], rgb[1], rgb[2], 1.0)
    return mat


def set_material(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


# ------------------------------------------------------------ su
_WATER_MAT = None


def water_material():
    global _WATER_MAT
    if _WATER_MAT is None or _WATER_MAT.name not in bpy.data.materials:
        _WATER_MAT = color_material("WaterMat", (0.55, 0.78, 0.92), 0.1)
    return _WATER_MAT


def make_water(name, r_bottom, r_top, height, loc, segs=16):
    """Duz ustlu kesik koni; orijin alt orta, yukseklik 0..height (Blender Z)."""
    bm = bmesh.new()
    bot = [bm.verts.new((r_bottom * math.cos(2 * math.pi * i / segs),
                         r_bottom * math.sin(2 * math.pi * i / segs), 0.0)) for i in range(segs)]
    top = [bm.verts.new((r_top * math.cos(2 * math.pi * i / segs),
                         r_top * math.sin(2 * math.pi * i / segs), height)) for i in range(segs)]
    for i in range(segs):
        j = (i + 1) % segs
        bm.faces.new((bot[i], bot[j], top[j], top[i]))
    bm.faces.new(list(reversed(bot)))
    bm.faces.new(top)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    triangulate_mesh = bmesh.new()
    triangulate_mesh.from_mesh(me)
    bmesh.ops.triangulate(triangulate_mesh, faces=triangulate_mesh.faces)
    triangulate_mesh.to_mesh(me)
    triangulate_mesh.free()
    for p in me.polygons:
        p.use_smooth = False
    me.materials.append(water_material())
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = loc
    return obj


# ------------------------------------------------------------ olcum (kabin ici)
def make_bvh(obj):
    deps = bpy.context.evaluated_depsgraph_get()
    return BVHTree.FromObject(obj, deps)


def interior_floor_z(bvh, top_z, probes=((0.02, 0.01), (-0.02, 0.015), (0.015, -0.02), (-0.01, -0.02))):
    zs = []
    for x, y in probes:
        hit = bvh.ray_cast(Vector((x, y, top_z + 0.2)), Vector((0, 0, -1)))
        if hit[0] is not None:
            zs.append(hit[0].z)
    return sum(zs) / len(zs)


def interior_radius(bvh, z, n=16, max_r=1.0):
    """Eksenden (0,0,z) disa isin atilir; ilk carpisma ic duvardir; ortalama yaricap."""
    rs = []
    for i in range(n):
        a = 2 * math.pi * i / n
        d = Vector((math.cos(a), math.sin(a), 0.0))
        hit = bvh.ray_cast(Vector((0, 0, z)), d, max_r)
        if hit[0] is not None:
            rs.append((hit[0] - Vector((0, 0, z))).length)
    return sum(rs) / len(rs), min(rs)


def interior_top_z(bvh, z_from, z_to, step=0.004, min_hits=6):
    """Ic duvarin vardigi en yuksek z (ustte ray ilk kez bos gectigi yerin hemen alti)."""
    z, last = z_from, z_from
    while z <= z_to:
        hits = 0
        for i in range(8):
            a = 2 * math.pi * i / 8
            if bvh.ray_cast(Vector((0, 0, z)), Vector((math.cos(a), math.sin(a), 0.0)), 1.0)[0] is not None:
                hits += 1
        if hits >= min_hits:
            last = z
        z += step
    return last


# ------------------------------------------------------------ kova hazirligi
def prepare_bucket(src, scale, body_tris, handle_tris, name="Bucket"):
    """wooden_bucket_01: govde+kulp tek mesh, orijin kulbun ust orta noktasi, olcekli.
    Doner: (nesne, su_olculeri) ; su_olculeri = dict(r_bottom, r_top, height, z_floor) (nesne uzayinda, metre)."""
    objs = import_ph(src, "wooden_bucket_01")
    body = [o for o in objs if not o.name.endswith("_handle")][0]
    handle = [o for o in objs if o.name.endswith("_handle")][0]
    # olcum (govde, olceklenmemis)
    bvh = make_bvh(body)
    floor_z = interior_floor_z(bvh, bbox(body)[1].z)
    rim_z = interior_top_z(bvh, floor_z + 0.02, bbox(body)[1].z)
    r_a = interior_radius(bvh, floor_z + 0.02)[1]
    r_b = interior_radius(bvh, rim_z - 0.004)[1]
    top_z = bbox(handle)[1].z
    log("kova olcum (ham): rim", round(rim_z, 3), "taban", round(floor_z, 3), "r_alt", round(r_a, 3),
        "r_ust", round(r_b, 3), "kulp_ust", round(top_z, 3))
    decimate(body, body_tris)
    decimate(handle, handle_tris)
    obj = join([body, handle], name)
    M = Matrix.Scale(scale, 4) @ Matrix.Translation(Vector((0, 0, -top_z)))
    transform_mesh(obj, M)
    set_material(obj, tex_material("WoodBucket", diffuse_path(src, "wooden_bucket_01")))
    finish_mesh(obj)
    water = dict(r_bottom=r_a * scale * 0.95, r_top=r_b * scale * 0.95,
                 height=(rim_z - 0.015 - floor_z) * scale, z_floor=(floor_z - top_z) * scale,
                 rim_z=(rim_z - top_z) * scale)
    return obj, water


# ------------------------------------------------------------ disa aktarma
def export_glb(objs, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_yup=True,
        export_normals=True, export_texcoords=True, export_materials="EXPORT",
        export_image_format="AUTO", export_cameras=False, export_lights=False,
        export_apply=False, export_skins=False, export_animations=False)
    log("GLB yazildi:", path, os.path.getsize(path), "bayt")


# ------------------------------------------------------------ onizleme
def render_views(objs, outdir, name, views, res=(900, 700), floor=True, floor_z=None):
    """views: [(etiket, kamera_konumu, hedef, fov_derece)]; konumlar mutlak (Blender)."""
    os.makedirs(outdir, exist_ok=True)
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_WORKBENCH"
    sh = scn.display.shading
    sh.light = "STUDIO"
    sh.color_type = "TEXTURE"
    sh.show_cavity = False
    sh.show_object_outline = False
    sh.show_shadows = True
    sh.shadow_intensity = 0.35
    scn.render.resolution_x, scn.render.resolution_y = res
    scn.render.film_transparent = False
    scn.world = bpy.data.worlds.new("w")
    scn.world.color = (0.5, 0.5, 0.5)
    if floor:
        mn = Vector((1e9, 1e9, 1e9))
        mx = Vector((-1e9, -1e9, -1e9))
        for o in objs:
            a, b = bbox(o)
            mn = Vector([min(mn[i], a[i]) for i in range(3)])
            mx = Vector([max(mx[i], b[i]) for i in range(3)])
        z0 = mn.z if floor_z is None else floor_z
        bm = bmesh.new()
        S = 6.0
        vs = [bm.verts.new(p) for p in ((-S, -S, z0 - 0.002), (S, -S, z0 - 0.002), (S, S, z0 - 0.002), (-S, S, z0 - 0.002))]
        bm.faces.new(vs)
        me = bpy.data.meshes.new("floor")
        bm.to_mesh(me)
        bm.free()
        fo = bpy.data.objects.new("floor", me)
        scn.collection.objects.link(fo)
        fo.data.materials.append(color_material("floorMat", (0.55, 0.55, 0.55)))
    for label, loc, target, fov in views:
        cam = bpy.data.cameras.new("c")
        cam.angle = math.radians(fov)
        cam.clip_start = 0.01
        co = bpy.data.objects.new("c", cam)
        scn.collection.objects.link(co)
        co.location = Vector(loc)
        co.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        scn.camera = co
        scn.render.filepath = os.path.join(outdir, f"{name}_{label}.png")
        bpy.ops.render.render(write_still=True)
        scn.collection.objects.unlink(co)
    log("goruntuler:", outdir)
