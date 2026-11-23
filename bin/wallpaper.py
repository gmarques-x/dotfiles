#!/usr/bin/env python3
"""Generate a minimal wallpaper: a soft vertical gradient between two colors.
Usage: wallpaper.py [out.png] [top #hex] [bottom #hex]   (default: Everforest bg0 → bg_dim)"""
import struct, sys, zlib

W, H = 3024, 1964
hexrgb = lambda h: tuple(int(h.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))
args = sys.argv[1:]
out = args[0] if args else "everforest-dark.png"
top = hexrgb(args[1]) if len(args) > 1 else (0x2D, 0x35, 0x3B)
bottom = hexrgb(args[2]) if len(args) > 2 else (0x23, 0x2A, 0x2E)

rows = bytearray()
for y in range(H):
    t = y / (H - 1)
    px = bytes(round(a + (b - a) * t) for a, b in zip(top, bottom))
    rows += b"\x00" + px * W

def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b"")
open(out, "wb").write(png)
