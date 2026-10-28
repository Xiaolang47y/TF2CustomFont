#Requires -Version 5.1
<#
.SYNOPSIS
    Replace the font used by the TF2 "!000_customfont" mod.

.DESCRIPTION
    Reads the family name from a TTF/OTF file, copies it into the mod folder
    and regenerates resource/clientscheme.res + resource/chatscheme.res from
    the templates in tools\template\.

    Run it through tools\set-font.cmd (recommended) or directly with
    powershell -ExecutionPolicy Bypass -File tools\set-font.ps1 ...

.PARAMETER FontFile
    Path to the .ttf/.otf/.ttc file.

.PARAMETER Name
    Use this family name instead of the name stored in the font file.

.PARAMETER Hud
    Path to an installed custom HUD (or its resource folder).  The HUD's
    clientscheme.res/chatscheme.res is copied (including every #base file)
    into the mod, and the HUD's own scheme is renamed to
    *_customfont_original.res so it no longer shadows the mod.

.PARAMETER NoRange
    Do not force the font on the full Unicode range. Use it for Latin-only
    fonts if CJK text should fall back to a system font instead of showing
    empty boxes.

.PARAMETER Target
    Mod folder to patch. Default: <repo>\tf\custom\!000_customfont

.PARAMETER Restore
    Undo a previous -Hud patch and restore the HUD's own scheme files.

.EXAMPLE
    .\set-font.cmd C:\Fonts\Inter.ttf

.EXAMPLE
    .\set-font.cmd C:\Fonts\Comic.ttf -Name "Comic Sans MS"

.EXAMPLE
    .\set-font.cmd C:\Fonts\Inter.ttf -Hud "C:\...\tf\custom\flawhud"
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$FontFile,

    [string]$Name,

    [string]$Hud,

    [switch]$NoRange,

    [string]$Target,

    [switch]$Restore,

    [switch]$Help
)

$ErrorActionPreference = 'Stop'

$ScriptDir   = $PSScriptRoot
$RepoDir     = Split-Path -Parent $ScriptDir
$TemplateDir = Join-Path $ScriptDir 'template'
$BaseDir     = Join-Path $ScriptDir 'base'
$Marker      = 'TF2_CUSTOM_FONT_OVERRIDE'
$OutEncoding = [System.Text.Encoding]::Default
$HudResDir   = $null
$HudUsed     = $false

function Write-Say {
    param([string]$Text)
    Write-Host $Text
}
function Write-Ok {
    param([string]$Text)
    Write-Host "[+] $Text" -ForegroundColor Green
}
function Write-Warn {
    param([string]$Text)
    Write-Host "[!] $Text" -ForegroundColor Yellow
}
function Die {
    param([string]$Text)
    Write-Host "[x] $Text" -ForegroundColor Red
    exit 1
}

function Show-Usage {
    @'
set-font.cmd / set-font.ps1 - replace the font used by the TF2 "!000_customfont" mod.

Usage:
  tools\set-font.cmd <font.ttf> [options]

Options:
  -Name <name>     Use <name> instead of the family name stored in the file.
  -Hud <path>      Copy an installed custom HUD's scheme (including every
                   #base file) and move the HUD's own scheme aside, so the
                   mod is not shadowed.  Keeps the HUD's colours etc.
  -NoRange         Do not force the font on the full Unicode range (Latin-only
                   fonts: CJK text then falls back to a system font).
  -Target <path>   Mod folder to patch
                   (default: <repo>\tf\custom\!000_customfont).
  -Restore         Undo -Hud and restore the HUD's own scheme files.
  -Help            Show this help.

Examples:
  tools\set-font.cmd C:\Fonts\Inter.ttf
  tools\set-font.cmd C:\Fonts\Comic.ttf -Name "Comic Sans MS"
  tools\set-font.cmd C:\Fonts\Inter.ttf -Hud "C:\Program Files (x86)\Steam\steamapps\common\Team Fortress 2\tf\custom\flawhud"
  tools\set-font.cmd -Restore -Hud "C:\Program Files (x86)\Steam\steamapps\common\Team Fortress 2\tf\custom\flawhud"
'@ | Write-Host
}

