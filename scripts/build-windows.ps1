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
$zip = Join-Path $root "dist/CuteCursor-windows-preview-$Runtime.zip"
Compress-Archive -Path $exe, (Join-Path $output "LICENSE.txt") -DestinationPath $zip -Force
$hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $(Split-Path -Leaf $zip)" | Set-Content "$zip.sha256" -Encoding ascii
Write-Host "Unsigned development package: $zip"
Write-Host "This is not a signed public release. Nothing was uploaded."
