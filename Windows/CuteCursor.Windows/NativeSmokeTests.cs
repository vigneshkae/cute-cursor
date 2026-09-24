using System.Text.Json;
using System.Windows.Media.Imaging;
namespace CuteCursor.Windows;

public static class NativeSmokeTests
{
    // Intentionally never calls Install / SetSystemCursor or changes the live scheme.
    public static void Run()
    {
        var pack = PackCodec.Read(App.BundledPack(), ImageCodec.Validate);
        if (pack.Cursors.Count != 11 || pack.Cursors.Any(c => c.Size != 40)) throw new Exception("Soft Bloom defaults changed.");
        var backend = new NativeCursors();
        var collection = BundledCollection.Load(ImageCodec.Validate);
        if (collection.Count != 20 || collection.Any(c => c.Image.Size != 40)) throw new Exception("Collection defaults changed.");
        foreach (var slot in pack.Cursors.Concat(collection.Select(c => c.Image)))
            foreach (double scale in new[] { 1, 1.25, 1.5, 2.0 })
            {
                using var handle = (CursorHandle)backend.Create(slot, scale);
                var image = ImageCodec.Decode(slot.Png);
                var geometry = CursorGeometry.Pixels(slot, image.PixelWidth, image.PixelHeight, scale);
                var actual = NativeCursors.Inspect(handle);
                if (actual.X != geometry.X || actual.Y != geometry.Y) throw new Exception("Native cursor hotspot differs from the pack.");
            }
        foreach (var id in Roles.SystemIds.Values) using (backend.Capture(id)) { }
        PackCodec.Read(PackCodec.Write(pack, ImageCodec.Validate), ImageCodec.Validate);
        var invalid = pack.Cursors[0].Png[..33];
        bool rejected = false;
        try { ImageCodec.Validate(invalid); } catch { rejected = true; }
        if (!rejected) throw new Exception("Truncated PNG was accepted.");
        var directory = Path.Combine(Path.GetTempPath(), "CuteCursor-image-tests-" + Guid.NewGuid());
        Directory.CreateDirectory(directory);
        try
        {
            var window = new MainWindow(Path.Combine(directory, "ui-library"), automation: true);
            try { window.VerifyInterfaceDefaults(); }
            finally { window.Close(); }
            var pixels = Enumerable.Repeat((byte)255, 640 * 320 * 4).ToArray();
            var source = BitmapSource.Create(640, 320, 300, 300, PixelFormats.Bgra32, null, pixels, 640 * 4);
            void Save(string path, BitmapEncoder encoder, BitmapSource bitmap)
            { encoder.Frames.Add(BitmapFrame.Create(bitmap)); using var file = File.Create(path); encoder.Save(file); }
            foreach (var (extension, encoder) in new (string, BitmapEncoder)[] { ("png", new PngBitmapEncoder()), ("jpg", new JpegBitmapEncoder()), ("gif", new GifBitmapEncoder()), ("bmp", new BmpBitmapEncoder()), ("tif", new TiffBitmapEncoder()) })
            {
                var path = Path.Combine(directory, "import." + extension); Save(path, encoder, source);
                var imported = ImageCodec.Import(path); var result = ImageCodec.Decode(imported.Png);
                if (result.PixelWidth != 256 || result.PixelHeight != 128 || imported.Size != 40)
                    throw new Exception("Image import lost its aspect ratio or default size: " + extension);
            }
            var transparent = BitmapSource.Create(2, 2, 96, 96, PixelFormats.Bgra32, null, new byte[16], 8);
            var blankPath = Path.Combine(directory, "transparent.png"); Save(blankPath, new PngBitmapEncoder(), transparent);
            bool blankRejected = false;
            try { ImageCodec.Import(blankPath); } catch (InvalidDataException) { blankRejected = true; }
            if (!blankRejected) throw new Exception("Fully transparent image was accepted.");
        }
        finally { Directory.Delete(directory, true); }
        var output = Environment.GetEnvironmentVariable("CUTE_CURSOR_SMOKE_RESULT");
        if (output is not null) File.WriteAllText(output, JsonSerializer.Serialize(new { ok = true, bundledCursors = 20, nativeCursorsCreated = 124, imageFormatsImported = 5, interfaceDefaultsVerified = true, systemCursorsChanged = 0 }));
    }
}
