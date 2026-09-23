using System.Buffers.Binary;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace CuteCursor.Core;

public static class Roles
{
    public static readonly string[] All = ["pointer", "link", "text", "grab", "grabbing", "resizeHorizontal", "resizeVertical", "resizeDiagonalNWSE", "resizeDiagonalNESW", "crosshair", "notAllowed"];
    public static readonly IReadOnlyDictionary<string, uint> SystemIds = new Dictionary<string, uint>
    {
        ["pointer"] = 32512, ["link"] = 32649, ["text"] = 32513, ["crosshair"] = 32515,
        ["resizeDiagonalNWSE"] = 32642, ["resizeDiagonalNESW"] = 32643,
        ["resizeHorizontal"] = 32644, ["resizeVertical"] = 32645, ["notAllowed"] = 32648
    };
    public static string Title(string role) => role switch
    {
        "pointer" => "Pointer", "link" => "Link", "text" => "Text", "grab" => "Grab", "grabbing" => "Grabbing",
        "resizeHorizontal" => "Resize ↔", "resizeVertical" => "Resize ↕", "resizeDiagonalNWSE" => "Resize ↖↘",
        "resizeDiagonalNESW" => "Resize ↗↙", "crosshair" => "Crosshair", "notAllowed" => "Not allowed", _ => role
    };
}

public sealed record CursorSlot
{
    [JsonRequired] public string Role { get; init; } = "pointer";
    [JsonRequired] public string Name { get; init; } = "Cursor";
    [JsonRequired] public double Size { get; init; } = 40;
    [JsonRequired] public double HotspotX { get; init; } = 0.5;
    [JsonRequired] public double HotspotY { get; init; } = 0.5;
    [JsonRequired] public byte[] Png { get; init; } = [];
}
public sealed record PortablePack
{
    [JsonRequired] public string Format { get; init; } = "CuteCursorPack";
    [JsonRequired] public int Version { get; init; } = 1;
    [JsonRequired] public string Name { get; init; } = "My cursor pack";
    [JsonRequired] public List<CursorSlot> Cursors { get; init; } = [];
}

public static class PackCodec
{
    public const int MaxBytes = 16 * 1024 * 1024;
    public static readonly JsonSerializerOptions Json = new() { PropertyNamingPolicy = JsonNamingPolicy.CamelCase, WriteIndented = true, MaxDepth = 20 };
    public static PortablePack Read(byte[] data, Action<byte[]>? decodeImage = null)
    {
        if (data.Length > MaxBytes) throw new InvalidDataException("The pack exceeds 16 MB.");
        var pack = JsonSerializer.Deserialize<PortablePack>(data, Json) ?? throw new InvalidDataException("The pack is empty.");
        Validate(pack, decodeImage);
        return pack;
    }
    public static byte[] Write(PortablePack pack, Action<byte[]>? decodeImage = null)
    {
        Validate(pack, decodeImage);
        var data = JsonSerializer.SerializeToUtf8Bytes(pack, Json);
        if (data.Length > MaxBytes) throw new InvalidDataException("The pack exceeds 16 MB.");
        return data;
    }
    public static void Validate(PortablePack pack, Action<byte[]>? decodeImage = null, bool allowEmpty = false)
    {
        if (pack.Format != "CuteCursorPack" || pack.Version != 1) throw new InvalidDataException("Unsupported pack format or version.");
        if (string.IsNullOrWhiteSpace(pack.Name) || pack.Name.Length > 80) throw new InvalidDataException("Pack names must contain 1–80 characters.");
        if (pack.Cursors is null || pack.Cursors.Count > 11 || (!allowEmpty && pack.Cursors.Count == 0)) throw new InvalidDataException("A pack needs 1–11 cursor slots.");
        var seen = new HashSet<string>();
        foreach (var slot in pack.Cursors)
        {
            if (slot is null || !Roles.All.Contains(slot.Role) || !seen.Add(slot.Role)) throw new InvalidDataException("Unknown or duplicate cursor role.");
            ValidateSlot(slot, decodeImage);
        }
    }
    public static void ValidateSlot(CursorSlot slot, Action<byte[]>? decodeImage = null)
    {
        if (string.IsNullOrWhiteSpace(slot.Name) || slot.Name.Length > 200 || !Roles.All.Contains(slot.Role) ||
            !double.IsFinite(slot.Size) || slot.Size < 16 || slot.Size > 64 ||
            !double.IsFinite(slot.HotspotX) || !double.IsFinite(slot.HotspotY) ||
            slot.HotspotX < 0 || slot.HotspotX > 1 || slot.HotspotY < 0 || slot.HotspotY > 1)
            throw new InvalidDataException("Invalid cursor name, size, or click point.");
        var png = slot.Png;
        byte[] signature = [137, 80, 78, 71, 13, 10, 26, 10];
        if (png is null || png.Length < 33 || png.Length > 1024 * 1024 || !png.AsSpan(0, 8).SequenceEqual(signature) ||
            !png.AsSpan(12, 4).SequenceEqual("IHDR"u8) || BinaryPrimitives.ReadUInt32BigEndian(png.AsSpan(8, 4)) != 13)
            throw new InvalidDataException("A cursor must contain a PNG image under 1 MB.");
        var width = BinaryPrimitives.ReadUInt32BigEndian(png.AsSpan(16, 4));
        var height = BinaryPrimitives.ReadUInt32BigEndian(png.AsSpan(20, 4));
        if (width is < 1 or > 256 || height is < 1 or > 256) throw new InvalidDataException("Pack images must be at most 256 × 256 pixels.");
        decodeImage?.Invoke(png);
    }
    public static byte[] ReadFile(string path, int limit = MaxBytes)
    {
        using var stream = File.OpenRead(path);
        if (stream.Length > limit) throw new InvalidDataException($"The file exceeds {limit / 1024 / 1024} MB.");
        using var buffer = new MemoryStream();
        var chunk = new byte[8192]; int count;
        while ((count = stream.Read(chunk)) != 0)
        {
            if (buffer.Length + count > limit) throw new InvalidDataException("The file is too large.");
            buffer.Write(chunk, 0, count);
        }
        return buffer.ToArray();
    }
}

public static class CursorGeometry
{
    public static (int Width, int Height, int X, int Y) Pixels(CursorSlot slot, int imageWidth, int imageHeight, double scale)
    {
        if (imageWidth <= 0 || imageHeight <= 0 || !double.IsFinite(scale) || scale <= 0 || scale > 8) throw new ArgumentOutOfRangeException(nameof(scale));
        var longest = Math.Clamp((int)Math.Round(slot.Size * scale), 1, 512);
        var width = Math.Max(1, (int)Math.Round(longest * imageWidth / (double)Math.Max(imageWidth, imageHeight)));
        var height = Math.Max(1, (int)Math.Round(longest * imageHeight / (double)Math.Max(imageWidth, imageHeight)));
        return (width, height, Math.Clamp((int)(slot.HotspotX * width), 0, width - 1), Math.Clamp((int)(slot.HotspotY * height), 0, height - 1));
    }
}
