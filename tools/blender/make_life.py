"""Balik ve kus (Blender de sifirdan modellendi; disaridan varlik/indirme yok, lisans sorunu yok).
  blender -b -P tools/blender/make_life.py -- --out assets/models/life
Sozlesme: metre, glTF +Y yukari, bas -Z (Blender +Y), orijin govde ortasi. Yalnizca vertex color (doku yok).
Balik: boy ~0,5 m; kuyruk +Z ucunda (golgelendirici bu eksene gore sallar). Kus: kanat acikligi 1 m, kanatlar +-X.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tool_common import arg, log, total_tris  # noqa

OUT = arg("--out", "assets/models/life")


def new_mesh(name, bm, smooth):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    me.update()
    return me


def loft(bm, stations, segs, color_fn, nose_color):
    """stations: [(y, rx, rz)], ilki burun noktasi; yuzler dis normal."""
    col = bm.verts.layers.float_color["Color"]
    nose = bm.verts.new((0.0, stations[0][0], 0.0))
    nose[col] = nose_color
    prev = None
    for k, (y, rx, rz) in enumerate(stations[1:], start=1):
        ring = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            v = bm.verts.new((math.cos(a) * rx, y, math.sin(a) * rz))
            v[col] = color_fn(a, y, k)
            ring.append(v)
        if prev is None:
            for i in range(segs):
                bm.faces.new((nose, ring[(i + 1) % segs], ring[i]))
        else:
            for i in range(segs):
                j = (i + 1) % segs
                bm.faces.new((prev[i], prev[j], ring[j], ring[i]))
        prev = ring
    bm.faces.new(list(reversed(prev)))


def poly(bm, pts, colors):
    col = bm.verts.layers.float_color["Color"]
    vs = []
    for p, c in zip(pts, colors):
        v = bm.verts.new(p)
        v[col] = c
        vs.append(v)
    bm.faces.new(vs)


def build_fish():
    bm = bmesh.new()
    bm.verts.layers.float_color.new("Color")
    back = Vector((0.95, 0.40, 0.10))
    flank = Vector((0.98, 0.62, 0.30))
    belly = Vector((0.98, 0.92, 0.82))

    def color_fn(a, y, k):
        up = math.sin(a)
        c = back if up > 0.35 else (flank if up > -0.25 else belly)
        c = c * (0.90 if k % 2 == 0 else 1.06)
        return (min(c.x, 1.0), min(c.y, 1.0), min(c.z, 1.0), 1.0)

    stations = [(0.26, 0, 0), (0.22, 0.030, 0.040), (0.14, 0.055, 0.072), (0.04, 0.066, 0.086),
                (-0.06, 0.055, 0.072), (-0.15, 0.034, 0.045), (-0.23, 0.014, 0.020)]
    loft(bm, stations, 8, color_fn, (0.80, 0.30, 0.10, 1.0))
    fin = (0.95, 0.45, 0.14, 1.0)
    fin2 = (0.99, 0.70, 0.40, 1.0)
    poly(bm, [(0, -0.22, 0.0), (0.0, -0.33, 0.12), (0.0, -0.30, 0.0)], [fin, fin2, fin2])
    poly(bm, [(0, -0.22, 0.0), (0.0, -0.30, 0.0), (0.0, -0.33, -0.12)], [fin, fin2, fin2])
    poly(bm, [(0, 0.10, 0.08), (0, -0.07, 0.085), (0, -0.10, 0.17), (0, 0.0, 0.16)], [fin, fin, fin2, fin2])
    poly(bm, [(0, -0.02, -0.08), (0, -0.10, -0.075), (0, -0.12, -0.13)], [fin, fin, fin2])
    for s in (1, -1):
        poly(bm, [(s * 0.050, 0.12, -0.02), (s * 0.052, 0.05, -0.03), (s * 0.13, 0.03, -0.075)], [fin, fin, fin2])
    bmesh.ops.triangulate(bm, faces=bm.faces)
    me = new_mesh("Fish", bm, True)
    return finish("Fish", me)


def build_bird():
    bm = bmesh.new()
    bm.verts.layers.float_color.new("Color")
    col = bm.verts.layers.float_color["Color"]
    # Koyu govdeli kus: beyaz bulutlu gokte siluet olarak secilir; karin acik gri.
    white = (0.16, 0.16, 0.19, 1.0)     # kanat ve govde ana rengi (koyu)
    grey = (0.40, 0.41, 0.45, 1.0)      # arka kenar
    black = (0.04, 0.04, 0.05, 1.0)
    yellow = (0.95, 0.75, 0.15, 1.0)

    def body_color(a, y, k):
        return yellow if k == 1 else ((0.62, 0.63, 0.67, 1.0) if math.sin(a) < -0.2 else white)

    stations = [(0.27, 0, 0), (0.22, 0.014, 0.016), (0.14, 0.036, 0.040), (0.02, 0.046, 0.052),
                (-0.12, 0.034, 0.038), (-0.22, 0.016, 0.018)]
    loft(bm, stations, 8, body_color, yellow)
    poly(bm, [(0, -0.20, 0.0), (0.06, -0.38, 0.0), (-0.06, -0.38, 0.0)], [white, grey, grey])
    xs = [0.04, 0.14, 0.25, 0.36, 0.46, 0.52]
    for s in (1, -1):
        vl = []
        for k, x in enumerate(xs):
            f = (x - 0.04) / 0.48
            le = 0.07 - 0.17 * f * f
            te = -0.09 - 0.07 * f
            z = 0.012 + 0.035 * math.sin(f * math.pi * 0.7)
            va = bm.verts.new((s * x, le, z))
            vb = bm.verts.new((s * x, te, z * 0.8))
            tip = k >= len(xs) - 2
            va[col] = black if tip else white
            vb[col] = black if tip else (grey if k >= 2 else white)
            vl.append((va, vb))
        for k in range(len(vl) - 1):
            a0, b0 = vl[k]
            a1, b1 = vl[k + 1]
            if s > 0:
                bm.faces.new((a0, b0, b1, a1))
            else:
                bm.faces.new((a0, a1, b1, b0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    me = new_mesh("Bird", bm, False)
    for p in me.polygons:
        p.use_smooth = all(abs(me.vertices[i].co.x) < 0.06 for i in p.vertices)
    return finish("Bird", me)


def finish(name, me):
    me.color_attributes.active_color = me.color_attributes["Color"]
    me.color_attributes.render_color_index = me.color_attributes.active_color_index
    mat = bpy.data.materials.new(name + "Mat")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    attr = mat.node_tree.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Color"
    mat.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.7
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def main():
    for name, builder in (("fish", build_fish), ("bird", build_bird)):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        ob = builder()
        log(name, "ucgen:", total_tris([ob]))
        path = os.path.join(OUT, name + ".glb")
        os.makedirs(OUT, exist_ok=True)
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.export_scene.gltf(
            filepath=path, export_format="GLB", use_selection=True, export_yup=True,
            export_normals=True, export_vertex_color="ACTIVE", export_materials="EXPORT",
            export_cameras=False, export_lights=False, export_apply=False,
            export_image_format="NONE", export_skins=False, export_animations=False)
        log("GLB:", path, os.path.getsize(path))


main()
