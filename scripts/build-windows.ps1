param([ValidateSet("win-x64", "win-arm64")][string]$Runtime = "win-x64")
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$output = Join-Path $root "dist/windows/$Runtime"
$project = Join-Path $root "Windows/CuteCursor.Windows/CuteCursor.Windows.csproj"
New-Item -ItemType Directory -Force -Path $output | Out-Null
# Local development packaging only. No signing, uploading, registry edits, or install.
dotnet publish $project -c Release -r $Runtime --self-contained true -o $output `
    -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:PublishTrimmed=false -p:DebugType=None -p:DebugSymbols=false
if ($LASTEXITCODE -ne 0) { throw "Windows publish failed ($LASTEXITCODE)." }
$exe = Join-Path $output "CuteCursor.exe"
if (!(Test-Path $exe)) { throw "The app executable is missing." }
$bytes = [System.IO.File]::ReadAllBytes($exe)
if ($bytes[0] -ne 0x4D -or $bytes[1] -ne 0x5A) { throw "The published app is not a Windows executable." }
$pe = [BitConverter]::ToInt32($bytes, 0x3C)
if ([BitConverter]::ToUInt32($bytes, $pe) -ne 0x4550) { throw "Invalid Windows PE header." }
$expectedMachine = if ($Runtime -eq "win-x64") { 0x8664 } else { 0xAA64 }
if ([BitConverter]::ToUInt16($bytes, $pe + 4) -ne $expectedMachine) { throw "Executable architecture does not match $Runtime." }
$architecture = if ($Runtime -eq "win-x64") { "x64" } else { "ARM64" }
$zip = Join-Path $root "dist/Cute-Cursor-Windows-$architecture.zip"
@"
Cute Cursor 0.3.2 beta - Windows $architecture

Extract the whole ZIP, then open CuteCursor.exe. Keep LICENSE.txt with it.
This package includes .NET; you do not need to install it separately.
Choose x64 for Intel/AMD PCs or ARM64 for Windows-on-ARM PCs.
Find your system type in Windows Settings > System > About.

Includes 20 cursor choices and the Soft Bloom pack, initially at size 40.
System Default restores the configured Windows cursor scheme, size and colors.
Closing the window keeps the app in the tray; Exit restores previous cursors.
Grab and Grabbing are preview-only. Nine other roles apply system-wide.

This is an unsigned beta for Windows 11 testing, not a signed final release.
"@ | Set-Content (Join-Path $output "READ-ME.txt") -Encoding utf8
Compress-Archive -Path $exe, (Join-Path $output "LICENSE.txt"), (Join-Path $output "READ-ME.txt") -DestinationPath $zip -Force
$hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $(Split-Path -Leaf $zip)" | Set-Content "$zip.sha256" -Encoding ascii
Write-Host "Unsigned development package: $zip"
Write-Host "This is not a signed public release. Nothing was uploaded."
