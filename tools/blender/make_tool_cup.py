"""Tas (sigi ahsap canak): Poly Haven wooden_bowl_02 (CC0, Kuutti Siitonen), https://polyhaven.com/a/wooden_bowl_02
Cap ~20 cm'e olceklenir; orijin canagin alt orta noktasi; Water = ic hacim.
  blender -b -P tools/blender/make_tool_cup.py -- --src <klasor> --glb assets/models/tools/cup.glb [--png-dir k]
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tool_common import *

ASSET = arg("--asset", "wooden_bowl_02")
TARGET_DIAMETER = 0.20
reset()
src = arg("--src")
body = import_ph(src, ASSET)[0]
mn, mx = bbox(body)
ctr = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, 0.0))
transform_mesh(body, Matrix.Translation(-ctr))          # eksen ortalansin (olcum icin)
body.update_tag()
bvh = make_bvh(body)
mn, mx = bbox(body)
floor_z = interior_floor_z(bvh, mx.z, probes=((0.02, 0.01), (-0.02, 0.015), (0.0, -0.025), (-0.03, 0.0)))
rim_z = interior_top_z(bvh, floor_z + 0.01, mx.z, step=0.002, min_hits=8)
r_a = interior_radius(bvh, floor_z + 0.008)[1]
r_b = interior_radius(bvh, rim_z - 0.003)[1]
s = TARGET_DIAMETER / (max(mx.x - mn.x, mx.y - mn.y))
log("canak ham: taban", round(floor_z, 4), "rim", round(rim_z, 4), "r_alt", round(r_a, 4), "r_ust", round(r_b, 4), "olcek", round(s, 3))
decimate(body, 2000)
transform_mesh(body, Matrix.Scale(s, 4) @ Matrix.Translation(Vector((0, 0, -mn.z))))
body.name = body.data.name = "Cup"
set_material(body, tex_material("WoodBowl", diffuse_path(src, ASSET)))
finish_mesh(body)
water = make_water("Water", r_a * s * 0.93, r_b * s * 0.97, (rim_z - 0.004 - floor_z) * s, (0, 0, (floor_z - mn.z) * s), segs=24)
log("UCGEN", tri_count(body), "su", tri_count(water), "toplam", total_tris([body, water]), "boyut", [round(c, 3) for c in bbox(body)[1] - bbox(body)[0]])
if arg("--png-dir"):
    render_views([body, water], arg("--png-dir"), "cup", [
        ("3q", (0.3, 0.42, 0.25), (0, 0, 0.03), 40),
        ("fp", (0.0, -0.22, 0.3), (0, 0.0, 0.0), 60)])
if arg("--glb"):
    export_glb([body, water], arg("--glb"))