function Resolve-HudResDir {
    if ([string]::IsNullOrWhiteSpace($Hud)) {
        Die '-Hud / -Restore requires a HUD path.'
    }
    try {
        $item = Get-Item -LiteralPath $Hud
    } catch {
        Die "HUD path not found: $Hud"
    }
    if (-not $item.PSIsContainer) {
        return $item.DirectoryName
    }

    $candidate = Join-Path $item.FullName 'resource'
    foreach ($dir in @($candidate, $item.FullName)) {
        foreach ($scheme in @('clientscheme', 'chatscheme')) {
            if ((Test-Path -LiteralPath (Join-Path $dir ($scheme + '.res'))) -or
                (Test-Path -LiteralPath (Join-Path $dir ($scheme + '_customfont_original.res')))) {
                return $dir
            }
        }
    }
    Die "no clientscheme.res/chatscheme.res found in $Hud (expected <hud>\resource\)"
}

function Restore-HudScheme {
    param([string]$Scheme)
    $original = Join-Path $HudResDir ($Scheme + '_customfont_original.res')
    $target   = Join-Path $HudResDir ($Scheme + '.res')

    if (-not (Test-Path -LiteralPath $original)) {
        Write-Warn "no backup found for ${Scheme}.res in $HudResDir"
        return
    }
    if ((Test-Path -LiteralPath $target) -and
        ([System.IO.File]::ReadAllText($target).Contains($Marker))) {
        Remove-Item -LiteralPath $target -Force
    }
    if (-not (Test-Path -LiteralPath $target)) {
        Move-Item -LiteralPath $original -Destination $target -Force
        Write-Ok "restored $target"
    } else {
        Write-Warn "not restoring ${target}: it exists and is not the font-mod wrapper"
    }
}

