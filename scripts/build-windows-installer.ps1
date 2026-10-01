$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $root 'Windows/CuteCursor.Windows/CuteCursor.Windows.csproj'
$version = ([xml](Get-Content $project -Raw)).Project.PropertyGroup.Version
foreach ($runtime in @('win-x64', 'win-arm64')) {
    if (!(Test-Path "$root/dist/windows/$runtime/CuteCursor.exe")) {
        throw "Publish $runtime with build-windows.ps1 before building the installer."
    }
}
$compiler = Get-Command ISCC.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
if (!$compiler) { $compiler = "${env:ProgramFiles(x86)}/Inno Setup 6/ISCC.exe" }
if (!(Test-Path $compiler)) { throw 'Install Inno Setup 6.3 or newer to build the Windows installer.' }
& $compiler "/DAppVersion=$version" "$root/Windows/Installer/CuteCursor.iss"
if ($LASTEXITCODE -ne 0) { throw 'Windows installer compilation failed.' }
$setup = Join-Path $root 'dist/Cute-Cursor-Setup.exe'
$hash = (Get-FileHash $setup -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  Cute-Cursor-Setup.exe" | Set-Content "$setup.sha256" -Encoding ascii
Write-Host 'Built unsigned beta installer. Publisher signing is still required for the planned signed release.'
