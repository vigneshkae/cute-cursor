using System.ComponentModel;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media.Imaging;
using Microsoft.Win32;

namespace CuteCursor.Windows;

public partial class MainWindow : Window
{
    private readonly Library library;
    private readonly CursorSession session = new(new NativeCursors());
    private readonly string recoveryPath;
    private readonly bool automation;
    private bool packMode = true, updating, exiting, recoveryPending;
    private Guid? selectedId;
    private string selectedRole = "pointer";
    private CursorHandle? previewHandle;
    private Cursor? previewCursor;
    private readonly System.Windows.Forms.NotifyIcon? tray;
    private int clicks;
    private SavedPack? SelectedPack => library.State.Packs.FirstOrDefault(p => p.Id == selectedId);
    private SavedCursor? SelectedCursor => library.State.Cursors.FirstOrDefault(c => c.Id == selectedId);
    private CursorSlot? SelectedSlot => packMode ? SelectedPack?.Pack.Cursors.FirstOrDefault(c => c.Role == selectedRole) : SelectedCursor?.Image;
    private PortablePack? SelectionPack => packMode ? SelectedPack?.Pack : SelectedCursor is { } cursor ? new() { Name = cursor.Image.Name.Length > 80 ? cursor.Image.Name[..80] : cursor.Image.Name, Cursors = [cursor.Image with { Role = "pointer" }] } : null;

