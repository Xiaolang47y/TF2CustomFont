#Requires -Version 5.1
<#
.SYNOPSIS
    Replace the fonts used by the TF2 "!000_customfont" mod, one font per role.

.DESCRIPTION
    TF2 uses four original fonts (tf2.ttf, tf2build.ttf, tf2secondary.ttf and
    tf2professor.ttf) for different kinds of text.  They are exposed as the
    roles tf2, build, secondary and professor.  Three more roles cover the rest
    of the text: body (Verdana/Arial/...), numbers ("Team Fortress", HUD
    numbers/ammo) and hud (families only a custom HUD defines).

    Every role can use a different TTF/OTF file, or keep its original family.
    The script reads the family name from each file, copies the files into the
    mod and regenerates resource/clientscheme.res + resource/chatscheme.res from
    the templates in tools\template\.

    Run it through tools\set-font.cmd (recommended) or directly with
    powershell -ExecutionPolicy Bypass -File tools\set-font.ps1 ...

.PARAMETER FontFile
    Default font file for every role that is not assigned explicitly.

.PARAMETER Font
    ROLE=FILE.  Assign several roles at once by putting the entries in one
    quoted argument, e.g.
    -Font "tf2=2.ttf,build=1.ttf,secondary=1.ttf,professor=2.ttf".
    (PowerShell does not allow the same parameter name twice.)
    ROLE is one of tf2, build, secondary, professor, body, numbers, hud
    (aliases: tf2build, tf2secondary, tf2professor). Use -Font all=FILE to set
    the default font.

.PARAMETER Keep
    Role list to leave on its original family, e.g. -Keep numbers or
    -Keep "numbers,hud".

.PARAMETER Name
    Use this family name instead of the name stored in the font file.
    -Name "ROLE=NAME" overrides only that role; separate several entries with
    commas, e.g. -Name "build=Font One,tf2=Font Two".

.PARAMETER ListFonts
    Show the selectable roles and their original families.

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
    .\set-font.cmd -Font "build=1.ttf,secondary=1.ttf,tf2=2.ttf,professor=2.ttf"

.EXAMPLE
    .\set-font.cmd C:\Fonts\Inter.ttf -Keep numbers

.EXAMPLE
    .\set-font.cmd -Font "tf2=C:\Fonts\2.ttf,build=C:\Fonts\1.ttf" -Hud "C:\...\tf\custom\flawhud"
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$FontFile,

    [string[]]$Font,

    [string[]]$Keep,

    [string[]]$Name,

    [string]$Hud,

    [switch]$NoRange,

    [string]$Target,

    [switch]$Restore,

    [switch]$ListFonts,

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

$RoleNames   = @('tf2', 'build', 'secondary', 'professor', 'body', 'numbers', 'hud')
$RoleOrigins = @('TF2', 'TF2 Build', 'TF2 Secondary', 'TF2 Professor',
                 'Verdana, Arial, Tahoma, ...', 'Team Fortress', 'HUD-only families')

$RoleFile    = @{}
$RoleKeep    = @{}
$RoleName    = @{}
$RoleTarget  = @{}
foreach ($r in $RoleNames) {
    $RoleFile[$r]   = ''
    $RoleKeep[$r]   = $false
    $RoleName[$r]   = ''
    $RoleTarget[$r] = ''
}

$GlobalName  = ''
$FamilyCache = @{}
$Regs        = New-Object System.Collections.Generic.List[object]

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
set-font.cmd / set-font.ps1 - replace the fonts used by the TF2 "!000_customfont" mod.

Usage:
  tools\set-font.cmd <font.ttf> [options]
  tools\set-font.cmd -Font "tf2=2.ttf,build=1.ttf,secondary=1.ttf,professor=2.ttf"

Roles (each can use a different font):
  tf2 = TF2              build     = TF2 Build
  secondary = TF2 Secondary        professor = TF2 Professor
  body = Verdana/Arial/...         numbers   = Team Fortress (HUD numbers)
  hud = families only a custom HUD defines

