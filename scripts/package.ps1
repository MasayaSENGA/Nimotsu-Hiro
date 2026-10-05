<#
.SYNOPSIS
    Validates manifest.json and builds the Chrome Web Store upload zip.

.DESCRIPTION
    1. Checks manifest.json against the Chrome Web Store upload rules.
    2. Builds dist/nimotsu-hiro-<version>.zip from manifest.json, the files it
       references (icons, content_scripts) and LICENSE, with forward-slash
       entry names and manifest.json at the root.
    3. Reopens the zip, compares it with the source files and prints the
       entries, size, SHA-256 and path.
    Problems are printed as "ERROR: ..." on stderr (exit code 1). Works on
    Windows PowerShell 5.1 and PowerShell 7 from any working directory.
    Keep this file pure ASCII (PS 5.1 reads BOM-less scripts as ANSI).

.PARAMETER OutDir
    Directory for the zip. Defaults to <repo>\dist. A relative path is
    resolved against the current location.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\package.ps1 [-OutDir C:\temp\release]
#>
[CmdletBinding()]
param([string]$OutDir)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Stop-WithErrors([string[]]$Messages) {
    foreach ($m in $Messages) { [Console]::Error.WriteLine("ERROR: $m") }
    exit 1
}

# Unexpected failures also end with an ERROR: line and exit code 1.
trap { Stop-WithErrors "$($_.Exception.Message) (package.ps1 line $($_.InvocationInfo.ScriptLineNumber))" }

# Manifest keys that can reference files this script does not collect.
# Before using one of them, teach the script to package those files.
$UnsupportedKeys = @('background', 'action', 'options_page', 'options_ui', 'web_accessible_resources',
    'default_locale', 'side_panel', 'devtools_page', 'chrome_url_overrides', 'sandbox', 'declarative_net_request')

$RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ($OutDir) {
    $OutDirFull = [IO.Path]::GetFullPath($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutDir))
} else {
    $OutDirFull = Join-Path $RepoRoot 'dist'
}

$errors = New-Object System.Collections.Generic.List[string]
$files  = New-Object System.Collections.Generic.List[string]  # zip entry names, in order

# Case-sensitive JSON property lookup. Outputs nothing for a missing key
# (a plain $obj.key throws under StrictMode), so @(Get-Prop ...) is empty.
function Get-Prop($Object, [string]$Name) {
    if ($Object -is [Management.Automation.PSCustomObject]) {
        foreach ($p in $Object.PSObject.Properties) { if ($p.Name -ceq $Name) { return $p.Value } }
    }
}

# Checks a path referenced from manifest.json and queues it for the zip.
function Add-PackageFile($Rel, [string]$What) {
    if (-not ($Rel -is [string]) -or $Rel -notmatch '^[\w.-]+(/[\w.-]+)*\z' -or $Rel -match '(^|/)\.\.?(/|\z)') {
        $errors.Add("$What '$Rel' must be a relative path with forward slashes, e.g. icons/icon16.png.")
        return $false
    }
    if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $Rel) -PathType Leaf)) {
        $errors.Add("$What '$Rel' does not exist.")
        return $false
    }
    if ($files -notcontains $Rel) { $files.Add($Rel) }
    return $true
}

# Width and height from the PNG IHDR header, or nothing if not a PNG.
function Get-PngSize([string]$Path) {
    $b = New-Object byte[] 24
    $s = [IO.File]::OpenRead($Path)
    try { $n = $s.Read($b, 0, 24) } finally { $s.Dispose() }
    if ($n -lt 24 -or [Text.Encoding]::ASCII.GetString($b, 12, 4) -cne 'IHDR') { return }
    $signature = @(137, 80, 78, 71, 13, 10, 26, 10)
    for ($i = 0; $i -lt 8; $i++) { if ($b[$i] -ne $signature[$i]) { return } }
    foreach ($o in 16, 20) { ([int64]$b[$o] * 16777216) + ($b[$o + 1] * 65536) + ($b[$o + 2] * 256) + $b[$o + 3] }
}

# Strict JSON syntax check with the JSON parser built into Windows
# (Windows.Data.Json). Returns $true or $false, or nothing when that parser
# is not available (e.g. PowerShell 7, where ConvertFrom-Json is the only check).
function Test-StrictJson([string]$Text) {
    $type = 'Windows.Data.Json.JsonValue, Windows.Data.Json, ContentType=WindowsRuntime' -as [type]
    if (-not $type) { return }
    $parsed = $null
    try { if (-not $type::TryParse('{}', [ref]$parsed)) { return } } catch { return }
    try { return [bool]$type::TryParse($Text, [ref]$parsed) } catch { return $false }  # TryParse can throw, e.g. on 1e400
}