    public MainWindow(string directory, bool automation = false)
    {
        this.automation = automation;
        library = new Library(directory, App.BundledPack(), ImageCodec.Validate);
        recoveryPath = Path.Combine(directory, "active-session.txt");
        recoveryPending = File.Exists(recoveryPath);
        InitializeComponent();
        selectedId = library.State.Packs.FirstOrDefault()?.Id;
        if (!automation)
        {
            tray = new System.Windows.Forms.NotifyIcon { Text = "Cute Cursor", Icon = System.Drawing.Icon.ExtractAssociatedIcon(Environment.ProcessPath!) ?? System.Drawing.SystemIcons.Application, Visible = true };
            var menu = new System.Windows.Forms.ContextMenuStrip();
            menu.Items.Add("Open Cute Cursor", null, (_, _) => OpenWindow());
            menu.Items.Add("Restore cursors", null, (_, _) => Run(RestoreCursors));
            menu.Items.Add("Exit Cute Cursor", null, (_, _) => TryExit());
            tray.ContextMenuStrip = menu;
            tray.DoubleClick += (_, _) => OpenWindow();
        }
        Closing += WindowClosing;
        Closed += (_, _) => { ClearPreview(); tray?.Dispose(); };
        RebuildLibrary(); RefreshEditor();
        Loaded += (_, _) =>
        {
            if (recoveryPending && !automation)
            {
                Status.Text = "A previous session ended unexpectedly. Restore before applying a new pack.";
                if (BloomDialog.Confirm(this, "Restore your Windows cursors?", "Cute Cursor may have closed with custom cursors active. Restore reloads your configured Windows cursor scheme. Your library is safe.", "Restore")) Run(RestoreCursors);
            }
        };
        DpiChanged += (_, _) => Run(RefreshArtwork);
    }
    private void OpenWindow() { Show(); WindowState = WindowState.Normal; Activate(); }
    public bool TryExit()
    {
        try { RestoreCursors(); }
        catch (Exception ex) { BloomDialog.Message(this, "Restore needs another try", ex.Message); return false; }
        exiting = true; Close(); Application.Current.Shutdown(); return true;
    }
    public bool RestoreForShutdown()
    {
        try { RestoreCursors(); return true; } catch { return false; }
    }
    private void WindowClosing(object? sender, CancelEventArgs e)
    {
        if (exiting || automation) return;
        e.Cancel = true; Hide();
        tray?.ShowBalloonTip(2500, "Cute Cursor is still here", "Open, restore, or exit from the system tray. Exit restores your cursors.", System.Windows.Forms.ToolTipIcon.Info);
    }
    private void Run(Action action)
    {
        try { action(); }
        catch (Exception ex) { Status.Text = "That change could not be completed."; BloomDialog.Message(this, "Couldn’t complete that", ex.Message); }
    }
    private void RebuildLibrary()
    {
        updating = true;
        try
        {
            LibraryList.Items.Clear();
            PacksTab.Background = (Brush)FindResource(packMode ? "Yellow" : "Paper");
            CursorsTab.Background = (Brush)FindResource(packMode ? "Paper" : "Yellow");
            var query = Search.Text.Trim();
            if (packMode)
            {
                foreach (var p in library.State.Packs.Where(p => p.Pack.Name.Contains(query, StringComparison.OrdinalIgnoreCase)))
                    AddLibraryRow(p.Id, p.Pack.Name, $"{p.Pack.Cursors.Count} of 11 roles", p.Pack.Cursors.FirstOrDefault(c => c.Role == "pointer") ?? p.Pack.Cursors.FirstOrDefault(), false);
            }
            else foreach (var c in library.State.Cursors.OrderByDescending(c => c.Favorite).Where(c => c.Image.Name.Contains(query, StringComparison.OrdinalIgnoreCase)))
                AddLibraryRow(c.Id, c.Image.Name, "Your image · PNG", c.Image, c.Favorite);
        }
        finally { updating = false; }
    }
    private void AddLibraryRow(Guid id, string name, string subtitle, CursorSlot? slot, bool favorite)
    {
        var row = new DockPanel();
        if (slot is not null) row.Children.Add(new Image { Source = ImageCodec.Decode(slot.Png), Width = 48, Height = 48, Margin = new Thickness(0, 0, 10, 0) });
        if (!packMode)
        {
            var star = new Button { Content = favorite ? "♥" : "♡", Padding = new Thickness(5), Background = Brushes.Transparent, BorderThickness = new Thickness(0), ToolTip = favorite ? "Remove favorite" : "Favorite" };
            System.Windows.Automation.AutomationProperties.SetName(star, favorite ? "Remove favorite" : "Favorite");
            DockPanel.SetDock(star, Dock.Right); row.Children.Add(star);
            star.Click += (_, e) => { e.Handled = true; Run(() => { library.Favorite(id); RebuildLibrary(); }); };
        }
        var text = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
        text.Children.Add(new TextBlock { Text = name, FontWeight = FontWeights.SemiBold, TextTrimming = TextTrimming.CharacterEllipsis, ToolTip = name });
        text.Children.Add(new TextBlock { Text = subtitle, FontSize = 12, Foreground = (Brush)FindResource("Muted"), Margin = new Thickness(0, 4, 0, 0) });
        row.Children.Add(text);
        var item = new ListBoxItem { Content = row, Tag = id, IsSelected = selectedId == id };
        System.Windows.Automation.AutomationProperties.SetName(item, name); LibraryList.Items.Add(item);
    }
    private void RefreshEditor()
    {
        updating = true;
        try
        {
            var pack = SelectionPack;
            Details.Visibility = pack is null ? Visibility.Collapsed : Visibility.Visible;
            EmptyState.Visibility = pack is null ? Visibility.Visible : Visibility.Collapsed;
            ApplyButton.IsEnabled = pack?.Cursors.Any(c => Roles.SystemIds.ContainsKey(c.Role)) == true;
            ApplyButton.Content = packMode ? "Apply pack ↗" : "Apply cursor ↗";
            RoleGrid.Visibility = packMode ? Visibility.Visible : Visibility.Collapsed;
            RoleGrid.Children.Clear();
            if (pack is null) { ClearPreview(); return; }
            SelectionTitle.Text = packMode ? pack.Name : SelectedCursor!.Image.Name;
            SelectionSubtitle.Text = packMode ? "11 shareable roles · 9 system roles on Windows · grab & grabbing are preview-only" : "Your image, your everyday pointer. Changes stay in your library.";
            if (packMode)
                foreach (var role in Roles.All)
                {
                    var slot = pack.Cursors.FirstOrDefault(c => c.Role == role);
                    var card = new DockPanel();
                    card.Children.Add(new Image { Source = slot is null ? null : ImageCodec.Decode(slot.Png), Width = 30, Height = 34, Margin = new Thickness(0, 0, 8, 0) });
                    var labels = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
                    labels.Children.Add(new TextBlock { Text = Roles.Title(role), FontSize = 12, FontWeight = FontWeights.SemiBold });
                    labels.Children.Add(new TextBlock { Text = !Roles.SystemIds.ContainsKey(role) ? "Preview only" : slot is null ? "Original" : $"{slot.Size:0} px at 100%", FontSize = 10, Foreground = (Brush)FindResource("Muted") });
                    card.Children.Add(labels);
                    var button = new Button { Content = card, Padding = new Thickness(9, 10, 7, 10), Margin = new Thickness(3), HorizontalContentAlignment = HorizontalAlignment.Stretch, Background = (Brush)FindResource(role == selectedRole ? "Yellow" : "Paper") };
                    System.Windows.Automation.AutomationProperties.SetName(button, Roles.Title(role));
                    button.Click += (_, _) => Run(() => { selectedRole = role; RefreshEditor(); }); RoleGrid.Children.Add(button);
                }
            RoleTitle.Text = packMode ? Roles.Title(selectedRole) : "Your pointer";
            var current = SelectedSlot;
            Adjustments.IsEnabled = current is not null;
            SizeSlider.Value = current?.Size ?? 40; XSlider.Value = current?.HotspotX ?? .5; YSlider.Value = current?.HotspotY ?? .5;
            RefreshArtwork();
        }
        finally { updating = false; }
    }
    private void ClearPreview()
    {
        TestPad.Cursor = null; previewCursor?.Dispose(); previewCursor = null; previewHandle?.Dispose(); previewHandle = null;
    }
    private void RefreshArtwork()
    {
        ClearPreview();
        var slot = SelectedSlot; Art.Source = slot is null ? null : ImageCodec.Decode(slot.Png);
        ClickMarker.Visibility = slot is null ? Visibility.Collapsed : Visibility.Visible;
        SizeLabel.Text = $"Size · {slot?.Size ?? 40:0}";
        if (slot is null) { TestHint.Text = "Choose an image for this role.\nEmpty system roles use the originals."; return; }
        var image = (BitmapSource)Art.Source!;
        double ratio = 190.0 / Math.Max(image.PixelWidth, image.PixelHeight);
        Art.Width = image.PixelWidth * ratio; Art.Height = image.PixelHeight * ratio;
        Canvas.SetLeft(Art, (200 - Art.Width) / 2); Canvas.SetTop(Art, (200 - Art.Height) / 2);
        Canvas.SetLeft(ClickMarker, Canvas.GetLeft(Art) + Art.Width * slot.HotspotX - 6);
        Canvas.SetTop(ClickMarker, Canvas.GetTop(Art) + Art.Height * slot.HotspotY - 6);
        previewHandle = (CursorHandle)new NativeCursors().Create(slot, VisualTreeHelper.GetDpi(this).DpiScaleX);
        previewCursor = CursorInteropHelper.Create(previewHandle); TestPad.Cursor = previewCursor;
        TestHint.Text = "Move your cursor here.\nGive it a click.";
    }
    private void SaveSlot(CursorSlot slot)
    {
        if (selectedId is not { } id) return;
        if (packMode) library.SetSlot(id, selectedRole, slot); else library.EditCursor(id, slot with { Role = "pointer" });
        Status.Text = session.HasChanges ? "Saved. Apply again to use your changes system-wide." : "Saved to your library.";
    }
    private void Adjust(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (updating || SelectedSlot is not { } slot) return;
        Run(() => { SaveSlot(slot with { Size = SizeSlider.Value, HotspotX = XSlider.Value, HotspotY = YSlider.Value }); RefreshArtwork(); });
    }
    private void SetClickPoint(object sender, MouseButtonEventArgs e)
    {
        if (SelectedSlot is not { } slot) return;
        var point = e.GetPosition(Art);
        Run(() => { SaveSlot(slot with { HotspotX = Math.Clamp(point.X / Art.Width, 0, 1), HotspotY = Math.Clamp(point.Y / Art.Height, 0, 1) }); RefreshEditor(); });
    }
    private void CenterPoint(object sender, RoutedEventArgs e) { if (SelectedSlot is { } slot) Run(() => { SaveSlot(slot with { HotspotX = .5, HotspotY = .5 }); RefreshEditor(); }); }
    private void TestClick(object sender, MouseButtonEventArgs e) => TestHint.Text = $"Bloom! {(++clicks == 1 ? "One click" : $"{clicks} clicks")} 🌼";
    private void SearchChanged(object sender, TextChangedEventArgs e) { if (LibraryList is not null) Run(RebuildLibrary); }
    private void ShowPacks(object sender, RoutedEventArgs e) => Run(() => { packMode = true; selectedId = library.State.Packs.FirstOrDefault()?.Id; Search.Text = ""; RebuildLibrary(); RefreshEditor(); });
    private void ShowCursors(object sender, RoutedEventArgs e) => Run(() => { packMode = false; selectedId = library.State.Cursors.FirstOrDefault()?.Id; Search.Text = ""; RebuildLibrary(); RefreshEditor(); });
    private void LibrarySelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (updating || LibraryList.SelectedItem is not ListBoxItem item) return;
        Run(() => { selectedId = (Guid)item.Tag; RefreshEditor(); });
    }
    private void NewPack(object sender, RoutedEventArgs e)
    {
        var name = BloomDialog.AskName(this, "New cursor pack", "My bloom pack"); if (name is null) return;
        Run(() => { selectedId = library.AddPack(new() { Name = name }); packMode = true; selectedRole = "pointer"; Search.Text = ""; RebuildLibrary(); RefreshEditor(); });
    }
    private void Rename(object sender, RoutedEventArgs e)
    {
        if (SelectionPack is not { } pack || selectedId is not { } id) return;
        var name = BloomDialog.AskName(this, packMode ? "Rename pack" : "Rename cursor", packMode ? pack.Name : SelectedCursor!.Image.Name); if (name is null) return;
        Run(() => { if (packMode) library.RenamePack(id, name); else library.EditCursor(id, SelectedCursor!.Image with { Name = name }); RebuildLibrary(); RefreshEditor(); });
    }
    private const string ImageFilter = "Images (*.png;*.jpg;*.jpeg;*.gif;*.bmp;*.tif;*.tiff;*.ico)|*.png;*.jpg;*.jpeg;*.gif;*.bmp;*.tif;*.tiff;*.ico";
    private void ImportFiles(object sender, RoutedEventArgs e)
    {
        var picker = new OpenFileDialog { Title = "Add to Cute Cursor", Filter = "Cursor packs (*.cutecursor)|*.cutecursor|" + ImageFilter, FilterIndex = 2, Multiselect = true };
        if (picker.ShowDialog(this) == true) ImportPaths(picker.FileNames);
    }
    private void ImportPaths(IEnumerable<string> paths)
    {
        int added = 0; var failures = new List<string>();
        foreach (var path in paths)
        {
            try
            {
                packMode = Path.GetExtension(path).Equals(".cutecursor", StringComparison.OrdinalIgnoreCase);
                selectedId = packMode ? library.ImportPack(PackCodec.ReadFile(path)) : library.AddCursor(ImageCodec.Import(path)); added++;
            }
            catch (Exception ex) { failures.Add($"{Path.GetFileName(path)}: {ex.Message}"); }
        }
        Search.Text = ""; RebuildLibrary(); RefreshEditor(); Status.Text = $"Added {added} item{(added == 1 ? "" : "s")}. Multi-frame images use the first frame.";
        if (failures.Count != 0) BloomDialog.Message(this, "Some files couldn’t be imported", string.Join("\n\n", failures.Take(4)));
    }
    private void ChoosePhoto(object sender, RoutedEventArgs e)
    {
        var picker = new OpenFileDialog { Title = "Choose a cursor image", Filter = ImageFilter };
        if (picker.ShowDialog(this) != true) return;
        Run(() => { SaveSlot(ImageCodec.Import(picker.FileName)); RebuildLibrary(); RefreshEditor(); });
    }
    private void ChooseLibrary(object sender, RoutedEventArgs e)
    {
        var menu = new ContextMenu();
        if (library.State.Cursors.Count == 0) menu.Items.Add(new MenuItem { Header = "Import an image to your library first", IsEnabled = false });
        foreach (var cursor in library.State.Cursors.OrderByDescending(c => c.Favorite))
        {
            var item = new MenuItem { Header = new TextBlock { Text = cursor.Image.Name, TextTrimming = TextTrimming.CharacterEllipsis, MaxWidth = 270 } };
            item.Click += (_, _) => Run(() => { SaveSlot(cursor.Image); RebuildLibrary(); RefreshEditor(); }); menu.Items.Add(item);
        }
        OpenMenu(menu, (Button)sender);
    }
    private static void OpenMenu(ContextMenu menu, Button anchor) { menu.PlacementTarget = anchor; menu.Placement = PlacementMode.Bottom; menu.IsOpen = true; }
    private void More(object sender, RoutedEventArgs e)
    {
        var menu = new ContextMenu();
        void Add(string title, Action action) { var item = new MenuItem { Header = title }; item.Click += (_, _) => Run(action); menu.Items.Add(item); }
        if (packMode && SelectedSlot is not null) Add("Clear this role", () => { library.SetSlot(selectedId!.Value, selectedRole, null); RefreshEditor(); Status.Text = "Role cleared. Apply again to restore its original cursor."; });
        Add(packMode ? "Remove pack…" : "Remove cursor…", () =>
        {
            if (!BloomDialog.Confirm(this, packMode ? "Remove this pack?" : "Remove this cursor?", "Remove it from your library? Your original image files stay untouched.", "Remove")) return;
            if (packMode) { library.RemovePack(selectedId!.Value); selectedId = library.State.Packs.FirstOrDefault()?.Id; }
            else { library.RemoveCursor(selectedId!.Value); selectedId = library.State.Cursors.FirstOrDefault()?.Id; }
            RebuildLibrary(); RefreshEditor(); Status.Text = "Removed from your library. Restore is always available for applied cursors.";
        });
        Add("Exit and restore cursors", () => TryExit()); OpenMenu(menu, (Button)sender);
    }
    private void Export(object sender, RoutedEventArgs e)
    {
        if (SelectionPack is not { } pack) return;
        Run(() =>
        {
            var data = PackCodec.Write(pack, ImageCodec.Validate);
            var safeName = string.Concat(pack.Name.Select(c => Path.GetInvalidFileNameChars().Contains(c) ? '-' : c));
            var picker = new SaveFileDialog { Title = "Export cursor pack", Filter = "Cute Cursor pack|*.cutecursor", FileName = safeName + ".cutecursor", DefaultExt = ".cutecursor" };
            if (picker.ShowDialog(this) != true) return;
            var temporary = picker.FileName + "." + Guid.NewGuid() + ".tmp";
            try { File.WriteAllBytes(temporary, data); File.Move(temporary, picker.FileName, true); }
            finally { if (File.Exists(temporary)) File.Delete(temporary); }
            Status.Text = "Pack exported with its images, sizes, and click points.";
        });
    }
    private void Apply(object sender, RoutedEventArgs e) => Run(() =>
    {
        if (automation || SelectionPack is not { } pack) return;
        if (recoveryPending) throw new InvalidOperationException("Restore the previous session’s cursor scheme first, then apply your pack.");
        // Persist before any native mutation so crash recovery remains available.
        using (var file = new FileStream(recoveryPath, FileMode.Create, FileAccess.Write, FileShare.None)) { file.Write("Restore the configured Windows cursor scheme after an interrupted session."u8); file.Flush(true); }
        try { session.Apply(pack, VisualTreeHelper.GetDpi(this).DpiScaleX); }
        finally { if (!session.HasChanges && File.Exists(recoveryPath)) File.Delete(recoveryPath); }
        Status.Text = $"{pack.Name} is applied. Exit or Restore brings back your previous cursors.";
    });
    private void RestoreCursors()
    {
        if (automation) return;
        if (recoveryPending) NativeCursors.ReloadConfiguredScheme(); else session.Restore();
        if (File.Exists(recoveryPath)) File.Delete(recoveryPath);
        recoveryPending = false; Status.Text = "Your previous cursors are restored.";
    }
    private void Restore(object sender, RoutedEventArgs e) => Run(RestoreCursors);
    private void Help(object sender, RoutedEventArgs e) => BloomDialog.Message(this, "A little help", "Import an image, or choose a role in a pack. Set its size and click point, then Apply. Soft Bloom starts at size 40 (40 pixels at 100% display scale).\n\nPacks work on Mac and Windows. Windows supports nine system roles; Grab and Grabbing stay available for preview and sharing. Some apps draw their own cursors.\n\nClosing this window keeps Cute Cursor in the system tray. Choose Exit there to restore your originals. No administrator access is needed.\n\nTransparent PNGs work best. GIFs and other multi-frame images use the first frame. Native file pickers retain the Windows appearance.");
    private void FileDragOver(object sender, DragEventArgs e) { e.Effects = e.Data.GetDataPresent(DataFormats.FileDrop) ? DragDropEffects.Copy : DragDropEffects.None; e.Handled = true; }
    private void FileDropped(object sender, DragEventArgs e) { if (e.Data.GetData(DataFormats.FileDrop) is string[] paths) Run(() => ImportPaths(paths)); }
}
