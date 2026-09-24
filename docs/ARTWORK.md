# Included artwork

## Soft Bloom

The eleven PNGs in `Sources/CursorStudio/Resources/SoftBloom/` were supplied by the
project maintainer for the default Cute Cursor pack. The accompanying
`Examples/Soft-Bloom.cutecursor` contains downsampled copies with 40 pt sizes and
role-specific click points. They are included under this project's MIT license.

The source images retain their original transparent backgrounds. The app imports
and downsamples them through the same image-validation path used for user images.
The flower theme uses rounded yellow petals, golden centers, cream hands, and
sage-green stems and symbols.

## Individual collection

The 20 PNGs and catalog in `Sources/CursorStudio/Resources/Collection/` were
supplied by the project maintainer for inclusion as default cursor options. They
are included under the project MIT license. Their curated names are listed in
[the collection guide](CURSOR_COLLECTION.md). No unrelated library files are
included.

## Earlier examples and app icon

The geometric prototype artwork in `CursorModel.swift` and `PackArtwork.swift`,
and the Lilac example pack were created for this project and are included under
MIT. `scripts/make-icon.swift` now places the same Soft Bloom pointer artwork used
by the header onto a cream rounded tile; it no longer draws a separate flower.

The Windows icon at `Windows/CuteCursor.Windows/Assets/CuteCursorBloom.ico`
contains the same rendered app-icon PNGs in an ICO container, assembled by
`scripts/make-windows-icon.py`. It introduces no new artwork.

## Imported images

The app does not grant a license to images imported by users. Only share a pack
when you have the rights to redistribute its images. No unrelated personal library
images or artwork from Mousecape projects are included in this repository.
