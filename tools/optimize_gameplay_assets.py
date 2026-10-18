"""Run with Blender --background --factory-startup --python this_file.
Original sources are never modified. No decimation or compression extensions.
"""
import bpy
import json
import hashlib
import struct
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'ldjam_60/assets'
OUT = ASSETS / 'optimized'
OUT.mkdir(exist_ok=True)

def measure(path):
    blob = path.read_bytes()
    gltf = json.loads(blob[20:20+struct.unpack_from("<I", blob, 12)[0]])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    points = [o.matrix_world @ Vector(c) for o in objects for c in o.bound_box]
    return dict(path=str(path.relative_to(ROOT)), bytes=path.stat().st_size, sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects),
                vertices=sum(len(o.data.vertices) for o in objects),
                mesh_objects=len(objects), objects=len(bpy.context.scene.objects),
                surfaces=sum(len(m["primitives"]) for m in gltf.get("meshes", [])),
                extensions_used=gltf.get("extensionsUsed", []),
                materials=len(bpy.data.materials),
                textures=[dict(name=i.name, size=list(i.size), channels=i.channels) for i in bpy.data.images if i.size[0]],
                bounds=[[min(p[i] for p in points) for i in range(3)], [max(p[i] for p in points) for i in range(3)]])

report = {'blender': bpy.app.version_string, 'before': [], 'after': []}
for path in sorted(ASSETS.rglob('*.glb')):
    if OUT in path.parents: continue
    report['before'].append(measure(path))

# Mine parts are rigid; bake transforms and join while retaining both materials,
# winding, custom normals and every triangle. Export root stays at world origin.
measure(ASSETS / 'boss_mine/spike_mine.glb')
bpy.ops.object.select_all(action='DESELECT')
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
for o in meshes: o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.join()
o = bpy.context.object
o.name = 'SpikeMine'
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.export_scene.gltf(filepath=str(OUT / 'spike_mine.glb'), export_format='GLB', use_selection=True, export_yup=True)
report['after'].append(measure(OUT / 'spike_mine.glb'))
# Trial: only dissolve coplanar cannon edges, respecting normal and UV seams.
measure(ASSETS / 'pirate_kit/cannon.glb')
for o in [o for o in bpy.context.scene.objects if o.type == 'MESH']:
    bpy.context.view_layer.objects.active = o
    mod = o.modifiers.new('Coplanar only', 'DECIMATE')
    mod.decimate_type = 'DISSOLVE'
    mod.angle_limit = 0.0001
    mod.delimit = {'NORMAL', 'MATERIAL', 'SEAM', 'UV'}
    bpy.ops.object.modifier_apply(modifier=mod.name)
trial = ROOT / 'build/asset_optimization/candidates/cannon.glb'
trial.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(trial), export_format='GLB', export_yup=True)
report['after'].append(measure(trial))
(ROOT / 'artifacts/asset_optimization/audit.json').write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps(report, indent=2))
