"""glb'leri geri aktarip dogrular: agiz kesitleri (sayisal), agiz yonleri, ucgen, boyut, nesne adlari.
  blender -b -P tools/blender/verify_canal.py -- --glb-dir assets/models/canal
Cerceve: Blender'a aktarilan glb'de Dogu=+X, Kuzey=+Y, yukari=+Z.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import canal_common as cc
from canal_common import *  # noqa

GLB = arg("--glb-dir")
TOL = 3e-4
prof = sorted({(round(abs(u), 3), round(h, 3)) for u, h in cc.PROFILE})
ok_all = True
for pid, mouths in cc.MOUTHS.items():
    reset()
    bpy.ops.import_scene.gltf(filepath=os.path.join(GLB, pid + ".glb"))
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    chan = [o for o in meshes if o.name.startswith("Channel")]
    # tek Channel nesnesi (aqueduct dahil)
    pts = [chan[0].matrix_world @ v.co for v in chan[0].data.vertices]
    found = set()
    msgs = []
    for d, (dx, dy) in cc.DIRV.items():
        sel = [p for p in pts if abs((p.x * dx + p.y * dy) - 1.0) < TOL]
        # kesit: yanal = eksene dik, h = z
        sec = sorted({(round(abs(p.y if dx else p.x), 3), round(p.z, 3)) for p in sel})
        if sel:
            found.add(d)
        if d in mouths:
            same = sec == prof
            msgs.append(f"{d}:{'ESLESTI' if same else 'FARKLI'}({len(sec)}/{len(prof)} nokta)")
            ok_all &= same
        else:
            if sel:
                msgs.append(f"{d}:BEKLENMEYEN_AGIZ")
                ok_all = False
    names = [o.name for o in meshes]
    tris = sum(tri_count(o) for o in meshes)
    mn, mx = stats(meshes)[1:]
    print("[DOGRULA]", pid, "yonler", "".join(sorted(found, key="NESW".index)), "beklenen", mouths, "|", " ".join(msgs),
          "| ucgen", tris, "| kutu", mn, mx, "| nesneler", names, flush=True)
print("[DOGRULA] SONUC", "TAMAM" if ok_all else "SORUN", flush=True)
