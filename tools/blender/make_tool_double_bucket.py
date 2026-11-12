"""Cift kova: Poly Haven wooden_bucket_01 (CC0, James Ray Cock), https://polyhaven.com/a/wooden_bucket_01 iki kopya,
aralarinda 0,5 m (merkezler), orijin iki kulbun ust orta noktasi; Water ve Water.001 = ic hacimler.
  blender -b -P tools/blender/make_tool_double_bucket.py -- --src <klasor> --glb assets/models/tools/double_bucket.glb [--png-dir k]
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tool_common import *

SCALE = 0.7
GAP = 0.5
reset()
src = arg("--src")
base, w = prepare_bucket(src, SCALE, body_tris=830, handle_tris=170, name="BucketL")
objs = [base]
base.location = (-GAP / 2, 0, 0)
right = duplicate(base, "BucketR", loc=(GAP / 2, 0, 0))
objs.append(right)
waters = []
for i, x in enumerate((-GAP / 2, GAP / 2)):
    nm = "Water" if i == 0 else "Water.001"
    waters.append(make_water(nm, w["r_bottom"], w["r_top"], w["height"], (x, 0, w["z_floor"]), segs=16))
log("UCGEN kova", [tri_count(o) for o in objs], "su", [tri_count(o) for o in waters], "toplam", total_tris(objs + waters), w)
if arg("--png-dir"):
    allo = objs + waters
    render_views(allo, arg("--png-dir"), "double_bucket", [
        ("3q", (0.9, 1.2, 0.1), (0, 0, -0.25), 40),
        ("fp", (0.0, -0.45, 0.35), (0, 0.1, -0.3), 85)])
if arg("--glb"):
    export_glb(objs + waters, arg("--glb"))
