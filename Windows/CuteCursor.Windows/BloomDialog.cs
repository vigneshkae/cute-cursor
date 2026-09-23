namespace CuteCursor.Windows;

public sealed class BloomDialog : Window
{
    private readonly TextBox? input;
    public string Value => input?.Text.Trim() ?? "";
    private BloomDialog(Window? owner, string title, string message, string confirm, string? initial, bool cancellable)
    {
        Style = (Style)Application.Current.FindResource(typeof(Window));
        Title = title; Owner = owner; Width = 440; SizeToContent = SizeToContent.Height;
        ResizeMode = ResizeMode.NoResize; WindowStartupLocation = owner is null ? WindowStartupLocation.CenterScreen : WindowStartupLocation.CenterOwner;
        ShowInTaskbar = owner is null;
        var content = new StackPanel { Margin = new Thickness(26) };
        content.Children.Add(new TextBlock { Text = title, FontSize = 22, FontWeight = FontWeights.SemiBold, TextWrapping = TextWrapping.Wrap });
        content.Children.Add(new TextBlock { Text = message, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 14, 0, 20), LineHeight = 23 });
        if (initial is not null)
        {
            input = new TextBox { Text = initial, MaxLength = 80, Margin = new Thickness(0, 0, 0, 20) }; content.Children.Add(input);
            Loaded += (_, _) => { input.Focus(); input.SelectAll(); };
        }
        var row = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right };
        if (cancellable)
        {
            var cancel = new Button { Content = "Cancel", IsCancel = true, Margin = new Thickness(0, 0, 8, 0) }; row.Children.Add(cancel);
        }
        var ok = new Button { Content = confirm, IsDefault = true, Style = (Style)FindResource("Primary") };
        ok.Click += (_, _) => { if (input is not null && string.IsNullOrWhiteSpace(Value)) { input.Focus(); return; } DialogResult = true; };
        row.Children.Add(ok); content.Children.Add(row); Content = content;
    }
    public static bool Confirm(Window? owner, string title, string message, string confirm = "Continue") => new BloomDialog(owner, title, message, confirm, null, true).ShowDialog() == true;
    public static void Message(Window? owner, string title, string message) => new BloomDialog(owner, title, message, "OK", null, false).ShowDialog();
    public static string? AskName(Window owner, string title, string initial)
    {
        var dialog = new BloomDialog(owner, title, "Choose a name you’ll recognize in your library.", "Save", initial, true);
        return dialog.ShowDialog() == true ? dialog.Value : null;
    }
}
