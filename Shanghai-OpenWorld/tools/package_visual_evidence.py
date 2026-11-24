#!/usr/bin/env python3
"""Package captured engine frames and build a matched-camera V0.1/V0.2 comparison."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
release = ROOT / 'builds/v0.2'
shots = release / 'screenshots'
mobile = release / 'mobile-previews'
baseline = ROOT / 'tools/local/v02-baseline-frames'
comparisons = [
    ('01-pearl-street', 'Lujiazui / Oriental Pearl street'),
    ('05-bund-rain-drive', 'The Bund / wet-night driving'),
    ('07-car-close', 'Lujiazui / vehicle close-up'),
]
expected = {'01-pearl-street','02-shanghai-tower','03-lujiazui-driving','04-bund-night','05-bund-rain-drive',
            '06-huangpu-reflections','07-car-close','08-third-person','09-tunnel','10-lujiazui-aerial'}
assert expected.issubset({p.stem for p in shots.glob('*.png')})
width, height = 730, 410
sheet = Image.new('RGB',(width*2+52,114+len(comparisons)*(height+48)),'#152028')
draw = ImageDraw.Draw(sheet)
font_path = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
large = ImageFont.truetype(font_path,29)
label = ImageFont.truetype(font_path,19)
draw.text((22,18),'SHANGHAI OPEN WORLD / MATCHED GODOT CAPTURES', font=large, fill='#eee9df')
draw.text((22,70),'V0.1.0  ·  BEFORE',font=label,fill='#b3bfcb')
draw.text((36+width,70),'V0.2.0  ·  AFTER',font=label,fill='#ffe0b2')
for index,(name,title) in enumerate(comparisons):
    y=104+index*(height+48)
    for x,source in [(22,baseline),(36+width,shots)]:
        with Image.open(source/(name+'.png')) as image:
            panel = image.resize((width,height),Image.Resampling.LANCZOS)
            sheet.paste(panel,(x,y))
    draw.text((25,y+height+10),title,font=label,fill='#d8dedf')
contrast = release / 'V0.1-V0.2-comparison.png'
sheet.save(contrast,optimize=True)
out = release / 'Shanghai-OpenWorld-v0.2.0-screenshots.zip'
with ZipFile(out,'w',compression=ZIP_DEFLATED,compresslevel=5) as bundle:
    for path in sorted(shots.iterdir()):
        if path.suffix in ('.png','.json'):
            bundle.write(path,Path('V0.2-Compatibility')/path.name)
    for path in sorted(mobile.iterdir()):
        if path.suffix in ('.png','.json'):
            bundle.write(path,Path('V0.2-Vulkan-Mobile-Linux')/path.name)
    for path in sorted(baseline.iterdir()):
        if path.suffix in ('.png','.json'):
            bundle.write(path,Path('V0.1-baseline')/path.name)
    bundle.write(contrast,contrast.name)
    bundle.write(ROOT/'TEST_REPORT.md','TEST_REPORT.md')
with ZipFile(out) as bundle:
    assert bundle.testzip() is None
print(out)
