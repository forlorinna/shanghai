#!/usr/bin/env python3
"""Paint the opacity/color sheet of the original plane-tree foliage mesh."""
from pathlib import Path
from PIL import Image, ImageDraw
import math
import random
r = random.Random(481637)
target = Path(__file__).resolve().parents[1] / 'assets/textures/pbr/foliage.png'
im = Image.new('RGBA', (512,512))
draw = ImageDraw.Draw(im)
centers = [(255,267),(162,237),(334,244),(237,174),(290,335),(197,328),(297,187)]
for center in centers:
    for j in range(108):
        angle = r.uniform(0, math.tau)
        radius = 101 * math.sqrt(r.random())
        x = center[0] + math.cos(angle)*radius
        y = center[1] + math.sin(angle)*radius*.74
        a = r.uniform(0, math.tau)
        width = r.uniform(3.5,12)
        length = width*r.uniform(1.2,2.4)
        points=[]
        for k in range(9):
            phi=k*math.tau/9
            lobes=.80 + .2*math.cos(3*phi)
            lx=math.cos(phi)*length*lobes
            ly=math.sin(phi)*width*lobes
            points.append((x+lx*math.cos(a)-ly*math.sin(a), y+lx*math.sin(a)+ly*math.cos(a)))
        height = y/512
        tone = r.random()
        draw.polygon(points,fill=(int(46+tone*54),int(65+tone*79-height*18),int(28+tone*41),255))
im.save(target, optimize=True)
