"""Package eight matched-camera Godot screenshots from the two builds."""
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[1]
release = root / "builds/v0.4"
shots = {
    "01-car": "Vehicle",
    "02-character": "Protagonist",
    "03-pearl": "Oriental Pearl Tower",
    "04-skywalk": "Lujiazui pedestrian bridge",
    "05-street": "Street",
    "06-third-person": "Third-person view",
    "07-night": "Night",
    "08-rain": "Rain",
}
versions = {"baseline": "V0.2.0", "screenshots": "V0.4.0"}
font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
font = ImageFont.truetype(font_path, 20)
header = ImageFont.truetype(font_path, 26)
width, height = 590, 332
sheet = Image.new("RGB", (2*width+48, 105+len(shots)*(height+36)), "#1c252c")
draw = ImageDraw.Draw(sheet)
draw.text((16, 15), "Shanghai Open World  |  Matched Godot captures", font=header, fill="#f0efe8")
for index, (folder, title) in enumerate(versions.items()):
    draw.text((16+index*(width+16), 63), title, font=font, fill="#d4dfdf")
for index, (name, title) in enumerate(shots.items()):
    row = 100+index*(height+36)
    for column, folder in enumerate(versions):
        with Image.open(release/folder/(name+".png")) as image:
            assert image.size == (1024,576), (name, folder, image.size)
            sheet.paste(image.resize((width,height),Image.Resampling.LANCZOS),
                        (16+column*(width+16),row))
    draw.text((16, row+height+6), title, font=font, fill="#e4e6e1")
comparison = release/"V0.2-V0.4-comparison.png"
sheet.save(comparison)
output = release/"Shanghai-OpenWorld-v0.4.0-screenshots.zip"
with ZipFile(output, "w", compression=ZIP_DEFLATED, compresslevel=5) as archive:
    for folder, version in versions.items():
        for shot in shots:
            name = shot+".png"
            archive.write(release/folder/name, Path(version)/name)
        path = release/folder/"metrics.json"
        if path.exists():
            archive.write(path, Path(version)/path.name)
    archive.write(comparison, comparison.name)
with ZipFile(output) as archive:
    assert archive.testzip() is None
print(output)
