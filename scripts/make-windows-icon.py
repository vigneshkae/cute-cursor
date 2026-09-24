#!/usr/bin/env python3
"""Wrap PNGs from make-icon.swift in an ICO container without altering pixels.

Usage: python3 scripts/make-windows-icon.py /tmp/CuteCursor.iconset output.ico
"""
from pathlib import Path
import struct
import sys

source, destination = map(Path, sys.argv[1:])
frames = [(size, (source / name).read_bytes()) for size, name in [
    (16, "icon_16x16.png"), (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"), (128, "icon_128x128.png"), (256, "icon_128x128@2x.png")]]
offset = 6 + 16 * len(frames)
directory = bytearray(struct.pack("<HHH", 0, 1, len(frames)))
for size, png in frames:
    assert png[:8] == b"\x89PNG\r\n\x1a\n" and struct.unpack(">II", png[16:24]) == (size, size)
    directory += struct.pack("<BBBBHHII", size % 256, size % 256, 0, 0, 1, 32, len(png), offset)
    offset += len(png)
destination.write_bytes(directory + b"".join(png for _, png in frames))
