"""Kova (tek): Poly Haven wooden_bucket_01 (CC0, James Ray Cock), https://polyhaven.com/a/wooden_bucket_01
Orijin kulbun ust orta noktasi; Water = kabin ic hacmi. Ayrintilar tool_common.py basinda.
  blender -b -P tools/blender/make_tool_bucket.py -- --src <klasor> --glb assets/models/tools/bucket.glb [--png-dir k]
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tool_common import *

SCALE = 0.75          # govde 26 cm
reset()
src = arg("--src")
obj, w = prepare_bucket(src, SCALE, body_tris=1500, handle_tris=300, name="Bucket")
water = make_water("Water", w["r_bottom"], w["r_top"], w["height"], (0, 0, w["z_floor"]), segs=20)
log("UCGEN", tri_count(obj), "su", tri_count(water), "toplam", total_tris([obj, water]), "su", w)
if arg("--png-dir"):
    render_views([obj, water], arg("--png-dir"), "bucket", [
        ("3q", (0.55, 0.65, -0.05), (0, 0, -0.17), 40),
        ("fp", (0.0, -0.35, 0.28), (0, 0.05, -0.2), 70),
        ("kesit", (0.0, 0.5, 0.15), (0, 0, -0.15), 35)])
if arg("--glb"):
    export_glb([obj, water], arg("--glb"))
