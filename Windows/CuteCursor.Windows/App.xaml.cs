using System.Reflection;
using System.Threading;
using System.Windows.Media.Imaging;
using System.Windows.Threading;

namespace CuteCursor.Windows;

public partial class App : Application
{
    private Mutex? instance;
    private bool ownsMutex;
    private string? temporaryDirectory;
    public static byte[] BundledPack()
    {
        using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("SoftBloom.cutecursor") ?? throw new InvalidDataException("Soft Bloom is missing.");
        using var buffer = new MemoryStream(); stream.CopyTo(buffer); return buffer.ToArray();
    }
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        try
        {
            if (e.Args.Contains("--self-test")) { NativeSmokeTests.Run(); Shutdown(0); return; }
            var screenshotIndex = Array.IndexOf(e.Args, "--screenshot");
            var automation = screenshotIndex >= 0;
            if (!automation)
            {
                instance = new Mutex(true, "Local\\CuteCursor.Windows", out ownsMutex);
                if (!ownsMutex) { BloomDialog.Message(null, "Cute Cursor is already open", "Open Cute Cursor from its icon in the system tray."); Shutdown(); return; }
            }
            var directory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "CuteCursor");
            if (automation) { temporaryDirectory = Path.Combine(Path.GetTempPath(), "CuteCursor-preview-" + Guid.NewGuid()); directory = temporaryDirectory; }
            var window = new MainWindow(directory, automation); MainWindow = window; window.Show();
            if (automation)
            {
                var output = Path.GetFullPath(e.Args[screenshotIndex + 1]);
                window.ContentRendered += (_, _) => Dispatcher.BeginInvoke(DispatcherPriority.ApplicationIdle, new Action(() =>
                {
                    try
                    {
                        // Render the actual WPF content at the design window size, independent
                        // of the hosted runner's small virtual desktop and non-client chrome.
                        var content = (FrameworkElement)window.Content;
                        window.Content = null;
                        System.Windows.Documents.TextElement.SetFontFamily(content, window.FontFamily);
                        System.Windows.Documents.TextElement.SetFontSize(content, window.FontSize);
                        content.Width = 1200; content.Height = 820;
                        content.Measure(new Size(1200, 820));
                        content.Arrange(new Rect(0, 0, 1200, 820)); content.UpdateLayout();
                        var target = new RenderTargetBitmap(1200, 820, 96, 96, PixelFormats.Pbgra32);
                        target.Render(content);
                        var png = new PngBitmapEncoder(); png.Frames.Add(BitmapFrame.Create(target));
                        using (var file = File.Create(output)) png.Save(file);
                        window.Close(); Shutdown(0);
                    }
                    catch (Exception ex) { File.WriteAllText(output + ".error.txt", ex.ToString()); Shutdown(1); }
                }));
            }
        }
        catch (Exception ex)
        {
            if (e.Args.Length != 0) { Console.Error.WriteLine(ex); File.WriteAllText(Path.Combine(Path.GetTempPath(), "CuteCursor-test-error.txt"), ex.ToString()); }
            else BloomDialog.Message(null, "Cute Cursor couldn’t start", ex.Message + "\n\nYour existing library files have been preserved.");
            Shutdown(1);
        }
    }
    protected override void OnSessionEnding(SessionEndingCancelEventArgs e)
    { if (MainWindow is MainWindow window) e.Cancel = !window.RestoreForShutdown(); base.OnSessionEnding(e); }
    protected override void OnExit(ExitEventArgs e)
    {
        if (ownsMutex) instance?.ReleaseMutex(); instance?.Dispose();
        if (temporaryDirectory is not null && Directory.Exists(temporaryDirectory)) Directory.Delete(temporaryDirectory, true);
        base.OnExit(e);
    }
}
