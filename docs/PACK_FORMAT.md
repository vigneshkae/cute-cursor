# Cute Cursor pack format, version 1

Extension: `.cutecursor`. A UTF-8 JSON object with these fields:

- `format`: exactly `CuteCursorPack`
- `version`: integer `1`
- `name`: nonempty pack name, at most 80 characters
- `cursors`: 1–11 objects, no repeated `role`

Each cursor contains `role`, `name` (1–200 characters), `size` (16–64 logical
points), `hotspotX` and `hotspotY` (finite normalized values 0–1, origin top left),
and `png` (base64 encoded transparent PNG). PNGs must contain one image, at most
256×256 pixels and at most 1 MB decoded. The complete JSON is at most 16 MB.

Role strings: `pointer`, `link`, `text`, `grab`, `grabbing`, `resizeHorizontal`,
`resizeVertical`, `resizeDiagonalNWSE`, `resizeDiagonalNESW`, `crosshair`,
`notAllowed`. The diagonal suffix indicates the line joining opposite corners.

Size describes the longest side. Preserve the image aspect ratio. Clamp a hotspot
of exactly 1 inside the final bitmap. Missing roles mean “use original,” not “reuse
another custom image.” No paths, executable code, URLs, or OS identifiers belong
in a portable pack. Import creates fresh internal UUIDs and filenames and validates
the complete file before writing its contents to the library.

Version 1 is static. GIF animation is not embedded. Unknown format versions and
unknown roles are rejected. macOS maps these roles to its own system registry;
Windows must provide a separate mapping and implementation. A portable format
does not make the application itself cross-platform.