# Copy the scheme file and every #base/#include file below it, preserving the
# relative layout inside <hud>\resource.
function Copy-HudSchemeFile {
    param(
        [string]$SourcePath,
        [string]$OutRel,
        [string]$HudRoot,
        [string]$DestRoot,
        [hashtable]$Seen
    )
    $full = [System.IO.Path]::GetFullPath($SourcePath)
    if ($Seen.ContainsKey($full)) { return }
    $Seen[$full] = $true

    $dest = Join-Path $DestRoot $OutRel
    $parent = [System.IO.Path]::GetDirectoryName($dest)
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    Copy-Item -LiteralPath $full -Destination $dest -Force

    $text = [System.IO.File]::ReadAllText($full)
    foreach ($m in [regex]::Matches($text, '(?im)^\s*#(?:base|include)\s+"([^"]+)"')) {
        $inc = $m.Groups[1].Value.Replace('/', '\')
        $next = [System.IO.Path]::GetFullPath(
            (Join-Path ([System.IO.Path]::GetDirectoryName($full)) $inc))
        if (-not $next.StartsWith($HudRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Warn "skipping include outside the HUD: $($m.Groups[1].Value)"
            continue
        }
        $rel = $next.Substring($HudRoot.Length).TrimStart('\')
        Copy-HudSchemeFile -SourcePath $next -OutRel $rel -HudRoot $HudRoot `
            -DestRoot $DestRoot -Seen $Seen
    }
}

function Install-Base {
    param([string]$Scheme)

    $original = $null
    $target   = $null
    $source   = $null
    if ($HudResDir) {
        $original = Join-Path $HudResDir ($Scheme + '_customfont_original.res')
        $target   = Join-Path $HudResDir ($Scheme + '.res')
        if ((Test-Path -LiteralPath $target) -and
            -not ([System.IO.File]::ReadAllText($target).Contains($Marker))) {
            $source = $target
            if (Test-Path -LiteralPath $original) {
                Write-Warn "$original is an older backup; using the current HUD ${Scheme}.res."
            }
        } elseif (Test-Path -LiteralPath $original) {
            $source = $original
            Write-Ok "using the existing HUD backup ${Scheme}_customfont_original.res"
        } else {
            Write-Warn "HUD has no usable ${Scheme}.res; using the vanilla base."
        }
    }

    if (-not $source) {
        Copy-Item -LiteralPath (Join-Path $BaseDir ($Scheme + '.res')) `
            -Destination (Join-Path $ResDir ($Scheme + '_base.res')) -Force
        return
    }

    $hudRoot = $HudResDir.TrimEnd('\') + '\'
    $seen = @{}
    Copy-HudSchemeFile -SourcePath $source -OutRel ($Scheme + '_base.res') `
        -HudRoot $hudRoot -DestRoot $ResDir -Seen $seen

    if ($source -eq $target) {
        if (Test-Path -LiteralPath $original) {
            Write-Warn "keeping the existing backup $original; not overwriting it."
        } else {
            Move-Item -LiteralPath $target -Destination $original -Force
            Write-Ok "moved HUD ${Scheme}.res aside (backup: $(Split-Path -Leaf $original))"
        }
    }

    $script:HudUsed = $true
    Write-Ok "base: ${Scheme}.res from HUD ($HudResDir)"
}

function Find-Python {
    foreach ($name in @('python3', 'python', 'py')) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    return $null
}

function New-SchemeOverride {
    param([string]$Scheme)
    $tplPath = Join-Path $TemplateDir ($Scheme + '.res')
    if (-not (Test-Path -LiteralPath $tplPath)) {
        Die "template missing: $tplPath"
    }
    $text = [System.IO.File]::ReadAllText($tplPath, [System.Text.Encoding]::UTF8)
    $text = $text.Replace('__CUSTOM_FONT_NAME__', $Name).Replace('__CUSTOM_FONT_FILE__', $fontRel)
    if ($NoRange) {
        $kept = New-Object System.Collections.Generic.List[string]
        $skipRange = $false
        foreach ($line in ($text -split "`n")) {
            if ($line -match 'CUSTOMFONT:RANGE-BEGIN') { $skipRange = $true; continue }
            if ($line -match 'CUSTOMFONT:RANGE-END')   { $skipRange = $false; continue }
            if (-not $skipRange) { $kept.Add($line) }
        }
        $text = $kept -join "`n"
    }
    $outPath = Join-Path $ResDir ($Scheme + '.res')
    [System.IO.File]::WriteAllText($outPath, $text, $OutEncoding)
    Write-Ok "wrote $outPath"
}

# ---------------------------------------------------------------------------
# restore mode
# ---------------------------------------------------------------------------
if ($Restore) {
    $HudResDir = Resolve-HudResDir
    Restore-HudScheme 'clientscheme'
    Restore-HudScheme 'chatscheme'
    Write-Say ''
    Write-Say 'HUD schemes restored. Remove the font mod folder if you no longer need it.'
    exit 0
}

if ([string]::IsNullOrWhiteSpace($FontFile)) {
    Show-Usage
    exit 1
}

# ---------------------------------------------------------------------------
# font file
# ---------------------------------------------------------------------------
try {
    $FontFile = (Resolve-Path -LiteralPath $FontFile).ProviderPath
} catch {
    Die "font file not found: $FontFile"
}
if (-not (Test-Path -LiteralPath $FontFile -PathType Leaf)) {
    Die "font file not found: $FontFile"
}

$ext = [System.IO.Path]::GetExtension($FontFile).ToLowerInvariant()
if ('.ttf', '.otf', '.ttc', '.otc' -notcontains $ext) {
    Write-Warn "unusual file extension '$ext'; installing as customfont.ttf."
    $ext = '.ttf'
}

# ---------------------------------------------------------------------------
# target mod folder
# ---------------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($Target)) {
    $Target = Join-Path $RepoDir 'tf/custom/!000_customfont'
}
try {
    $Target = [System.IO.Path]::GetFullPath($Target)
} catch {
    Die "invalid target path: $Target"
}
if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
    Die "mod folder not found: $Target`nPoint -Target at ...\Team Fortress 2\tf\custom\!000_customfont"
}
$ResDir = Join-Path $Target 'resource'
if (-not (Test-Path -LiteralPath $ResDir -PathType Container)) {
    Die "no resource folder in $Target"
}

# ---------------------------------------------------------------------------
# optional HUD
# ---------------------------------------------------------------------------
if (-not [string]::IsNullOrWhiteSpace($Hud)) {
    $HudResDir = Resolve-HudResDir
}

# ---------------------------------------------------------------------------
# font family name
# ---------------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($Name)) {
    try {
        Add-Type -AssemblyName System.Drawing
        $collection = New-Object System.Drawing.Text.PrivateFontCollection
        $collection.AddFontFile($FontFile)
        if ($collection.Families.Count -gt 0) {
            $family = $collection.Families[0]
            # Prefer the en-US name: GDI's ANSI APIs are most reliable with it.
            try {
                $english = $family.GetName(0x0409)
                if (-not [string]::IsNullOrWhiteSpace($english)) {
                    $Name = $english
                }
            } catch { }
            if ([string]::IsNullOrWhiteSpace($Name)) {
                $Name = $family.Name
            }
        }
        $collection.Dispose()
    } catch {
        Write-Warn "could not read the font family name with GDI+: $($_.Exception.Message)"
    }
}
if ([string]::IsNullOrWhiteSpace($Name)) {
    $Name = [System.IO.Path]::GetFileNameWithoutExtension($FontFile)
    Write-Warn "falling back to the file name '$Name'."
    Write-Warn 'If the game keeps the old font, re-run with -Name "<exact family name>".'
}

