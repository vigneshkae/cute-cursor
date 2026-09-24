using System.Reflection;
using System.Text.Json;

namespace CuteCursor.Core;

public static class BundledCollection
{
    private sealed record Entry(Guid Id, string Name, string OriginalName, string Resource, double HotspotX, double HotspotY);

    public static IReadOnlyList<SavedCursor> Load(Action<byte[]>? decodeImage = null)
    {
        var assembly = typeof(BundledCollection).Assembly;
        byte[] Read(string name)
        {
            using var stream = assembly.GetManifestResourceStream("Collection." + name)
                ?? throw new InvalidDataException("The bundled cursor collection is missing. Reinstall Cute Cursor.");
            using var buffer = new MemoryStream(); stream.CopyTo(buffer); return buffer.ToArray();
        }
        var entries = JsonSerializer.Deserialize<List<Entry>>(Read("catalog.json"), PackCodec.Json)
            ?? throw new InvalidDataException("The bundled cursor collection is empty.");
        if (entries.Count != 20 || entries.Select(e => e.Id).Distinct().Count() != 20 || entries.Select(e => e.Name).Distinct().Count() != 20)
            throw new InvalidDataException("The bundled cursor collection is invalid.");
        return entries.Select(entry =>
        {
            if (entry.Id == Guid.Empty || Path.GetFileName(entry.Resource) != entry.Resource || !entry.Resource.EndsWith(".png", StringComparison.Ordinal))
                throw new InvalidDataException("A bundled cursor resource is invalid.");
            var slot = new CursorSlot { Name = entry.Name, Png = Read(entry.Resource), Size = 40,
                HotspotX = entry.HotspotX, HotspotY = entry.HotspotY };
            PackCodec.ValidateSlot(slot, decodeImage);
            return new SavedCursor(entry.Id, slot);
        }).ToList();
    }
}
