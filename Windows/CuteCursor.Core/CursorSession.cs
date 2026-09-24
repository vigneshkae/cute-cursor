namespace CuteCursor.Core;

public interface ICursorImage : IDisposable { }

public interface ICursorBackend
{
    ICursorImage Capture(uint systemId);
    ICursorImage Create(CursorSlot slot, double scale);
    // Install must copy the supplied handle: ownership stays with the caller.
    void Install(ICursorImage image, uint systemId);
    void ReloadConfiguredScheme();
}

public sealed class CursorSession(ICursorBackend backend)
{
    private Dictionary<uint, ICursorImage>? originals;
    public bool HasChanges => originals is not null;

    private Dictionary<uint, ICursorImage> CaptureAll()
    {
        var result = new Dictionary<uint, ICursorImage>();
        try
        {
            foreach (var id in Roles.SystemIds.Values) result.Add(id, backend.Capture(id));
            return result;
        }
        catch { Release(result); throw; }
    }

    public void Apply(PortablePack pack, double scale)
    {
        PackCodec.Validate(pack);
        if (!pack.Cursors.Any(c => Roles.SystemIds.ContainsKey(c.Role)))
            throw new InvalidOperationException("This pack only contains preview roles. Add a Windows cursor role first.");
        var prepared = new Dictionary<uint, ICursorImage>();
        Dictionary<uint, ICursorImage>? previous = null;
        var wasActive = HasChanges;
        try
        {
            // Decode/create every image before touching the current system cursors.
            foreach (var slot in pack.Cursors.Where(c => Roles.SystemIds.ContainsKey(c.Role)))
                prepared.Add(Roles.SystemIds[slot.Role], backend.Create(slot, scale));
            previous = CaptureAll();
            originals ??= CaptureAll();
            try
            {
                foreach (var id in Roles.SystemIds.Values)
                    backend.Install(prepared.GetValueOrDefault(id) ?? originals[id], id);
            }
            catch (Exception applyError)
            {
                var errors = InstallAll(previous);
                if (errors.Count == 0 && !wasActive) { Release(originals); originals = null; }
                throw new InvalidOperationException(errors.Count == 0
                    ? "Could not apply the pack. Your previous cursors were restored."
                    : "Applying and rolling back failed. Use Restore to retry before exiting.", applyError);
            }
        }
        finally { Release(prepared); if (previous is not null) Release(previous); }
    }

    public void Restore()
    {
        if (originals is null) return;
        var errors = InstallAll(originals);
        if (errors.Count != 0)
            throw new AggregateException("Some cursors could not be restored. Keep the app open and retry Restore.", errors);
        Release(originals); originals = null;
    }

    public void RestoreSystemDefaults()
    {
        // Always ask Windows to reload its configured scheme. Captured handles
        // can contain custom cursors left by an older process or another app.
        // Keep recovery snapshots alive if the native reset fails.
        backend.ReloadConfiguredScheme();
        if (originals is not null) { Release(originals); originals = null; }
    }

    private List<Exception> InstallAll(Dictionary<uint, ICursorImage> images)
    {
        var errors = new List<Exception>();
        foreach (var (id, image) in images)
            try { backend.Install(image, id); } catch (Exception ex) { errors.Add(ex); }
        return errors;
    }
    private static void Release(Dictionary<uint, ICursorImage> images)
    { foreach (var image in images.Values) image.Dispose(); }
}
