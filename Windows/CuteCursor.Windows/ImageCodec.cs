using System.Windows.Media.Imaging;

namespace CuteCursor.Windows;

public static class ImageCodec
{
    public static BitmapSource Decode(byte[] data)
    {
        using var stream = new MemoryStream(data, false);
        var decoder = BitmapDecoder.Create(stream, BitmapCreateOptions.PreservePixelFormat, BitmapCacheOption.OnDemand);
        var frame = decoder.Frames[0];
        if (frame.PixelWidth > 16384 || frame.PixelHeight > 16384 || (long)frame.PixelWidth * frame.PixelHeight > 64_000_000)
            throw new InvalidDataException("Choose an image under 64 megapixels and 16,384 pixels per side.");
        var bitmap = new FormatConvertedBitmap(frame, PixelFormats.Pbgra32, null, 0);
        var pixels = new byte[bitmap.PixelWidth * bitmap.PixelHeight * 4];
        bitmap.CopyPixels(pixels, bitmap.PixelWidth * 4, 0);
        var result = BitmapSource.Create(bitmap.PixelWidth, bitmap.PixelHeight, 96, 96, PixelFormats.Pbgra32, null, pixels, bitmap.PixelWidth * 4);
        result.Freeze(); return result;
    }
    public static void Validate(byte[] png)
    {
        var image = Decode(png);
        if (image.PixelWidth > 256 || image.PixelHeight > 256) throw new InvalidDataException("Pack images must be 256 pixels or smaller.");
        var pixels = new byte[image.PixelWidth * image.PixelHeight * 4];
        image.CopyPixels(pixels, image.PixelWidth * 4, 0);
        if (!Enumerable.Range(0, image.PixelWidth * image.PixelHeight).Any(i => pixels[i * 4 + 3] != 0))
            throw new InvalidDataException("The image is entirely transparent.");
    }
    public static BitmapSource Resize(BitmapSource image, int width, int height)
    {
        // Normalize source DPI: cursor geometry is in pixels, not image metadata units.
        var pixels = new byte[image.PixelWidth * image.PixelHeight * 4];
        image.CopyPixels(pixels, image.PixelWidth * 4, 0);
        var source = BitmapSource.Create(image.PixelWidth, image.PixelHeight, 96, 96, PixelFormats.Pbgra32, null, pixels, image.PixelWidth * 4);
        var visual = new DrawingVisual();
        RenderOptions.SetBitmapScalingMode(visual, BitmapScalingMode.HighQuality);
        using (var drawing = visual.RenderOpen()) drawing.DrawImage(source, new Rect(0, 0, width, height));
        var result = new RenderTargetBitmap(width, height, 96, 96, PixelFormats.Pbgra32);
        result.Render(visual); result.Freeze(); return result;
    }
    public static CursorSlot Import(string path)
    {
        var decoded = Decode(PackCodec.ReadFile(path));
        double ratio = Math.Min(1, 256.0 / Math.Max(decoded.PixelWidth, decoded.PixelHeight));
        var image = Resize(decoded, Math.Max(1, (int)Math.Round(decoded.PixelWidth * ratio)), Math.Max(1, (int)Math.Round(decoded.PixelHeight * ratio)));
        var encoder = new PngBitmapEncoder(); encoder.Frames.Add(BitmapFrame.Create(image));
        using var stream = new MemoryStream(); encoder.Save(stream);
        var name = Path.GetFileNameWithoutExtension(path);
        var slot = new CursorSlot { Name = name.Length > 200 ? name[..200] : name, Png = stream.ToArray() };
        PackCodec.ValidateSlot(slot, Validate); return slot;
    }
}
