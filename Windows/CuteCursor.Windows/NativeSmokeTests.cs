using System.Text.Json;
namespace CuteCursor.Windows;

public static class NativeSmokeTests
{
    // Intentionally never calls Install / SetSystemCursor or changes the live scheme.
    public static void Run()
    {
        var pack = PackCodec.Read(App.BundledPack(), ImageCodec.Validate);
        if (pack.Cursors.Count != 11 || pack.Cursors.Any(c => c.Size != 40)) throw new Exception("Soft Bloom defaults changed.");
        var backend = new NativeCursors();
        foreach (var slot in pack.Cursors)
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
        var output = Environment.GetEnvironmentVariable("CUTE_CURSOR_SMOKE_RESULT");
        if (output is not null) File.WriteAllText(output, JsonSerializer.Serialize(new { ok = true, nativeCursorsCreated = 44, systemCursorsChanged = 0 }));
    }
}
