using System.Text;
using System.Text.Json;
using CuteCursor.Core;

var bloomBytes = File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "Soft-Bloom.cutecursor"));
var bloom = PackCodec.Read(bloomBytes);
int passed = 0;
void Check(bool value, string message = "Assertion failed") { if (!value) throw new Exception(message); }
void Reject(Action action) { try { action(); } catch { return; } throw new Exception("Expected rejection"); }
void Test(string name, Action action) { action(); Console.WriteLine("PASS " + name); passed++; }
byte[] Json(PortablePack pack) => JsonSerializer.SerializeToUtf8Bytes(pack, PackCodec.Json);
PortablePack With(params CursorSlot[] slots) => bloom with { Cursors = slots.ToList() };
var first = bloom.Cursors.Single(c => c.Role == "pointer");
Test("Shared Mac Soft Bloom has all roles at size 40", () => Check(bloom.Cursors.Count == 11 && bloom.Cursors.All(c => c.Size == 40) && Roles.All.All(r => bloom.Cursors.Any(c => c.Role == r))));
Test("Both Mac example packs import", () => Check(PackCodec.Read(File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "Lilac.cutecursor"))).Cursors.Count > 0));
Test("Round trip preserves names, roles, images and geometry", () => Check(Json(bloom).SequenceEqual(Json(PackCodec.Read(PackCodec.Write(bloom))))));
Test("Unknown format and version reject", () => { Reject(() => PackCodec.Read(Json(bloom with { Format = "Other" }))); Reject(() => PackCodec.Read(Json(bloom with { Version = 2 }))); });
Test("Invalid JSON and oversized input reject", () => { Reject(() => PackCodec.Read("{"u8.ToArray())); Reject(() => PackCodec.Read(new byte[PackCodec.MaxBytes + 1])); });
Test("Missing required metadata rejects", () => { Reject(() => PackCodec.Read(Encoding.UTF8.GetBytes(Encoding.UTF8.GetString(bloomBytes).Replace("\"version\"", "\"missingVersion\"")))); });
Test("Unknown, duplicate and empty roles reject", () => { Reject(() => PackCodec.Write(With())); Reject(() => PackCodec.Write(With(first, first))); Reject(() => PackCodec.Write(With(first with { Role = "wait" }))); });
Test("Bad sizes and hotspots reject", () =>
{
    foreach (double value in new[] { double.NaN, double.PositiveInfinity, 15, 65 }) Reject(() => PackCodec.ValidateSlot(first with { Size = value }));
    foreach (double value in new[] { double.NaN, double.NegativeInfinity, -.1, 1.1 }) Reject(() => PackCodec.ValidateSlot(first with { HotspotX = value }));
});
Test("Pack and cursor name bounds reject", () => { Reject(() => PackCodec.Write(bloom with { Name = " " })); Reject(() => PackCodec.ValidateSlot(first with { Name = new string('a', 201) })); });
Test("Malformed and oversized PNG reject", () => { Reject(() => PackCodec.ValidateSlot(first with { Png = new byte[40] })); Reject(() => PackCodec.ValidateSlot(first with { Png = new byte[1024 * 1024 + 1] })); var big = first.Png.ToArray(); big[16] = 127; Reject(() => PackCodec.ValidateSlot(first with { Png = big })); });
Test("Full decoder callback rejects corrupt image before import", () => Reject(() => PackCodec.Read(bloomBytes, _ => throw new InvalidDataException("invalid pixels"))));
Test("Geometry keeps aspect and clamps edge hotspots", () => { var g = CursorGeometry.Pixels(first with { Size = 40, HotspotX = 1, HotspotY = 1 }, 256, 128, 1.5); Check(g == (60, 30, 59, 29)); Reject(() => CursorGeometry.Pixels(first, 1, 1, double.NaN)); });
Test("Windows roles exclude grab and grabbing", () => Check(Roles.SystemIds.Count == 9 && !Roles.SystemIds.ContainsKey("grab") && !Roles.SystemIds.ContainsKey("grabbing")));
var root = Path.Combine(Path.GetTempPath(), "cute-cursor-tests-" + Guid.NewGuid());
try
{
    Test("Fresh library installs Soft Bloom once and preserves edits", () =>
    {
        var lib = new Library(root, bloomBytes, _ => { }); Check(lib.State.Packs.Single().Pack.Cursors.All(c => c.Size == 40));
        lib.RenamePack(Library.SoftBloomId, "My flowers"); lib.SetSlot(Library.SoftBloomId, "pointer", first with { Size = 55, HotspotX = .123 });
        var reopened = new Library(root, bloomBytes, _ => { }); Check(reopened.State.Packs.Single().Pack.Name == "My flowers");
        Check(reopened.State.Packs.Single().Pack.Cursors.Single(c => c.Role == "pointer").Size == 55);
    });
    Test("Intentional default pack deletion stays deleted", () => { var lib = new Library(root, bloomBytes, _ => { }); lib.RemovePack(Library.SoftBloomId); Check(new Library(root, bloomBytes, _ => { }).State.Packs.Count == 0); });
    Test("Pack slots and library images stay independent", () =>
    {
        var lib = new Library(root, bloomBytes, _ => { }); var id = lib.AddCursor(first); var packId = lib.AddPack(new() { Name = "New pack" });
        lib.SetSlot(packId, "link", lib.State.Cursors.Single(c => c.Id == id).Image); lib.EditCursor(id, first with { Size = 64 });
        Check(lib.State.Packs.Single().Pack.Cursors.Single().Size == 40); lib.Favorite(id);
        Check(new Library(root, bloomBytes, _ => { }).State.Cursors.Single(c => c.Id == id).Favorite); lib.RemoveCursor(id);
        Check(lib.State.Packs.Single().Pack.Cursors.Count == 1); lib.SetSlot(packId, "link", null); Check(lib.State.Packs.Single().Pack.Cursors.Count == 0);
    });
    Test("Rejected mutations preserve saved bytes", () => { var lib = new Library(root, bloomBytes, _ => { }); var before = File.ReadAllBytes(Path.Combine(root, "library.json")); Reject(() => lib.RenamePack(lib.State.Packs.Single().Id, "")); Check(before.SequenceEqual(File.ReadAllBytes(Path.Combine(root, "library.json")))); });
    Test("Corrupt existing library is not overwritten", () => { var badDir = Path.Combine(root, "corrupt"); Directory.CreateDirectory(badDir); var path = Path.Combine(badDir, "library.json"); File.WriteAllText(path, "{broken"); Reject(() => new Library(badDir, bloomBytes, _ => { })); Check(File.ReadAllText(path) == "{broken"); });
    Test("Default collection contains 20 unique named pointers at 40", () =>
    {
        var cursors = BundledCollection.Load();
        Check(cursors.Count == 20 && cursors.Select(c => c.Id).Distinct().Count() == 20);
        Check(cursors.All(c => c.Image.Size == 40 && c.Image.Role == "pointer"));
        Check(cursors[0].Image.Name == "Ancestor" && cursors[2].Image.Name == "No Smoking");
    });
    Test("Collection edits, favorites and deletions survive reopening", () =>
    {
        var directory = Path.Combine(root, "collection"); var lib = new Library(directory, bloomBytes, _ => { });
        var item = lib.State.Cursors[0]; var deleted = lib.State.Cursors[1].Id;
        lib.EditCursor(item.Id, item.Image with { Name = "My pointer", Size = 53, HotspotX = .27 });
        lib.Favorite(item.Id); lib.RemoveCursor(deleted);
        var reopened = new Library(directory, bloomBytes, _ => { });
        var kept = reopened.State.Cursors.Single(c => c.Id == item.Id);
        Check(kept.Favorite && kept.Image.Name == "My pointer" && kept.Image.Size == 53 && kept.Image.HotspotX == .27);
        Check(reopened.State.Cursors.Count == 19 && reopened.State.Cursors.All(c => c.Id != deleted));
    });
    Test("Older Windows libraries gain collection without overwriting edits", () =>
    {
        var directory = Path.Combine(root, "upgrade"); Directory.CreateDirectory(directory);
        var custom = new SavedCursor(Guid.NewGuid(), first with { Name = "My imported cursor", Size = 62 }, true);
        var existing = BundledCollection.Load()[0] with { Image = first with { Name = "Already edited", Size = 49 } };
        var old = new LibraryState { SoftBloomInstalled = true, Cursors = [custom, existing], Packs = [] };
        File.WriteAllBytes(Path.Combine(directory, "library.json"), JsonSerializer.SerializeToUtf8Bytes(old, PackCodec.Json));
        var lib = new Library(directory, bloomBytes, _ => { });
        Check(lib.State.CollectionInstalled && lib.State.Cursors.Count == 21 && lib.State.Packs.Count == 0);
        Check(lib.State.Cursors[0].Favorite && lib.State.Cursors[0].Image.Size == 62);
        Check(lib.State.Cursors.Single(c => c.Id == existing.Id).Image.Name == "Already edited");
        Check(new Library(directory, bloomBytes, _ => { }).State.Cursors.Count == 21);
    });
    Test("A collection decoding failure never writes a partial migration", () =>
    {
        var directory = Path.Combine(root, "bad-collection"); Directory.CreateDirectory(directory);
        var path = Path.Combine(directory, "library.json");
        var bytes = JsonSerializer.SerializeToUtf8Bytes(new LibraryState { SoftBloomInstalled = true }, PackCodec.Json);
        File.WriteAllBytes(path, bytes);
        Reject(() => new Library(directory, bloomBytes, _ => throw new InvalidDataException("Bad pixels")));
        Check(File.ReadAllBytes(path).SequenceEqual(bytes));
    });
}
finally { if (Directory.Exists(root)) Directory.Delete(root, true); }
Test("Apply and restore all Windows roles without leaked handles", () =>
{
    var b = new FakeBackend(); var s = new CursorSession(b); s.Apply(bloom, 1); Check(s.HasChanges); Check(b.Live.Values.All(v => v.StartsWith("custom:"))); s.Restore(); Check(!s.HasChanges && b.OriginalsRestored && b.Outstanding == 0);
});
Test("Switch to a partial pack resets omitted roles to original", () =>
{
    var b = new FakeBackend(); var s = new CursorSession(b); s.Apply(bloom, 1); s.Apply(With(first), 1); Check(b.Live[32512].StartsWith("custom:") && b.Live[32649] == "original:32649"); s.Restore(); Check(b.Outstanding == 0);
});
Test("Failed preflight never mutates live cursors", () => { var b = new FakeBackend { FailCreateRole = "text" }; var s = new CursorSession(b); Reject(() => s.Apply(bloom, 1)); Check(b.Installs == 0 && !s.HasChanges && b.Outstanding == 0); });
Test("Failed original capture never mutates live cursors", () => { var b = new FakeBackend { FailCaptureAt = 12 }; var s = new CursorSession(b); Reject(() => s.Apply(bloom, 1)); Check(b.Installs == 0 && !s.HasChanges && b.Outstanding == 0); });
Test("First failed apply rolls back and releases originals", () => { var b = new FakeBackend { FailInstall = n => n == 4 }; var s = new CursorSession(b); Reject(() => s.Apply(bloom, 1)); Check(b.OriginalsRestored && !s.HasChanges && b.Outstanding == 0); });
Test("Failed reapply restores the prior custom pack", () => { var b = new FakeBackend(); var s = new CursorSession(b); s.Apply(bloom, 1); var before = b.Live.ToDictionary(); b.FailInstall = n => n == 12; Reject(() => s.Apply(With(first with { Size = 64 }), 1)); Check(before.All(kv => b.Live[kv.Key] == kv.Value) && s.HasChanges); b.FailInstall = _ => false; s.Restore(); Check(b.Outstanding == 0); });
Test("Failed rollback keeps originals available for retry", () => { var b = new FakeBackend { FailInstall = n => n >= 3 }; var s = new CursorSession(b); Reject(() => s.Apply(bloom, 1)); Check(s.HasChanges && b.Installs == 12); b.FailInstall = _ => false; s.Restore(); Check(b.OriginalsRestored && b.Outstanding == 0); });
Test("Restore attempts every role and keeps state on failure", () => { var b = new FakeBackend(); var s = new CursorSession(b); s.Apply(bloom, 1); b.FailInstall = n => n == 11; Reject(s.Restore); Check(s.HasChanges && b.Installs == 18); b.FailInstall = _ => false; s.Restore(); Check(!s.HasChanges && b.Outstanding == 0); });
Test("Preview-only pack does not change system cursors", () => { var b = new FakeBackend(); var s = new CursorSession(b); Reject(() => s.Apply(With(first with { Role = "grab" }), 1)); Check(b.Installs == 0 && b.Outstanding == 0); });
Test("System Default reloads configured scheme instead of stale originals", () =>
{
    var b = new FakeBackend(); foreach (var id in b.Live.Keys) b.Live[id] = "leftover flower";
    var s = new CursorSession(b); s.Apply(bloom, 1); s.RestoreSystemDefaults();
    Check(b.OriginalsRestored && !s.HasChanges && b.Outstanding == 0 && b.Reloads == 1);
});
Test("System Default runs even without an active session", () =>
{
    var b = new FakeBackend(); b.Live[32512] = "leftover flower"; var s = new CursorSession(b);
    s.RestoreSystemDefaults(); s.RestoreSystemDefaults(); Check(b.OriginalsRestored && b.Reloads == 2 && b.Outstanding == 0);
});
Test("Failed System Default preserves recovery handles for retry", () =>
{
    var b = new FakeBackend(); var s = new CursorSession(b); s.Apply(bloom, 1); b.FailReload = true;
    Reject(s.RestoreSystemDefaults); Check(s.HasChanges && b.Outstanding == 9);
    b.FailReload = false; s.RestoreSystemDefaults(); Check(!s.HasChanges && b.OriginalsRestored && b.Outstanding == 0);
    s.Apply(With(first), 1); s.Restore(); Check(b.OriginalsRestored && b.Outstanding == 0);
});
Console.WriteLine($"{passed} tests passed. No system cursors were changed.");

