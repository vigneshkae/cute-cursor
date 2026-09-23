namespace CuteCursor.Windows;
internal sealed class BloomTrayColors : System.Windows.Forms.ProfessionalColorTable
{
    private static System.Drawing.Color Cream => System.Drawing.Color.FromArgb(251, 250, 240);
    public override System.Drawing.Color MenuItemSelected => System.Drawing.Color.FromArgb(236, 239, 220);
    public override System.Drawing.Color MenuItemBorder => System.Drawing.Color.FromArgb(92, 120, 74);
    public override System.Drawing.Color MenuBorder => System.Drawing.Color.FromArgb(225, 229, 214);
    public override System.Drawing.Color ToolStripDropDownBackground => Cream;
    public override System.Drawing.Color ImageMarginGradientBegin => Cream;
    public override System.Drawing.Color ImageMarginGradientMiddle => Cream;
    public override System.Drawing.Color ImageMarginGradientEnd => Cream;
}