$manifestPath = Join-Path $RepoRoot 'manifest.json'
Write-Host "== Validating $manifestPath" -ForegroundColor Cyan
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { Stop-WithErrors "manifest.json not found in $RepoRoot" }
$manifestText = [IO.File]::ReadAllText($manifestPath, (New-Object Text.UTF8Encoding $false))
try {
    $manifest = $manifestText | ConvertFrom-Json
} catch {
    # PowerShell 5.1 appends "(<offset>): <whole file>"; report a line number instead.
    $msg = ($_.Exception.Message -split "`r?`n")[0]
    if ($msg -match '^(.*?)\s*\((\d+)\):') {
        $line = $manifestText.Substring(0, [Math]::Min([int]$Matches[2], $manifestText.Length)).Split("`n").Count
        $msg = "$($Matches[1]) (near line $line)"
    }
    Stop-WithErrors "manifest.json is not valid JSON: $msg"
}
# Windows PowerShell's ConvertFrom-Json also accepts single-quoted strings,
# unquoted keys, line breaks inside strings and numbers with leading zeros,
# which Chrome rejects.
if ((Test-StrictJson $manifestText) -eq $false) {
    Stop-WithErrors 'manifest.json is not valid JSON: put every key and string in double quotes, keep each string on one line and write numbers without leading zeros.'
}
if (-not ($manifest -is [Management.Automation.PSCustomObject])) { Stop-WithErrors 'manifest.json must contain a JSON object.' }
$files.Add('manifest.json')

$mv = Get-Prop $manifest 'manifest_version'
if (($mv -is [int] -or $mv -is [long]) -and $mv -eq 3) { Write-Host '  manifest_version : OK (3)' }
else { $errors.Add("manifest_version must be the number 3 (found: '$mv').") }

# Length counts UTF-16 code units: equal to the character count for Japanese
# text, stricter than the store for emoji.
foreach ($field in @(@('name', 75), @('description', 132))) {
    $key = $field[0]; $max = $field[1]
    $value = Get-Prop $manifest $key
    if (-not ($value -is [string]) -or $value.Trim().Length -eq 0) { $errors.Add("$key is missing or empty.") }
    elseif ($value.Length -gt $max) { $errors.Add("$key is $($value.Length) characters; the limit is $max.") }
    else { Write-Host ('  {0,-16} : OK ({1}/{2} chars)' -f $key, $value.Length, $max) }
}

# 1-4 dot-separated integers 0-65535, no leading zeros, not all zero.
$version = Get-Prop $manifest 'version'
$versionOk = ($version -is [string]) -and ($version -cmatch '^(0|[1-9][0-9]{0,4})(\.(0|[1-9][0-9]{0,4})){0,3}\z')
if ($versionOk) {
    $parts = @($version.Split('.') | ForEach-Object { [int]$_ })
    $versionOk = (@($parts | Where-Object { $_ -gt 65535 }).Count -eq 0) -and (@($parts | Where-Object { $_ -ne 0 }).Count -gt 0)
}
if ($versionOk) { Write-Host "  version          : OK ($version)" }
elseif (-not ($version -is [string])) { $errors.Add('version must be a string, e.g. "2.0".') }
else { $errors.Add("version '$version' is invalid: use 1-4 dot-separated integers 0-65535 without leading zeros, not all zero (e.g. 2.0.1).") }

$keys = @($manifest.PSObject.Properties | ForEach-Object { $_.Name })
foreach ($key in $UnsupportedKeys) {
    if ($keys -ccontains $key) { $errors.Add("manifest key '$key' can reference files that package.ps1 does not collect. Extend the script first.") }
}

$i = 0
foreach ($cs in @(Get-Prop $manifest 'content_scripts')) {
    if (-not ($cs -is [Management.Automation.PSCustomObject])) { $errors.Add("content_scripts[$i] must be an object.") }
    foreach ($kind in 'js', 'css') {
        foreach ($rel in @(Get-Prop $cs $kind)) {
            if (Add-PackageFile $rel "content_scripts[$i].$kind") { Write-Host ('  {0,-16} : OK ({1})' -f $kind, $rel) }
        }
    }
    $i++
}

