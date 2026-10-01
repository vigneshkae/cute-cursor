param([Parameter(Mandatory)][string]$Installer)
$ErrorActionPreference = 'Stop'
$Installer = (Resolve-Path $Installer).Path
if ($env:CI -ne 'true') { throw 'Installer lifecycle tests run only on an isolated CI runner.' }
$testRoot = Join-Path $env:RUNNER_TEMP ('cute-cursor-install-' + [guid]::NewGuid())
$installDir = Join-Path $testRoot 'Cute Cursor'
$library = Join-Path $env:LOCALAPPDATA 'CuteCursor'
New-Item -ItemType Directory -Force $library, $testRoot | Out-Null
$sentinel = Join-Path $library ('.installer-test-' + [guid]::NewGuid() + '.txt')
'User library data must survive installation, upgrade and uninstall.' | Set-Content $sentinel
$sentinelHash = (Get-FileHash $sentinel).Hash
function Invoke-Setup([string]$exe, [string[]]$arguments) {
    $process = Start-Process -FilePath $exe -ArgumentList $arguments -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "Installer process exited with $($process.ExitCode)." }
}
function Assert-LibraryPreserved {
    if (!(Test-Path $sentinel) -or (Get-FileHash $sentinel).Hash -ne $sentinelHash) {
        throw 'The installer modified user library data.'
    }
}
$argsList = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/DIR=`"$installDir`"")
try {
    Invoke-Setup $Installer ($argsList + "/LOG=`"$testRoot/install.log`"")
    Assert-LibraryPreserved
    $exe = Join-Path $installDir 'CuteCursor.exe'
    $bytes = [IO.File]::ReadAllBytes($exe)
    $pe = [BitConverter]::ToInt32($bytes, 0x3C)
    $isArm = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq 'Arm64'
    $expected = if ($isArm) { 0xAA64 } else { 0x8664 }
    if ([BitConverter]::ToUInt16($bytes, $pe + 4) -ne $expected) { throw 'Installer chose the wrong native architecture.' }
    if (!(Test-Path (Join-Path ([Environment]::GetFolderPath('Programs')) 'Cute Cursor.lnk'))) { throw 'Start menu shortcut missing.' }
    if (!(Test-Path (Join-Path $installDir 'LICENSE.txt'))) { throw 'License missing.' }
    $env:CUTE_CURSOR_SMOKE_RESULT = Join-Path $testRoot 'installed-smoke.json'
    Invoke-Setup $exe @('--self-test')
    if (!(Test-Path $env:CUTE_CURSOR_SMOKE_RESULT) -or !(Get-Content $env:CUTE_CURSOR_SMOKE_RESULT -Raw | ConvertFrom-Json).ok) {
        throw 'Installed app failed native smoke tests.'
    }
    $mutex = [Threading.Mutex]::new($false, 'Local\CuteCursor.Windows')
    try {
        $blocked = Start-Process $Installer -ArgumentList ($argsList + "/LOG=`"$testRoot/blocked.log`"") -Wait -PassThru
        if ($blocked.ExitCode -eq 0) { throw 'Installer ignored the running-app mutex.' }
    } finally { $mutex.Dispose() }
    Invoke-Setup $Installer ($argsList + "/LOG=`"$testRoot/upgrade.log`"")
    Assert-LibraryPreserved
    Invoke-Setup (Join-Path $installDir 'unins000.exe') @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART')
    if (Test-Path $exe) { throw 'Uninstaller left the application executable behind.' }
    if (Test-Path (Join-Path ([Environment]::GetFolderPath('Programs')) 'Cute Cursor.lnk')) { throw 'Uninstaller left the Start menu shortcut behind.' }
    Assert-LibraryPreserved
    Write-Host "PASS installer: native architecture, shortcut, installed app smoke tests, running-app protection, upgrade, uninstall and preserved library ($([Runtime.InteropServices.RuntimeInformation]::OSArchitecture))."
} finally {
    if (Test-Path $sentinel) { Remove-Item $sentinel }
}
