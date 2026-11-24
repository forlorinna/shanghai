"""Prepare the licensed BMW M4 source as a metrically sized, animated Godot asset.

blender -b -t 4 -P tools/prepare_car_v04.py -- INPUT.glb assets/vehicles/models
"""
from pathlib import Path
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

source, destination = map(Path, sys.argv[sys.argv.index("--") + 1:])
destination.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source.resolve()))
objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
assert len(objects) == 30, "Unexpected source revision"
normalize = Matrix.Translation(Vector((0, 0, 0))) @ Matrix.Diagonal(Vector((-.232, -.232, .245, 1)))
center = Matrix.Translation(Vector((.675, -.65, 0)))

for obj in objects:
    transform = normalize @ center @ obj.matrix_world
    obj.parent = None
    obj.matrix_world = Matrix.Identity(4)
    obj.data.transform(transform)
for obj in tuple(bpy.context.scene.objects):
    if obj.type == "EMPTY":
        bpy.data.objects.remove(obj, do_unlink=True)

# Remove deeply hidden engine parts and brand/racing decals. Keep modeled cabin,
# glazing, paint panels, intake mesh, lamps, tires and individual rim assemblies.
discard = {"Object_14", "Object_21", "Object_26", "Object_28"}
wheel_parts = [bpy.data.objects[part] for part in ("Object_33", "Object_34")]
for name in discard | {"Object_32"}:
    bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)

for side in [-1, 1]:
    for axle in [-1, 1]:
        pivot = bpy.data.objects.new(f"Wheel_{'L' if side < 0 else 'R'}{'F' if axle > 0 else 'R'}", None)
        bpy.context.collection.objects.link(pivot)
        for original in wheel_parts:
            part = original.copy()
            part.data = original.data.copy()
            bpy.context.collection.objects.link(part)
            mesh = bmesh.new()
            mesh.from_mesh(part.data)
            bmesh.ops.delete(mesh, geom=[v for v in mesh.verts if v.co.x * side <= 0 or v.co.y * axle <= 0], context="VERTS")
            mesh.to_mesh(part.data)
            mesh.free()
            if not part.data.vertices:
                raise ValueError(pivot.name)
            lows = [min(v.co[i] for v in part.data.vertices) for i in range(3)]
            highs = [max(v.co[i] for v in part.data.vertices) for i in range(3)]
            if original == wheel_parts[1]:
                pivot.location = [(a + b) / 2 for a, b in zip(lows, highs)]
            part.parent = pivot
        for part in pivot.children:
            part.data.transform(Matrix.Translation(-pivot.location))
for original in wheel_parts:
    bpy.data.objects.remove(original, do_unlink=True)

bpy.data.objects["Object_23"].name = "Paint"
bpy.data.objects["Object_20"].name = "Headlight"
bpy.data.objects["Object_17"].name = "Taillight"

for image in bpy.data.images:
    w, h = image.size
    if max(w, h) > 1024:
        factor = 1024 / max(w, h)
        image.scale(round(w * factor), round(h * factor))
        image.pack()

def export(name, ratio):
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        mod = obj.modifiers.new("Mobile reduction", "DECIMATE")
        mod.ratio = ratio if len(obj.data.polygons) > 200 else 1
        mod.use_collapse_triangulate = True
    bpy.ops.export_scene.gltf(filepath=str(destination / name), export_format="GLB", export_extras=True, export_apply=True)
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            obj.modifiers.clear()

export("m4_near.glb", .45)
export("m4_traffic.glb", .055)
