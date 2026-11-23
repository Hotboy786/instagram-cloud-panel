"""Generate an original opaque camera icon using only the standard library."""
from pathlib import Path
import json
import struct
import zlib

size = 1024
rows = bytearray()
for y in range(size):
    rows.append(0)
    for x in range(size):
        color = (int(64 + 104 * y / size), int(29 + 18 * x / size), int(150 + 30 * x / size))
        # Rounded camera outline, lens, and flash.
        dx, dy = max(abs(x - 512) - 225, 0), max(abs(y - 512) - 225, 0)
        outer = dx * dx + dy * dy <= 100 * 100
        dx, dy = max(abs(x - 512) - 225, 0), max(abs(y - 512) - 225, 0)
        inner = dx * dx + dy * dy <= 64 * 64 and abs(x - 512) <= 289 and abs(y - 512) <= 289
        radius = (x - 512) ** 2 + (y - 512) ** 2
        white = (outer and not inner) or 140 ** 2 <= radius <= 176 ** 2 or (x - 715) ** 2 + (y - 310) ** 2 <= 28 ** 2
        rows.extend((250, 245, 255) if white else color)

def chunk(kind, payload):
    return struct.pack('>I', len(payload)) + kind + payload + struct.pack('>I', zlib.crc32(kind + payload) & 0xffffffff)

destination = Path(__file__).parent / 'InstagramStudio/Assets.xcassets/AppIcon.appiconset'
destination.mkdir(parents=True, exist_ok=True)
(destination.parent / 'Contents.json').write_text(json.dumps({'info': {'author': 'xcode', 'version': 1}}))
(destination / 'Contents.json').write_text(json.dumps({'images': [{'filename': 'AppIcon.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}], 'info': {'author': 'xcode', 'version': 1}}))
(destination / 'AppIcon.png').write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b''))
