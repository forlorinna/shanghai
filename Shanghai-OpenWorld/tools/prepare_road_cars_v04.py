"""Convert licensed Highland/Juniper meshes into metre-scale near and traffic assets."""
from collections import defaultdict
from math import pi
from pathlib import Path
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

source, output, name = sys.argv[sys.argv.index("--") + 1:]
output = Path(output)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(Path(source).resolve()))
objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
transforms = {obj.name: obj.matrix_world.copy() for obj in objects}
saloon = name == "sedan"
if saloon:
    rotate = Matrix.Rotation(pi/2, 4, 'Z') @ Matrix.Translation(Vector((5.265, 9.93, 0)))
    targets = (1.82, 4.4, 1.46)
    extents = (7.74, 17.51, 5.24)
else:
    rotate = Matrix.Identity(4)
    targets = (2.02, 4.64, 1.92)
    extents = (2.12, 4.80, 1.67)
normalize = Matrix.Diagonal(Vector((*[wanted/size for wanted,size in zip(targets,extents)],1))) @ rotate

def combine(objects, group):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    obj = objects[0]
    bpy.context.view_layer.objects.active = obj
    if len(objects) > 1:
        bpy.ops.object.join()
    obj.name = group
    return obj

def part_for(obj, side, axle):
    copy = obj.copy()
    copy.data = obj.data.copy()
    bpy.context.collection.objects.link(copy)
    mesh = bmesh.new()
    mesh.from_mesh(copy.data)
    bmesh.ops.delete(mesh, geom=[v for v in mesh.verts if v.co.x*side < 0 or v.co.y*axle < 0], context="VERTS")
    mesh.to_mesh(copy.data)
    mesh.free()
    return copy

def reduced_images():
    for image in bpy.data.images:
        width,height = image.size
        if max(width,height) > 1024:
            factor = 1024 / max(width,height)
            image.scale(round(width*factor),round(height*factor))
            image.pack()

visuals = defaultdict(list)
sources = defaultdict(list)
for obj in objects:
    obj.parent = None
    obj.matrix_world = Matrix.Identity(4)
    obj.data.transform(normalize @ transforms[obj.name])
    tag = obj.data.materials[0].name.lower()
    if saloon and obj.name in {"Object_15", "Object_19"}:
        for side in [-1,1]:
            for axle in [-1,1]:
                sources[side,axle].append(part_for(obj,side,axle))
        bpy.data.objects.remove(obj, do_unlink=True)
        continue
    if not saloon and tag.startswith(("tire_rubber","wheel_finish","brake_rotor","brake_caliper")):
        midpoint = sum((v.co for v in obj.data.vertices),Vector()) / len(obj.data.vertices)
        sources[1 if midpoint.x>0 else -1,1 if midpoint.y>0 else -1].append(obj)
        continue
    if (saloon and obj.name in {"Object_6", "Object_11"}) or tag.startswith("exterior_paint"):
        group = "Paint"
    elif tag.startswith("signature_led"):
        group = "Headlight"
    elif tag.startswith("taillight_led") or saloon and obj.name == "Object_16":
        group = "Taillight"
    elif tag.startswith(("glass","geoextwindow")):
        group = "Glazing"
    else:
        group = "Interior" if tag.startswith(("interior", "geocockpit")) else "Trim"
    visuals[group].append(obj)
for obj in tuple(bpy.context.scene.objects):
    if obj.type == "EMPTY":
        bpy.data.objects.remove(obj, do_unlink=True)
for group, members in visuals.items():
    combine(members, group)
for (side,axle), parts in sources.items():
    tire = max(parts, key=lambda item:len(item.data.vertices))
    midpoint = Vector([(min(v.co[i] for v in tire.data.vertices)+max(v.co[i] for v in tire.data.vertices))/2 for i in range(3)])
    wheel = combine(parts, "RollingSurface")
    pivot = bpy.data.objects.new(f"Wheel_{'L' if side<0 else 'R'}{'F' if axle>0 else 'R'}", None)
    bpy.context.collection.objects.link(pivot)
    pivot.location = midpoint
    wheel.parent = pivot
    wheel.data.transform(Matrix.Translation(-midpoint))
reduced_images()

def export(suffix, ratio):
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            mod = obj.modifiers.new("Mesh budget", "DECIMATE")
            mod.ratio = ratio
            mod.use_collapse_triangulate = True
    bpy.ops.export_scene.gltf(filepath=str(output / f"{name}_{suffix}.glb"),
                            export_format="GLB", export_apply=True)
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            obj.modifiers.clear()

export("near", .38 if saloon else .22)
export("traffic", .043 if saloon else .027)
