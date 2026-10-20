<#
.SYNOPSIS
    Builds output\bg3_mcm.pak from the folder "Mod Configuration Menu" (the package content of the mod).

.DESCRIPTION
    This fork adds a build and releases to Volitio's Mod Configuration Menu (https://github.com/AtilioA/BG3-MCM),
    which has no GitHub releases (see FORK.md). The script:
      1. copies "Mod Configuration Menu" into output\stage, without editor folders (.vscode);
      2. converts every Localization\<Language>\*.loca.xml into the binary *.loca that the game reads, and leaves the
         .loca.xml sources out of the package;
      3. packs output\stage into output\bg3_mcm.pak with Divine.exe (LSLib) and lists the package contents.
    The mod files themselves stay as the author wrote them: UUID, folder (BG3MCM), name and version do not change.

    Divine.exe comes from _tools\lslib\Packed\Tools in a parent folder of the repository, or from $env:BG3_TOOLS.
    With -Deploy (or -ModsDir), deploy.ps1 then copies the .pak into the game's Mods folder.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\build.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\build.ps1 -Deploy
#>
param(
    # Copy the package to the game's Mods folder after the build (see deploy.ps1 for the default folder).
    [switch]$Deploy,
    # Mods folder for the deployment; implies -Deploy.
    [string]$ModsDir
)

$ErrorActionPreference = "Stop"

$PakName = "bg3_mcm"
$root = $PSScriptRoot
$source = Join-Path $root "Mod Configuration Menu"
$output = Join-Path $root "output"
$stage = Join-Path $output "stage"
$pak = Join-Path $output "$PakName.pak"

# The shared tools: $env:BG3_TOOLS, else the first _tools folder above the repository.
function Find-Tools {
    if ($env:BG3_TOOLS) {
        return $env:BG3_TOOLS
    }
    $dir = Split-Path $root -Parent
    while ($dir) {
        $candidate = Join-Path $dir "_tools"
        if (Test-Path $candidate) {
            return $candidate
        }
        $dir = Split-Path $dir -Parent
    }
    throw "No _tools folder above $root. Put LSLib (https://github.com/Norbyte/lslib/releases) into a folder _tools\lslib above the repository, or set BG3_TOOLS."
}

$divine = Join-Path (Find-Tools) "lslib\Packed\Tools\Divine.exe"
if (-not (Test-Path $divine)) {
    throw "$divine not found. Put LSLib (https://github.com/Norbyte/lslib/releases) into _tools\lslib, or set BG3_TOOLS."
}

# 1. A clean copy. robocopy takes the paths literally ("[PAK]_UI" has wildcard characters for PowerShell).
if (Test-Path -LiteralPath $stage) {
    Remove-Item -LiteralPath $stage -Recurse -Force
}
& robocopy $source $stage /E /XD .vscode /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) {
    throw "robocopy failed with exit code $LASTEXITCODE"
}

# 2. The texts: .loca.xml (source) -> .loca (what the game reads).
$sources = @(Get-ChildItem -LiteralPath (Join-Path $stage "Localization") -Recurse -File -Filter "*.loca.xml")
if ($sources.Count -eq 0) {
    throw "No Localization\<Language>\*.loca.xml files found in $source."
}
foreach ($xml in $sources) {
    $loca = $xml.FullName.Substring(0, $xml.FullName.Length - ".xml".Length)
    & $divine --game bg3 --action convert-loca --source $xml.FullName --destination $loca --loglevel warn
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $loca)) {
        throw "Divine.exe convert-loca failed for $($xml.FullName) (exit code $LASTEXITCODE)"
    }
    Remove-Item -LiteralPath $xml.FullName
    Write-Host "Converted $($xml.Name) -> $(Split-Path $loca -Leaf)"
}

# 3. The package.
if (Test-Path -LiteralPath $pak) {
    Remove-Item -LiteralPath $pak
}
& $divine --game bg3 --action create-package --source $stage --destination $pak --compression-method lz4 --loglevel warn
if ($LASTEXITCODE -ne 0) {
    throw "Divine.exe create-package failed with exit code $LASTEXITCODE"
}
Remove-Item -LiteralPath $stage -Recurse -Force

Write-Host "Package contents (without Lua files):"
$contents = & $divine --game bg3 --action list-package --source $pak --loglevel warn
if ($LASTEXITCODE -ne 0) {
    throw "Divine.exe list-package failed with exit code $LASTEXITCODE"
}
$contents | Where-Object { $_ -notmatch '\.lua\t' } | ForEach-Object { Write-Host "  $_" }
Write-Host "Lua files: $(@($contents | Where-Object { $_ -match '\.lua\t' }).Count)"
Write-Host "Built $pak"

if ($Deploy -or $ModsDir) {
    $deployArgs = @{}
    if ($ModsDir) {
        $deployArgs.ModsDir = $ModsDir
    }
    & (Join-Path $root "deploy.ps1") @deployArgs
    exit $LASTEXITCODE
}
