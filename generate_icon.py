from PIL import Image, ImageDraw, ImageFont
import math
import os

size = 1024
img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Background gradient: deep purple to indigo
corner_r = 180
cx_center, cy_center = size / 2, size / 2
for y in range(size):
    t = y / size
    r = int(88 + t * 20)
    g = int(50 + t * 50)
    b = int(140 + t * 40)
    for x in range(size):
        dx = max(0, corner_r - x) if x < corner_r else max(0, x - (size - corner_r))
        dy = max(0, corner_r - y) if y < corner_r else max(0, y - (size - corner_r))
        if dx > 0 and dy > 0:
            dist = math.sqrt(dx * dx + dy * dy)
            if dist > corner_r:
                continue
        img.putpixel((x, y), (r, g, b, 255))

center_x, center_y = size // 2, size // 2

# Outer ring
ring_r = 220
for angle in range(360):
    rad = math.radians(angle)
    x1 = center_x + int(ring_r * math.cos(rad))
    y1 = center_y + int(ring_r * math.sin(rad))
    x2 = center_x + int((ring_r - 15) * math.cos(rad))
    y2 = center_y + int((ring_r - 15) * math.sin(rad))
    if 0 <= x1 < size and 0 <= y1 < size:
        draw.line([(x1, y1), (x2, y2)], fill=(255, 255, 255, 200), width=6)

# Nodes: 4 expert nodes + center gateway
node_positions = [
    (center_x, center_y - 120),
    (center_x - 100, center_y + 60),
    (center_x + 100, center_y + 60),
    (center_x, center_y + 140),
]
node_r = 40
for nx, ny in node_positions:
    for gr in range(node_r + 20, node_r - 1, -1):
        alpha = int(60 * (1 - (gr - node_r) / 20))
        draw.ellipse([nx - gr, ny - gr, nx + gr, ny + gr], fill=(255, 255, 255, alpha))
    draw.ellipse([nx - node_r, ny - node_r, nx + node_r, ny + node_r], fill=(255, 255, 255, 255))

# Connections
connections = [(0, 1), (0, 2), (1, 3), (2, 3), (1, 2)]
for i, j in connections:
    x1, y1 = node_positions[i]
    x2, y2 = node_positions[j]
    draw.line([(x1, y1), (x2, y2)], fill=(255, 255, 255, 180), width=8)

# Central gateway node
draw.ellipse([center_x - 55, center_y - 55, center_x + 55, center_y + 55], fill=(255, 255, 255, 255))

# Try to add text
try:
    font_paths = [
        "C:/Windows/Fonts/segoeuib.ttf",
        "C:/Windows/Fonts/arialbd.ttf",
        "C:/Windows/Fonts/seguiemj.ttf",
    ]
    font = None
    for fp in font_paths:
        if os.path.exists(fp):
            font = ImageFont.truetype(fp, 56)
            break
    if font is None:
        font = ImageFont.load_default()
    draw.text((center_x - 52, center_y - 40), "AI", fill=(88, 50, 140, 255), font=font)
except Exception:
    pass

output_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets", "app_icon.png")
img.save(output_path)
print(f"Icon saved to {output_path}")