Options:
  -Font ROLE=FILE  Use FILE for ROLE. Put several entries in one quoted
                   argument, e.g. -Font "build=1.ttf,tf2=2.ttf" (PowerShell
                   does not allow the same parameter twice). The roles tf2build,
                   tf2secondary and tf2professor are aliases for build,
                   secondary and professor. Use -Font all=FILE for the default.
  -Keep <roles>    Keep the original family for the given role(s), e.g.
                   -Keep numbers or -Keep "numbers,hud".
  -Name <name>     Use <name> instead of the family name stored in the file.
                   -Name "ROLE=NAME" overrides only that role; separate several
                   entries with commas, e.g. -Name "build=Font One,tf2=Font Two".
  -ListFonts       Show the selectable roles and their original families.
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
  tools\set-font.cmd C:\Fonts\Inter.ttf -Keep numbers
  tools\set-font.cmd -Font "build=C:\Fonts\1.ttf,secondary=C:\Fonts\1.ttf,tf2=C:\Fonts\2.ttf,professor=C:\Fonts\2.ttf"
  tools\set-font.cmd C:\Fonts\Inter.ttf -Hud "C:\Program Files (x86)\Steam\steamapps\common\Team Fortress 2\tf\custom\flawhud"
  tools\set-font.cmd -Restore -Hud "C:\Program Files (x86)\Steam\steamapps\common\Team Fortress 2\tf\custom\flawhud"
'@ | Write-Host
}

function Show-Roles {
    Write-Say 'Selectable roles (use -Font ROLE=FILE or -Keep ROLE):'
    for ($i = 0; $i -lt $RoleNames.Count; $i++) {
        $alias = ''
        switch ($RoleNames[$i]) {
            'build'     { $alias = '  (alias: tf2build)' }
            'secondary' { $alias = '  (alias: tf2secondary)' }
            'professor' { $alias = '  (alias: tf2professor)' }
        }
        Write-Say ('  {0,-11} {1,-30}{2}' -f $RoleNames[$i], $RoleOrigins[$i], $alias)
    }
    Write-Say ''
    Write-Say 'Unassigned roles keep their original family.  The positional font'
    Write-Say 'file (or -Font all=FILE) sets the default for every role.'
}