if ($Name -match '[^\x00-\x7F]') {
    Write-Warn 'the family name contains non-ASCII characters.'
    Write-Warn 'GDI ANSI calls may not find it. Re-run with -Name "<English family name>" if the font does not apply.'
}

Write-Say "Font family : $Name"
Write-Say "Font file   : $FontFile"

Install-Base 'clientscheme'
Install-Base 'chatscheme'

# ---------------------------------------------------------------------------
# copy the font (read it first so the target file can be the input, too)
# ---------------------------------------------------------------------------
$fontBytes = [System.IO.File]::ReadAllBytes($FontFile)
$fontRel   = 'resource/customfont' + $ext

foreach ($old in [System.IO.Directory]::GetFiles($ResDir, 'customfont.*')) {
    if ([System.IO.Path]::GetFileName($old) -ne ('customfont' + $ext)) {
        Remove-Item -LiteralPath $old -Force -ErrorAction SilentlyContinue
    }
}

[System.IO.File]::WriteAllBytes((Join-Path $ResDir ('customfont' + $ext)), $fontBytes)
Write-Ok "installed $(Join-Path $ResDir ('customfont' + $ext))"

New-SchemeOverride 'clientscheme'
New-SchemeOverride 'chatscheme'

# Inject HUD-only font families.  The Python helper has the full parser; if
# Python is unavailable the vanilla families are still replaced correctly.
$Python = Find-Python
$Helper = Join-Path $ScriptDir 'dev/hud_scheme.py'
if ($HudUsed -and $Python -and (Test-Path -LiteralPath $Helper)) {
    foreach ($scheme in @('clientscheme', 'chatscheme')) {
        & $Python $Helper inject $scheme $HudResDir $ResDir $Name
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "HUD font injection failed for $scheme (vanilla families are still replaced)."
        }
    }
} elseif ($HudUsed) {
    Write-Warn 'Python was not found: HUD-only font families were not added.'
    Write-Warn 'Install Python 3 and re-run for full HUD font coverage.'
}

# ---------------------------------------------------------------------------
# load-order check: tf/custom/* is mounted alphabetically and the first match
# wins, so an earlier folder shadows this one.
# ---------------------------------------------------------------------------
$customDir = Split-Path -Parent $Target
$targetName = Split-Path -Leaf $Target
if (Test-Path -LiteralPath $customDir -PathType Container) {
    $folders = New-Object System.Collections.Generic.List[string]
    foreach ($d in [System.IO.Directory]::GetDirectories($customDir)) {
        $folders.Add([System.IO.Path]::GetFileName($d))
    }
    $folders.Sort([System.StringComparer]::Ordinal)
    foreach ($f in $folders) {
        if ($f -eq $targetName) { break }
        if (Test-Path -LiteralPath (Join-Path $customDir ($f + '\resource\clientscheme.res'))) {
            Write-Warn "'$f' is searched before '$targetName' and has a clientscheme.res."
            Write-Warn "The mod will not work. Use -Hud '$customDir\$f' or rename its scheme."
            break
        }
    }
}

Write-Say ''
Write-Say 'Done. Files patched in:'
Write-Say "  $Target"
Write-Say ''
Write-Say "Install / update: copy 'tf\custom\!000_customfont' into"
Write-Say '  <Steam>\steamapps\common\Team Fortress 2\tf\custom\'
Write-Say "then restart TF2, or type 'hud_reloadscheme' in the developer console."
Write-Say ''
Write-Say 'Notes:'
Write-Say '  - Linux users can run tools/set-font.sh instead.'
Write-Say '  - If text is still the old font, check that the family name matches exactly'
Write-Say '    and that no HUD/mod with a clientscheme.res sorts before !000_customfont.'
Write-Say '  - -Hud renames the HUD scheme to *_customfont_original.res; use -Restore to undo.'
exit 0
