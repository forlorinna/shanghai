"""Reconstruct the Lujiazui ring from OSM way 48876367 and mapped access ways."""

from math import ceil, cos, radians
import json
from pathlib import Path
from xml.etree import ElementTree as ET

import bpy
from mathutils import Vector

root = Path(__file__).resolve().parents[1]
output = root / "assets/landmarks/models"
bpy.ops.wm.read_factory_settings(use_empty=True)
osm = ET.parse(root / "maps/source/shanghai.osm")
nodes = {
    node.attrib["id"]: (
        (float(node.attrib["lon"]) - 121.498) * 111319 * cos(radians(31.236)),
        (31.236 - float(node.attrib["lat"])) * 111312,
    )
    for node in osm.findall("node")
}
ways = {way.attrib["id"]: [nodes[n.attrib["ref"]] for n in way.findall("nd")] for way in osm.findall("way")}
elevation = 8.15
width = 7.6
origin = Vector((-184, -462))

def model_point(osm_point):
    pos = Vector(osm_point) - origin
    return Vector((pos.x, -pos.y))

def material(name, color, roughness, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    return mat

finish = {
    "deck": material("Deck paving", (.44, .43, .40), .82),
    "edge": material("Structural aluminum", (.33, .38, .40), .42, .58),
    "joint": material("Expansion joints and step nosings", (.14, .15, .15), .7, .25),
    "column": material("Cast concrete", (.55, .54, .50), .84),
    "glass": material("Float glass", (.39, .57, .59), .23, .18),
    "light": material("Under rail light", (.94, .63, .28), .35),
    "tread": material("Escalator tread", (.18, .20, .21), .51, .46),
}
glass = finish["glass"].node_tree.nodes.get("Principled BSDF")
glass.inputs["Alpha"].default_value = .27
finish["glass"].surface_render_method = "DITHERED"
batches = {name: ([], []) for name in finish}

def mesh(name, points, faces):
    vertices, polygons = batches[name]
    polygons.extend(tuple(i + len(vertices) for i in face) for face in faces)
    vertices.extend(points)

def quad(name, a, b, c, d):
    mesh(name, [a, b, c, d], [(0, 1, 2, 3)])

def xyz(point, height):
    return Vector((point.x, point.y, height))

def smooth_ring(points):
    loop = [model_point(p) for p in points[:-1]]
    result = []
    for i, b in enumerate(loop):
        a, c, d = loop[i-1], loop[(i+1) % len(loop)], loop[(i+2) % len(loop)]
        for j in range(5):
            t = j / 5
            result.append(.5 * ((2*b) + (-a+c)*t + (2*a-5*b+4*c-d)*t*t + (-a+3*b-3*c+d)*t*t*t))
    return result

def offsets(points, amount, closed=False):
    right = []
    for i, point in enumerate(points):
        a = points[(i - 1) % len(points)] if i > 0 or closed else point
        b = points[(i + 1) % len(points)] if i < len(points)-1 or closed else point
        vector = (b - a).normalized()
        right.append(point + Vector((-vector.y, vector.x))*amount)
    return right

def strip(name, left, right, heights, closed=False):
    edges = len(left) if closed else len(left) - 1
    for i in range(edges):
        j = (i+1) % len(left)
        quad(name, xyz(left[i], heights[i]), xyz(right[i], heights[i]), xyz(right[j], heights[j]), xyz(left[j], heights[j]))

def tube(name, a, b, radius, sides=8):
    u = (b-a).normalized()
    x = u.cross(Vector((0,0,1))) if abs(u.z) < .95 else u.cross(Vector((1,0,0)))
    x.normalize()
    y = u.cross(x)
    rim = [radius * (x*cos(radians(i*360/sides)) + y*cos(radians(i*360/sides-90))) for i in range(sides)]
    faces = [(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)]
    mesh(name, [a+p for p in rim]+[b+p for p in rim], faces)

def railing(points, heights, closed=False, every=1, skip=()):
    for i in range(0, len(points) if closed else len(points)-1, every):
        j = (i+every) % len(points) if closed else min(i+every, len(points)-1)
        if i == j:
            continue
        a, b = points[i], points[j]
        if any((a.lerp(b, .5) - exit).length < 4.1 for exit in skip):
            continue
        h, k = heights[i], heights[j]
        quad("glass", xyz(a, h+.16),xyz(b, k+.16),xyz(b, k+1.07),xyz(a, h+1.07))
        tube("edge", xyz(a,h+1.13),xyz(b,k+1.13),.039)
        tube("edge", xyz(a,h+.12),xyz(b,k+.12),.021,6)
        tube("edge", xyz(a,h+.06),xyz(a,h+1.16),.029,6)
        tube("light", xyz(a,h+1.067),xyz(b,k+1.067),.014,6)

ring = smooth_ring(ways["48876367"])
entrances = {w: [model_point(p) for p in ways[w]] for w in ("104441053", "166125936", "166125933", "166125934", "104441056")}
heights = [elevation]*len(ring)
left, right = offsets(ring, -width/2, True), offsets(ring, width/2, True)
strip("deck", left, right, heights, True)
for sign in (-1, 1):
    edge = offsets(ring, sign*width/2.0, True)
    inset = offsets(ring, sign*(width/2.0-.48), True)
    for i, point in enumerate(edge):
        j = (i+1) % len(edge)
        quad("edge",xyz(point,elevation),xyz(edge[j],elevation),xyz(inset[j],elevation-.93),xyz(inset[i],elevation-.93))
    exits = [path[0].lerp(path[1], .22) for path in entrances.values() if (path[1]-path[0]).dot(edge[min(range(len(ring)),key=lambda i:(ring[i]-path[0]).length_squared)]-path[0]) > 0]
    railing(offsets(ring,sign*(width/2-.16),True),heights,True,2,exits)
strip("column", offsets(ring,-width/2+.48,True), offsets(ring,width/2-.48,True), [elevation-.93]*len(ring), True)
for i in range(0, len(ring), 11):
    p = ring[i]
    tube("column", xyz(p, .05), xyz(p, elevation-.93), .77, 16)
    tube("edge", xyz(p, elevation-1.3), xyz(p, elevation-.91), 1.02, 16)
for i in range(0, len(ring), 12):
    a, b = left[i], right[i]
    toward = (ring[(i+1)%len(ring)] - ring[i]).normalized()*.036
    quad("joint",xyz(a,elevation+.008),xyz(b,elevation+.008),xyz(b+toward,elevation+.008),xyz(a+toward,elevation+.008))

def world(point, height):
    return [round(point.x, 4), round(height, 4), round(-point.y, 4)]

collision = {"origin":[origin.x, 0, origin.y],
             "ring":[world(p,elevation) for p in ring], "width":width, "access":[]}

for ident, route in entrances.items():
    # A short level landing meets the inner deck before the stair flight begins.
    approach = (route[1]-route[0]).normalized()
    path = [route[0], route[0]+approach*1.4, *route[1:]]
    distance = [0.0]
    for a, b in zip(path, path[1:]):
        distance.append(distance[-1] + (b-a).length)
    levels = [max(.08, elevation*(1-max(0,d-1.4)/(distance[-1]-1.4))) for d in distance]
    levels[0] = elevation
    levels[1] = elevation
    stair_width = 3.15 if ident in ("104441053", "104441056") else 3.9
    escalator = ident.startswith("166")
    collision["access"].append({"id":ident, "width":stair_width, "points":[world(p,h) for p,h in zip(path,levels)]})
    for i, (a,b) in enumerate(zip(path,path[1:])):
        h,k = levels[i],levels[i+1]
        direction = (b-a).normalized()
        side = Vector((-direction.y,direction.x))*stair_width*.5
        count = max(1, ceil((h-k)/.167))
        for step in range(count):
            p,q = a.lerp(b,step/count), a.lerp(b,(step+1)/count)
            y,z = h+(k-h)*step/count,h+(k-h)*(step+1)/count
            quad("tread" if escalator else "deck",xyz(p-side,y),xyz(p+side,y),xyz(q+side,y),xyz(q-side,y))
            if abs(y-z) > .001:
                quad("joint",xyz(q-side,y),xyz(q+side,y),xyz(q+side,z),xyz(q-side,z))
        for sign in (-1,1):
            rail_steps = max(2,ceil((b-a).length/1.9))
            base = [a.lerp(b,j/rail_steps)+sign*side for j in range(rail_steps+1)]
            rail_heights = [h+(k-h)*j/rail_steps for j in range(rail_steps+1)]
            railing(base,rail_heights)
            quad("edge",xyz(a+sign*side,h),xyz(b+sign*side,k),xyz(b+sign*side,k-.46),xyz(a+sign*side,h-.46))

for name, (vertices, faces) in batches.items():
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(finish[name])
    uv = data.uv_layers.new()
    for polygon in data.polygons:
        for li in polygon.loop_indices:
            co = data.vertices[data.loops[li].vertex_index].co
            uv.data[li].uv = (co.x/2.8, co.y/2.8)
# Strip and glass normals are intentionally two-sided. Structural columns have outward normals.
bpy.ops.export_scene.gltf(filepath=str(output / "lujiazui_skywalk.glb"), export_format="GLB")
(output / "lujiazui_skywalk.json").write_text(json.dumps(collision, separators=(",", ":"))+"\n")