function Get-RoleIndex {
    param([string]$Role)
    switch ($Role) {
        'tf2'                 { return 0 }
        'build'               { return 1 }
        'tf2build'            { return 1 }
        'secondary'           { return 2 }
        'tf2secondary'        { return 2 }
        'professor'           { return 3 }
        'tf2professor'        { return 3 }
        'body'                { return 4 }
        'numbers'             { return 5 }
        'hud'                 { return 6 }
        'tf2.ttf'             { return 0 }
        'tf2build.ttf'        { return 1 }
        'tf2secondary.ttf'    { return 2 }
        'tf2professor.ttf'    { return 3 }
    }
    return -1
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
        $rel = $next.Substring($HudRoot.Length).TrimStart('\', '/')
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

    $hudRoot = $HudResDir.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
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
    foreach ($candidate in @('python3', 'python', 'py')) {
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    return $null
}

function Resolve-FontPath {
    param([string]$Path, [string]$Role)
    try {
        $full = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    } catch {
        if ($Role) { Die "font file not found for ${Role}: $Path" }
        Die "font file not found: $Path"
    }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        if ($Role) { Die "font file not found for ${Role}: $Path" }
        Die "font file not found: $Path"
    }
    return $full
}

function Get-FontExtension {
    param([string]$Path)
    $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    if (@('.ttf', '.otf', '.ttc', '.otc') -contains $ext) {
        return $ext
    }
    Write-Warn "unusual file extension '$ext'; installing as .ttf (the game expects a TrueType/OpenType font)"
    return '.ttf'
}

function Get-FontFamily {
    param([string]$Path)
    $collection = $null
    try {
        Add-Type -AssemblyName System.Drawing
        $collection = New-Object System.Drawing.Text.PrivateFontCollection
        $collection.AddFontFile($Path)
        if ($collection.Families.Count -gt 0) {
            $family = $collection.Families[0]
            # Prefer the en-US name: GDI's ANSI APIs are most reliable with it.
            try {
                $english = $family.GetName(0x0409)
                if (-not [string]::IsNullOrWhiteSpace($english)) {
                    return $english
                }
            } catch { }
            if (-not [string]::IsNullOrWhiteSpace($family.Name)) {
                return $family.Name
            }
        }
    } catch {
        Write-Warn "could not read the font family name with GDI+: $($_.Exception.Message)"
    } finally {
        if ($null -ne $collection) { $collection.Dispose() }
    }
    return $null
}

function ConvertTo-ResString {
    param([string]$Text)
    return $Text.Replace('\', '\\').Replace('"', '\"')
}

# Build the CustomFontFiles section for the selected fonts (one entry per
# unique family).  The template marks the section with CUSTOM-FILE-BEGIN/END.
function New-CustomFontBlock {
    $tab  = "`t"
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add($tab + '// CUSTOMFONT:CUSTOM-FILE-BEGIN')
    $lines.Add($tab + '// Registered only when a role uses a custom font file.')
    $lines.Add($tab + 'CustomFontFiles')
    $lines.Add($tab + '{')
    for ($i = 0; $i -lt $Regs.Count; $i++) {
        $reg = $Regs[$i]
        $lines.Add($tab + $tab + '"' + ($i + 1000) + '"')
        $lines.Add($tab + $tab + '{')
        $lines.Add($tab + $tab + $tab + '"font"' + $tab + '"' + (ConvertTo-ResString $reg.Dest) + '"')
        $lines.Add($tab + $tab + $tab + '"name"' + $tab + '"' + (ConvertTo-ResString $reg.Name) + '"')
        $lines.Add('')
        if (-not $NoRange) {
            $lines.Add($tab + $tab + $tab + '// CUSTOMFONT:RANGE-BEGIN')
            $lines.Add($tab + $tab + $tab + '// The range blocks make the engine use the replacement font for')
            $lines.Add($tab + $tab + $tab + '// the whole Unicode range instead of falling back to a system font.')
            $lines.Add($tab + $tab + $tab + '// Remove them (or use -NoRange) if the font only has')
            $lines.Add($tab + $tab + $tab + '// Latin glyphs and you want CJK text to fall back to a system font.')
            foreach ($lang in @('english', 'german', 'french', 'italian', 'korean',
                                'spanish', 'schinese', 'tchinese', 'russian', 'thai',
                                'japanese', 'portuguese', 'brazilian', 'latam', 'polish',
                                'danish', 'dutch', 'finnish', 'norwegian', 'swedish',
                                'czech', 'hungarian', 'romanian', 'turkish', 'bulgarian',
                                'greek', 'ukrainian', 'vietnamese')) {
                $lines.Add($tab + $tab + $tab + '"' + $lang + '"' + $tab + '{ "range" "0x0000 0xFFFF" }')
            }
            $lines.Add($tab + $tab + $tab + '// CUSTOMFONT:RANGE-END')
        }
        $lines.Add($tab + $tab + '}')
        if ($i -lt $Regs.Count - 1) { $lines.Add('') }
    }
    $lines.Add($tab + '}')
    $lines.Add($tab + '// CUSTOMFONT:CUSTOM-FILE-END')
    return $lines
}

function New-SchemeOverride {
    param([string]$Scheme)
    $tplPath = Join-Path $TemplateDir ($Scheme + '.res')
    if (-not (Test-Path -LiteralPath $tplPath)) {
        Die "template missing: $tplPath"
    }
    $text  = [System.IO.File]::ReadAllText($tplPath, [System.Text.Encoding]::UTF8)
    $block = New-CustomFontBlock

    # Replace the CustomFontFiles section line by line.  Plain .Replace is used
    # for the placeholders, so '&' and '\' in family names stay literal.
    $out = New-Object System.Collections.Generic.List[string]
    $inBlock = $false
    foreach ($line in ($text -split "`n")) {
        $line = $line -replace "`r$", ''
        if ($line -match 'CUSTOMFONT:CUSTOM-FILE-BEGIN') {
            foreach ($b in $block) { $out.Add($b) }
            $inBlock = $true
            continue
        }
        if ($line -match 'CUSTOMFONT:CUSTOM-FILE-END') {
            $inBlock = $false
            continue
        }
        if ($inBlock) { continue }
        $out.Add($line)
    }

    if ($NoRange) {
        $kept = New-Object System.Collections.Generic.List[string]
        $skipRange = $false
        foreach ($line in $out) {
            if ($line -match 'CUSTOMFONT:RANGE-BEGIN') { $skipRange = $true; continue }
            if ($line -match 'CUSTOMFONT:RANGE-END')   { $skipRange = $false; continue }
            if (-not $skipRange) { $kept.Add($line) }
        }
        $out = $kept
    }

    $content = $out -join "`n"
    $content = $content.Replace('__CUSTOM_FONT_SUMMARY__', $Summary)
    $content = $content.Replace('__CUSTOM_FONT_NAME__', $PrimaryFamily)
    $content = $content.Replace('__CUSTOM_FONT_FILE__', $PrimaryFile)

    # Without Python only one family can be applied; remap is required when a
    # role keeps its original family or uses a second font.  Check before
    # writing so a failed run does not leave a half-patched scheme behind.
    $canRemap = ($Python -and (Test-Path -LiteralPath $Helper))
    if (-not $canRemap) {
        $customCount = 0
        foreach ($r in $RoleNames) {
            if ($RoleTarget[$r] -ne 'keep') { $customCount++ }
        }
        if (($customCount -ne $RoleNames.Count) -or ($Regs.Count -ne 1)) {
            Die 'Python is required to assign different fonts to different roles or to keep a role.'
        }
    }

    $outPath = Join-Path $ResDir ($Scheme + '.res')
    [System.IO.File]::WriteAllText($outPath, $content, $OutEncoding)

    if ($canRemap) {
        & $Python $Helper remap $Scheme $ResDir $RoleSpec
        if ($LASTEXITCODE -ne 0) {
            Die "failed to remap $Scheme.res for the selected roles"
        }
    }

    if ($HudUsed -and $HudResDir) {
        if ($canRemap) {
            & $Python $Helper inject $Scheme $HudResDir $ResDir $RoleSpec
            if ($LASTEXITCODE -ne 0) {
                Write-Warn "could not add the HUD's extra font names; its own text fonts may stay unchanged."
            }
        } else {
            Write-Warn 'Python was not found: HUD-only font families were not added.'
            Write-Warn 'Install Python 3 and re-run for full HUD font coverage.'
        }
    }

    Write-Ok "wrote $outPath"
}

# ---------------------------------------------------------------------------
# help / role list
# ---------------------------------------------------------------------------
if ($Help) {
    Show-Usage
    exit 0
}
if ($ListFonts) {
    Show-Roles
    exit 0
}

# ---------------------------------------------------------------------------
# parse -Font / -Keep / -Name
# ---------------------------------------------------------------------------
if ($null -ne $Font) {
    foreach ($spec in $Font) {
        foreach ($entry in ($spec -split ',')) {
            $entry = $entry.Trim()
            if ([string]::IsNullOrWhiteSpace($entry)) { continue }
            $eq = $entry.IndexOf('=')
            if ($eq -lt 1) {
                Die "-Font expects ROLE=FILE, got '$entry'"
            }
            $roleKey = $entry.Substring(0, $eq).Trim().ToLowerInvariant()
            $rolePath = $entry.Substring($eq + 1).Trim()
            if ($roleKey -eq 'all') {
                $FontFile = $rolePath
            } else {
                $idx = Get-RoleIndex $roleKey
                if ($idx -lt 0) {
                    Die "unknown role '$roleKey' (use -ListFonts)"
                }
                $RoleFile[$RoleNames[$idx]] = $rolePath
                $RoleKeep[$RoleNames[$idx]] = $false
            }
        }
    }
}

if ($null -ne $Keep) {
    foreach ($list in $Keep) {
        foreach ($item in ($list -split ',')) {
            $roleKey = $item.Trim().ToLowerInvariant()
            if ([string]::IsNullOrWhiteSpace($roleKey)) { continue }
            $idx = Get-RoleIndex $roleKey
            if ($idx -lt 0) {
                Die "unknown role '$roleKey' (use -ListFonts)"
            }
            $RoleFile[$RoleNames[$idx]] = ''
            $RoleKeep[$RoleNames[$idx]] = $true
        }
    }
}

if ($null -ne $Name) {
    foreach ($spec in $Name) {
        foreach ($entry in ($spec -split ',')) {
            $entry = $entry.Trim()
            if ([string]::IsNullOrWhiteSpace($entry)) { continue }
            $eq = $entry.IndexOf('=')
            if ($eq -gt 0) {
                $roleKey = $entry.Substring(0, $eq).Trim().ToLowerInvariant()
                $idx = Get-RoleIndex $roleKey
                if ($idx -ge 0) {
                    $RoleName[$RoleNames[$idx]] = $entry.Substring($eq + 1).Trim()
                    continue
                }
            }
            $GlobalName = $entry
        }
    }
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

# ---------------------------------------------------------------------------
# font file (default for every role without an explicit -Font)
# ---------------------------------------------------------------------------
$anyRoleFont = $false
foreach ($r in $RoleNames) {
    if (-not [string]::IsNullOrWhiteSpace($RoleFile[$r])) { $anyRoleFont = $true; break }
}
if ([string]::IsNullOrWhiteSpace($FontFile)) {
    if (-not $anyRoleFont) {
        Show-Usage
        exit 1
    }
} else {
    $FontFile = Resolve-FontPath $FontFile ''
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

Install-Base 'clientscheme'
Install-Base 'chatscheme'

# ---------------------------------------------------------------------------
# assign roles and build the unique font registrations
# ---------------------------------------------------------------------------
foreach ($role in $RoleNames) {
    $targetFamily = ''
    if ($RoleKeep[$role]) {
        $targetFamily = 'keep'
        if ($RoleName[$role]) {
            Write-Warn "-Name for $role ignored because the role is kept"
        }
    } else {
        $source = $RoleFile[$role]
        if ([string]::IsNullOrWhiteSpace($source)) { $source = $FontFile }
        if ([string]::IsNullOrWhiteSpace($source)) {
            $targetFamily = 'keep'
        } else {
            $source = Resolve-FontPath $source $role
            if ($RoleName[$role]) {
                $familyName = $RoleName[$role]
            } elseif ($GlobalName) {
                $familyName = $GlobalName
            } elseif ($FamilyCache.ContainsKey($source)) {
                $familyName = $FamilyCache[$source]
            } else {
                $familyName = Get-FontFamily $source
                if ([string]::IsNullOrWhiteSpace($familyName)) {
                    $familyName = [System.IO.Path]::GetFileNameWithoutExtension($source)
                    Write-Warn "could not read the font family name of $source; falling back to '$familyName'."
                    Write-Warn 'If the game shows the old font, re-run with -Name "<exact family name>".'
                }
                $FamilyCache[$source] = $familyName
            }
            if ([string]::IsNullOrWhiteSpace($familyName)) {
                Die "empty font name for $role"
            }
            if ($familyName -match '[^\x00-\x7F]') {
                Write-Warn "the family name '$familyName' contains non-ASCII characters."
                Write-Warn 'GDI ANSI calls may not find it. Re-run with -Name "<English family name>" if the font does not apply.'
            }

            # The engine indexes custom fonts by family name, so one family can
            # only be registered once even if several files contain it.
            $found = -1
            for ($i = 0; $i -lt $Regs.Count; $i++) {
                if ($Regs[$i].Name -eq $familyName) { $found = $i; break }
            }
            if ($found -ge 0) {
                if ($Regs[$found].Path -ne $source) {
                    Write-Warn "family '$familyName' appears in both $($Regs[$found].Path) and $source; using the first file."
                }
            } else {
                $Regs.Add([pscustomobject]@{
                    Path      = $source
                    Name      = $familyName
                    Ext       = (Get-FontExtension $source)
                    Dest      = ''
                    FirstRole = $role
                })
            }
            $targetFamily = $familyName
        }
    }
    $RoleTarget[$role] = $targetFamily
}

# Destination names: keep the historical customfont.<ext> for a single font,
# otherwise one file per role so every registration stays reachable.
for ($i = 0; $i -lt $Regs.Count; $i++) {
    if ($Regs.Count -eq 1) {
        $Regs[$i].Dest = 'resource/customfont' + $Regs[$i].Ext
    } else {
        $Regs[$i].Dest = 'resource/customfont_' + $Regs[$i].FirstRole + $Regs[$i].Ext
    }
}

# ---------------------------------------------------------------------------
# role map ("role=family|role=keep") and the header summary
# ---------------------------------------------------------------------------
$RoleSpec    = ''
$Summary     = ''
$PrimaryFamily = 'keep'
$PrimaryFile   = 'resource/customfont.ttf'
if ($Regs.Count -gt 0) {
    $PrimaryFamily = $Regs[0].Name
    $PrimaryFile   = $Regs[0].Dest
}

Write-Say 'Role mapping:'
for ($i = 0; $i -lt $RoleNames.Count; $i++) {
    $role   = $RoleNames[$i]
    $mapped = $RoleTarget[$role]
    if ($mapped -eq 'keep') {
        $desc = 'keep (original: ' + $RoleOrigins[$i] + ')'
    } else {
        $desc = $mapped + ' (custom)'
    }
    if ($RoleSpec) { $RoleSpec += '|' }
    $RoleSpec += $role + '=' + $mapped

    $padded = $role.PadRight(11)
    $line   = $padded + ' -> ' + $desc
    Write-Say ("  " + $line)
    if (-not $Summary) {
        $Summary = ' ' + $line
    } else {
        $Summary += "`n//  " + $line
    }
}

if ($Regs.Count -gt 0) {
    Write-Say ''
    foreach ($reg in $Regs) {
        Write-Say "Font family : $($reg.Name)  [$($reg.FirstRole)]"
        Write-Say "Font file   : $($reg.Path)"
    }
} else {
    Write-Say ''
    Write-Warn 'no role uses a custom font; the mod will keep every original family.'
}

# ---------------------------------------------------------------------------
# copy the fonts (read them first so target files can be the input, too)
# ---------------------------------------------------------------------------
$fontBytes = @{}
foreach ($reg in $Regs) {
    $fontBytes[$reg.Path] = [System.IO.File]::ReadAllBytes($reg.Path)
}

# Remove stale output from earlier runs.
$regex = '^customfont(_[A-Za-z0-9_-]+)?\.(ttf|otf|ttc|otc)$'
foreach ($old in [System.IO.Directory]::GetFiles($ResDir, 'customfont*')) {
    if ([System.IO.Path]::GetFileName($old) -match $regex) {
        Remove-Item -LiteralPath $old -Force -ErrorAction SilentlyContinue
    }
}

foreach ($reg in $Regs) {
    $destPath = Join-Path $ResDir ([System.IO.Path]::GetFileName($reg.Dest))
    [System.IO.File]::WriteAllBytes($destPath, $fontBytes[$reg.Path])
    Write-Ok "installed $destPath ($($reg.Name))"
}

# ---------------------------------------------------------------------------
# regenerate the scheme overrides
# ---------------------------------------------------------------------------
$Python = Find-Python
$Helper = Join-Path $ScriptDir 'dev/hud_scheme.py'
if (-not $Python) {
    Write-Warn 'Python was not found; only one font can be applied without it.'
}

New-SchemeOverride 'clientscheme'
New-SchemeOverride 'chatscheme'

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
        if (Test-Path -LiteralPath (Join-Path (Join-Path $customDir $f) 'resource/clientscheme.res')) {
            $hudPath = Join-Path $customDir $f
            Write-Warn "'$f' is searched before '$targetName' and has a clientscheme.res."
            Write-Warn "The mod will not work. Use -Hud '$hudPath' or rename its scheme."
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
Write-Say '  - Use -ListFonts to see the assignable roles.'
Write-Say '  - If text is still the old font, check that the family name matches exactly'
Write-Say '    and that no HUD/mod with a clientscheme.res sorts before !000_customfont.'
Write-Say '  - -Hud renames the HUD scheme to *_customfont_original.res; use -Restore to undo.'
exit 0
