"""hands_grip.glb'ye sol eli ekler: sag elin X aynasi, "GripL" nesnesi (yuz sarimi ters cevrilir, normaller yeniden hesaplanir).
make_hands_grip.py once sag eli uretir; bu betik ayni glb'yi okuyup uzerine yazar (tekrar calistirilirsa eski GripL atilir).
  blender -b -P tools/blender/make_hands_grip_mirror.py -- --glb assets/models/hands_grip.glb [--png-dir klasor]
Sag el nesnesi "Grip" adini alir; ikisi de ayni glb'de iki ayri mesh dugumu olur.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    return ARGS[ARGS.index(name) + 1] if name in ARGS else default


GLB = arg("--glb", "assets/models/hands_grip.glb")
PNG = arg("--png-dir")


def mirrored(ob, name):
    out = ob.copy()
    out.data = ob.data.copy()
    out.name = out.data.name = name
    bpy.context.scene.collection.objects.link(out)
    bm = bmesh.new()
    bm.from_mesh(out.data)
    for v in bm.verts:
        v.co.x = -v.co.x
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.normal_update()
    bm.to_mesh(out.data)
    bm.free()
    out.data.update()
    return out


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=GLB)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    right = [o for o in meshes if o.name in ("HandGrip", "Grip")]
    if not right:
        raise RuntimeError("sag el nesnesi yok")
    right = right[0]
    for o in meshes:
        if o is not right:
            bpy.data.objects.remove(o, do_unlink=True)
    right.name = right.data.name = "Grip"
    left = mirrored(right, "GripL")
    print("[ARAC] sag", len(right.data.polygons), "sol", len(left.data.polygons), "ucgen")
    bpy.ops.object.select_all(action="DESELECT")
    for o in (right, left):
        o.select_set(True)
    bpy.context.view_layer.objects.active = right
    bpy.ops.export_scene.gltf(
        filepath=GLB, export_format="GLB", use_selection=True, export_yup=True,
        export_normals=True, export_vertex_color="ACTIVE",
        export_active_vertex_color_when_no_material=True,
        export_cameras=False, export_lights=False, export_apply=False,
        export_image_format="NONE", export_skins=False, export_animations=False)
    print("[ARAC] GLB yazildi:", GLB, os.path.getsize(GLB))


main()