$icons = Get-Prop $manifest 'icons'
if (-not ($icons -is [Management.Automation.PSCustomObject])) {
    $errors.Add('icons is missing. The Chrome Web Store requires a 128x128 PNG icon.')
} else {
    foreach ($icon in $icons.PSObject.Properties) {
        $what = "icons[`"$($icon.Name)`"]"
        if ($icon.Name -cnotmatch '^[1-9][0-9]{0,3}\z') { $errors.Add("$what key must be the icon size in pixels."); continue }
        if (-not (Add-PackageFile $icon.Value $what)) { continue }
        $size = @(Get-PngSize (Join-Path $RepoRoot $icon.Value))
        $px = [int]$icon.Name
        if ($size.Count -ne 2) { $errors.Add("$what '$($icon.Value)' is not a PNG file.") }
        elseif ($size[0] -ne $px -or $size[1] -ne $px) { $errors.Add("$what '$($icon.Value)' is $($size[0])x$($size[1]) px; expected ${px}x${px}.") }
        else { Write-Host ('  {0,-16} : OK ({1}, {2}x{2} PNG)' -f "icon $px", $icon.Value, $px) }
    }
    if (@($icons.PSObject.Properties | Where-Object { $_.Name -ceq '128' }).Count -eq 0) {
        $errors.Add('icons has no "128" entry. The Chrome Web Store requires a 128x128 PNG icon.')
    }
}

if (Add-PackageFile 'LICENSE' 'Extra file') { Write-Host '  LICENSE          : OK' }

if ($errors.Count -gt 0) { Stop-WithErrors $errors.ToArray() }

# Non-fatal: the uploaded zip should match a commit.
if (Get-Command git -ErrorAction SilentlyContinue) {
    $ErrorActionPreference = 'Continue'  # PS 5.1 turns git's stderr into errors
    $dirty = @()
    if ((& git -C $RepoRoot rev-parse --is-inside-work-tree 2>$null) -eq 'true') {
        $dirty = @(& git -C $RepoRoot status --porcelain -- $files.ToArray() 2>$null)
    }
    $ErrorActionPreference = 'Stop'
    if ($dirty.Count -gt 0) {
        Write-Warning 'These packaged files have uncommitted changes. Commit them so the upload matches a commit:'
        foreach ($line in $dirty) { Write-Host "    $line" -ForegroundColor Yellow }
    }
}

Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$zipPath = Join-Path $OutDirFull "nimotsu-hiro-$version.zip"
$tmpPath = "$zipPath.tmp"
Write-Host "== Building and verifying nimotsu-hiro-$version.zip" -ForegroundColor Cyan

try {
    [void][IO.Directory]::CreateDirectory($OutDirFull)
    if (Test-Path -LiteralPath $tmpPath) { Remove-Item -LiteralPath $tmpPath -Force }

    # ZipArchive with explicit entry names instead of Compress-Archive, which
    # in PowerShell 5.1 can write backslashes into entry names.
    $zip = [IO.Compression.ZipFile]::Open($tmpPath, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($rel in $files) {
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $RepoRoot $rel), $rel, [IO.Compression.CompressionLevel]::Optimal)
        }
    } finally { $zip.Dispose() }

    $zip = [IO.Compression.ZipFile]::OpenRead($tmpPath)
    try {
        $expected = (@($files | Sort-Object -CaseSensitive) -join ', ')
        $actual   = (@($zip.Entries | ForEach-Object { $_.FullName } | Sort-Object -CaseSensitive) -join ', ')
        if ($actual -cne $expected) { throw "zip entries [$actual] do not match the expected [$expected]." }
        foreach ($entry in $zip.Entries) {
            $buffer = New-Object IO.MemoryStream
            $s = $entry.Open()
            try { $s.CopyTo($buffer) } finally { $s.Dispose() }
            $source = [IO.File]::ReadAllBytes((Join-Path $RepoRoot $entry.FullName))
            if (-not [Linq.Enumerable]::SequenceEqual($buffer.ToArray(), $source)) { throw "zip entry '$($entry.FullName)' differs from the source file." }
            Write-Host ('  {0,-20} {1,8:N0} bytes' -f $entry.FullName, $entry.Length)
        }
    } finally { $zip.Dispose() }

    # Delete the old zip first: if another program has it open, Remove-Item
    # reports that (PS 5.1's Move-Item -Force only says the file exists).
    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
    Move-Item -LiteralPath $tmpPath -Destination $zipPath
} catch {
    $msg = $_.Exception.Message
    # ERROR_SHARING_VIOLATION (32) / ERROR_LOCK_VIOLATION (33)
    if (@(32, 33) -contains ($_.Exception.HResult -band 0xFFFF)) {
        $msg += ' Close the program that has the file open (an archiver, an upload dialog, antivirus) and run the script again.'
    }
    if (Test-Path -LiteralPath $tmpPath) { Remove-Item -LiteralPath $tmpPath -Force -ErrorAction SilentlyContinue }
    Stop-WithErrors "Could not build the zip: $msg"
}

Write-Host "Package : $zipPath" -ForegroundColor Green
Write-Host "Entries : $($files.Count)"
Write-Host ('Size    : {0:N0} bytes' -f (Get-Item -LiteralPath $zipPath).Length)
Write-Host "SHA-256 : $((Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant())"
Write-Host 'Upload this zip in the Chrome Web Store Developer Dashboard (first upload: New item; updates: Package > Upload new package).'
exit 0
