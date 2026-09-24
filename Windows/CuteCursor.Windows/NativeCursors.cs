using System.ComponentModel;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

namespace CuteCursor.Windows;

public sealed class CursorHandle : SafeHandleZeroOrMinusOneIsInvalid, ICursorImage
{
    public CursorHandle(IntPtr value) : base(true) { SetHandle(value); }
    protected override bool ReleaseHandle() => NativeCursors.DestroyCursor(handle);
}

// All global cursor mutation is isolated here. Never pass a shared LoadCursor handle
// to SetSystemCursor, which takes ownership of its argument.
public sealed class NativeCursors : ICursorBackend
{
    [DllImport("user32.dll", SetLastError = true)] private static extern IntPtr LoadCursorW(IntPtr instance, IntPtr name);
    [DllImport("user32.dll", SetLastError = true)] private static extern IntPtr CopyImage(IntPtr image, uint type, int x, int y, uint flags);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool SetSystemCursor(IntPtr cursor, uint id);
    [DllImport("user32.dll", SetLastError = true)] internal static extern bool DestroyCursor(IntPtr cursor);
    [DllImport("user32.dll", SetLastError = true)] private static extern IntPtr CreateIconIndirect(ref IconInfo info);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool GetIconInfo(IntPtr cursor, out IconInfo info);
    [DllImport("gdi32.dll", SetLastError = true)] private static extern IntPtr CreateDIBSection(IntPtr dc, ref BitmapInfo info, uint usage, out IntPtr bits, IntPtr section, uint offset);
    [DllImport("gdi32.dll", SetLastError = true)] private static extern IntPtr CreateBitmap(int width, int height, uint planes, uint bits, byte[] data);
    [DllImport("gdi32.dll")] private static extern bool DeleteObject(IntPtr value);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool SystemParametersInfoW(uint action, uint param, IntPtr value, uint flags);
    [StructLayout(LayoutKind.Sequential)] private struct IconInfo
    { public int IsIcon; public uint X; public uint Y; public IntPtr Mask; public IntPtr Color; }
    [StructLayout(LayoutKind.Sequential)] private struct BitmapInfo
    {
        public uint Size; public int Width; public int Height; public ushort Planes; public ushort BitCount;
        public uint Compression; public uint ImageSize; public int XPels; public int YPels; public uint Used; public uint Important; public uint Colors;
    }
    private static IntPtr Checked(IntPtr handle) => handle == IntPtr.Zero ? throw new Win32Exception(Marshal.GetLastWin32Error()) : handle;
    public ICursorImage Capture(uint systemId) => new CursorHandle(Checked(CopyImage(Checked(LoadCursorW(IntPtr.Zero, (IntPtr)systemId)), 2, 0, 0, 0)));
    public ICursorImage Create(CursorSlot slot, double scale)
    {
        PackCodec.ValidateSlot(slot, ImageCodec.Validate);
        var source = ImageCodec.Decode(slot.Png);
        var (w, h, x, y) = CursorGeometry.Pixels(slot, source.PixelWidth, source.PixelHeight, scale);
        var image = ImageCodec.Resize(source, w, h);
        var pixels = new byte[w * h * 4]; image.CopyPixels(pixels, w * 4, 0);
        var info = new BitmapInfo { Size = 40, Width = w, Height = -h, Planes = 1, BitCount = 32, ImageSize = (uint)pixels.Length };
        var color = Checked(CreateDIBSection(IntPtr.Zero, ref info, 0, out var bits, IntPtr.Zero, 0));
        IntPtr mask = IntPtr.Zero;
        try
        {
            Marshal.Copy(pixels, 0, bits, pixels.Length);
            var maskStride = ((w + 15) / 16) * 2;
            var maskBytes = new byte[maskStride * h];
            for (int row = 0; row < h; row++)
                for (int col = 0; col < w; col++)
                    if (pixels[(row * w + col) * 4 + 3] == 0) maskBytes[row * maskStride + col / 8] |= (byte)(0x80 >> (col % 8));
            mask = Checked(CreateBitmap(w, h, 1, 1, maskBytes));
            var cursor = new IconInfo { X = (uint)x, Y = (uint)y, Mask = mask, Color = color };
            return new CursorHandle(Checked(CreateIconIndirect(ref cursor)));
        }
        finally { if (mask != IntPtr.Zero) DeleteObject(mask); DeleteObject(color); }
    }
    public void Install(ICursorImage image, uint systemId)
    {
        var handle = (CursorHandle)image;
        var copy = Checked(CopyImage(handle.DangerousGetHandle(), 2, 0, 0, 0));
        // SetSystemCursor destroys the passed cursor; our retained original is untouched.
        if (!SetSystemCursor(copy, systemId)) throw new Win32Exception(Marshal.GetLastWin32Error());
        GC.KeepAlive(handle);
    }
    public void ReloadConfiguredScheme()
    {
        if (!SystemParametersInfoW(0x57, 0, IntPtr.Zero, 0)) throw new Win32Exception(Marshal.GetLastWin32Error());
    }
    public static (uint X, uint Y) Inspect(CursorHandle cursor)
    {
        if (!GetIconInfo(cursor.DangerousGetHandle(), out var info)) throw new Win32Exception(Marshal.GetLastWin32Error());
        try { return (info.X, info.Y); }
        finally { if (info.Mask != IntPtr.Zero) DeleteObject(info.Mask); if (info.Color != IntPtr.Zero) DeleteObject(info.Color); GC.KeepAlive(cursor); }
    }
}
