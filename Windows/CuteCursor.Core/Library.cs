using System.Text.Json;
namespace CuteCursor.Core;

public sealed record SavedCursor(Guid Id, CursorSlot Image, bool Favorite = false);
public sealed record SavedPack(Guid Id, PortablePack Pack);
public sealed record LibraryState
{
    public int Version { get; init; } = 1;
    public bool SoftBloomInstalled { get; init; }
    public bool CollectionInstalled { get; init; }
    public List<SavedCursor> Cursors { get; init; } = [];
    public List<SavedPack> Packs { get; init; } = [];
}

public sealed class Library
{
    public static readonly Guid SoftBloomId = new("75E7AB00-30B1-4AFC-9459-82B7C9A8BD40");
    private readonly string path;
    private readonly Action<byte[]> decodeImage;
    public LibraryState State { get; private set; }
    public Library(string directory, byte[] softBloom, Action<byte[]> decodeImage)
    {
        this.decodeImage = decodeImage;
        Directory.CreateDirectory(directory);
        path = Path.Combine(directory, "library.json");
        State = File.Exists(path) ? JsonSerializer.Deserialize<LibraryState>(PackCodec.ReadFile(path, 128 * 1024 * 1024), PackCodec.Json)
            ?? throw new InvalidDataException("The saved library is empty.") : new();
        Validate(State);
        // Validate both bundled sets before persisting an upgrade. The receipt
        // prevents removed defaults from returning and preserves later edits.
        var next = State;
        if (!State.SoftBloomInstalled)
        {
            var pack = PackCodec.Read(softBloom, decodeImage);
            pack = pack with { Cursors = pack.Cursors.Select(c => c with { Size = 40 }).ToList() };
            var packs = State.Packs.ToList();
            if (!packs.Any(p => p.Id == SoftBloomId)) packs.Insert(0, new(SoftBloomId, pack));
            next = next with { Packs = packs, SoftBloomInstalled = true };
        }
        if (!State.CollectionInstalled)
        {
            var collection = BundledCollection.Load(decodeImage);
            var cursors = next.Cursors.ToList();
            foreach (var cursor in collection)
                if (!cursors.Any(c => c.Id == cursor.Id)) cursors.Add(cursor);
            next = next with { Cursors = cursors, CollectionInstalled = true };
        }
        if (!ReferenceEquals(next, State)) Save(next);
    }
    private void Validate(LibraryState state)
    {
        if (state.Version != 1 || state.Cursors is null || state.Packs is null ||
            state.Cursors.Any(c => c is null || c.Image is null) || state.Packs.Any(p => p is null || p.Pack is null) ||
            state.Cursors.Select(c => c.Id).Distinct().Count() != state.Cursors.Count ||
            state.Packs.Select(p => p.Id).Distinct().Count() != state.Packs.Count)
            throw new InvalidDataException("The saved library is invalid. Existing files have been preserved.");
        foreach (var cursor in state.Cursors) PackCodec.ValidateSlot(cursor.Image, decodeImage);
        foreach (var pack in state.Packs) PackCodec.Validate(pack.Pack, decodeImage, allowEmpty: true);
    }
    private void Save(LibraryState next)
    {
        Validate(next);
        var bytes = JsonSerializer.SerializeToUtf8Bytes(next, PackCodec.Json);
        if (bytes.Length > 128 * 1024 * 1024) throw new InvalidDataException("Your library has reached its 128 MB limit.");
        var temporary = path + "." + Guid.NewGuid() + ".tmp";
        try
        {
            using (var file = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None)) { file.Write(bytes); file.Flush(true); }
            File.Move(temporary, path, true);
            State = next;
        }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
    public Guid AddCursor(CursorSlot image)
    {
        var item = new SavedCursor(Guid.NewGuid(), image with { Role = "pointer" });
        Save(State with { Cursors = [..State.Cursors, item] }); return item.Id;
    }
    public void EditCursor(Guid id, CursorSlot image) => Save(State with { Cursors = State.Cursors.Select(c => c.Id == id ? c with { Image = image } : c).ToList() });
    public void Favorite(Guid id) => Save(State with { Cursors = State.Cursors.Select(c => c.Id == id ? c with { Favorite = !c.Favorite } : c).ToList() });
    public void RemoveCursor(Guid id) => Save(State with { Cursors = State.Cursors.Where(c => c.Id != id).ToList() });
    public Guid AddPack(PortablePack pack)
    {
        PackCodec.Validate(pack, decodeImage, allowEmpty: true);
        var item = new SavedPack(Guid.NewGuid(), pack);
        Save(State with { Packs = [..State.Packs, item] }); return item.Id;
    }
    public Guid ImportPack(byte[] data) => AddPack(PackCodec.Read(data, decodeImage));
    public void RenamePack(Guid id, string name) => Save(State with { Packs = State.Packs.Select(p => p.Id == id ? p with { Pack = p.Pack with { Name = name.Trim() } } : p).ToList() });
    public void RemovePack(Guid id) => Save(State with { Packs = State.Packs.Where(p => p.Id != id).ToList() });
    public void SetSlot(Guid id, string role, CursorSlot? image)
    {
        if (!Roles.All.Contains(role)) throw new ArgumentException("Unknown role.");
        Save(State with { Packs = State.Packs.Select(p => p.Id != id ? p : p with
        {
            Pack = p.Pack with { Cursors = [..p.Pack.Cursors.Where(c => c.Role != role), ..(image is null ? Array.Empty<CursorSlot>() : new[] { image with { Role = role } })] }
        }).ToList() });
    }
}