sealed class FakeBackend : ICursorBackend
{
    public Dictionary<uint, string> Live { get; } = Roles.SystemIds.Values.ToDictionary(id => id, id => "original:" + id);
    public int Outstanding, Installs, Captures, Reloads;
    public bool FailReload;
    public string? FailCreateRole;
    public int FailCaptureAt;
    public Func<int, bool> FailInstall = _ => false;
    public bool OriginalsRestored => Live.All(kv => kv.Value == "original:" + kv.Key);
    public ICursorImage Capture(uint id) { if (++Captures == FailCaptureAt) throw new Exception("capture failed"); return new Image(this, Live[id]); }
    public ICursorImage Create(CursorSlot slot, double scale) { if (slot.Role == FailCreateRole) throw new Exception("decode failed"); return new Image(this, $"custom:{slot.Role}:{slot.Size}"); }
    public void Install(ICursorImage image, uint id) { var i = (Image)image; if (i.Disposed) throw new Exception("disposed handle"); if (FailInstall(++Installs)) throw new Exception("native failure"); Live[id] = i.Value; }
    public void ReloadConfiguredScheme() { Reloads++; if (FailReload) throw new Exception("Scheme reload failed"); foreach (var id in Live.Keys) Live[id] = "original:" + id; }
    private sealed class Image : ICursorImage
    {
        private readonly FakeBackend owner;
        public string Value { get; }
        public bool Disposed;
        public Image(FakeBackend owner, string value) { this.owner = owner; Value = value; owner.Outstanding++; }
        public void Dispose() { if (Disposed) throw new Exception("Double dispose"); Disposed = true; owner.Outstanding--; }
    }
}
