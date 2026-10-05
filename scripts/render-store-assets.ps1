<#
.SYNOPSIS
    Regenerates every Chrome Web Store image in store/assets from the sources in store/src.

.DESCRIPTION
    - Screenshots and promo tiles are rendered from store/src/*.html with headless Google Chrome.
      The screenshot pages embed store/src/mock-serp.html, which loads the real content.css and
      content.js, so the card in the images is the one the extension actually draws.
    - The store icon is icons/icon128.png scaled to 96x96 and centered on a transparent
      128x128 canvas (16px padding on each side), as the Chrome Web Store recommends.
    - Before rendering, every search query used by the pages (mock-serp.html?q=...) is loaded on
      its own and the card that the real content.js inserts is compared with the expected set of
      carrier buttons ($expectedCards below). The captions in the images are written for exactly
      these results, so a change in content.js / content.css that breaks them fails the run
      instead of silently producing wrong screenshots. Queries may be percent-encoded in the
      HTML (screenshot-2 uses full-width characters); they are decoded the same way the browser
      decodes them for content.js. The query shown in a page's address bar ("search?q=<b>...</b>")
      must be one that the page's iframe really searches for.
    - Afterwards every PNG is checked for its exact pixel size and alpha channel
      (screenshots/tiles: 24-bit, no alpha; icon: 32-bit with alpha). Any mismatch fails the run.

    Chrome runs with a throwaway --user-data-dir under the system temp directory, so your
    normal Chrome profile is never touched. The color scheme is forced to light so the output
    does not depend on the OS theme (the dark card in screenshot-5 is produced per iframe with
    the CSS "color-scheme: dark" property).

    The script resolves all paths from its own location, so it can be run from any directory.
    Works with Windows PowerShell 5.1 and PowerShell 7 on Windows.

.PARAMETER ChromePath
    Full path to chrome.exe. If omitted, the standard install locations and the App Paths
    registry entry are searched.

.PARAMETER Only
    Render only the outputs whose file name matches one of these wildcard patterns.
    Several patterns can be given as an array or as one comma-separated string, so both
    -Only 'screenshot-1*','promo*' and (with powershell -File) -Only 'screenshot-1*,promo*' work.
    A pattern list that matches nothing is an error. Verification still runs for every file.

.PARAMETER TimeoutSeconds
    Maximum time to wait for a single Chrome render. Default: 60.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\render-store-assets.ps1

.EXAMPLE
    .\scripts\render-store-assets.ps1 -ChromePath 'D:\Apps\Chrome\chrome.exe' -Only 'screenshot-*'

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\render-store-assets.ps1 -Only 'screenshot-3*,store-icon*'
#>
[CmdletBinding()]
param(
    [string]$ChromePath,
    [string[]]$Only,
    [ValidateRange(5, 600)]
    [int]$TimeoutSeconds = 60
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# "powershell -File script.ps1 -Only 'a*,b*'" passes one comma-joined string; split it here.
if ($Only) {
    $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$repoRoot   = (Resolve-Path -LiteralPath (Join-Path $scriptDir '..')).Path
$srcDir     = Join-Path $repoRoot 'store\src'
$outDir     = Join-Path $repoRoot 'store\assets'
$iconSource = Join-Path $repoRoot 'icons\icon128.png'

# ---------------------------------------------------------------------------
# What to build (output names are a fixed contract - do not rename)
# ---------------------------------------------------------------------------
$pages = @(
    @{ Source = 'screenshot-1.html';  Output = 'screenshot-1.png';            Width = 1280; Height = 800 },
    @{ Source = 'screenshot-2.html';  Output = 'screenshot-2.png';            Width = 1280; Height = 800 },
    @{ Source = 'screenshot-3.html';  Output = 'screenshot-3.png';            Width = 1280; Height = 800 },
    @{ Source = 'screenshot-4.html';  Output = 'screenshot-4.png';            Width = 1280; Height = 800 },
    @{ Source = 'screenshot-5.html';  Output = 'screenshot-5.png';            Width = 1280; Height = 800 },
    @{ Source = 'promo-small.html';   Output = 'promo-small-440x280.png';     Width = 440;  Height = 280 },
    @{ Source = 'promo-marquee.html'; Output = 'promo-marquee-1400x560.png';  Width = 1400; Height = 560 }
)
$storeIcon = @{ Output = 'store-icon-128.png'; Width = 128; Height = 128; ArtSize = 96 }

# What content.js must draw for each search query used in store/src (keyed by the normalized
# number shown in the card). The captions in the images describe exactly these results:
#   screenshot-1/5, marquee : 1234-5678-9013 -> all three carriers
#   screenshot-2            : the same number typed with full-width digits and full-width
#                             hyphens (U+FF10-U+FF19, U+FF0D; percent-encoded in the HTML)
#                             -> normalized to 123456789013 -> all three carriers
#   screenshot-3            : EM123456789JP  -> Japan Post only
#   screenshot-4            : ...9013 -> all three / ...9012 (check digit fails) -> Japan Post only
# A query whose number is not listed here, or that shows no card, fails the run.
$expectedCards = @{
    '123456789013'  = @('yamato', 'sagawa', 'japanpost')
    '123456789012'  = @('japanpost')
    'EM123456789JP' = @('japanpost')
}

function Test-Selected([string]$Name) {
    if (-not $Only -or $Only.Count -eq 0) { return $true }
    foreach ($pattern in $Only) {
        if ($Name -like $pattern) { return $true }
    }
    return $false
}

# ---------------------------------------------------------------------------
# Chrome
# ---------------------------------------------------------------------------
function Resolve-Chrome([string]$Override) {
    if ($Override) {
        if (Test-Path -LiteralPath $Override -PathType Leaf) {
            return (Resolve-Path -LiteralPath $Override).Path
        }
        throw "chrome.exe was not found at -ChromePath '$Override'."
    }

    $candidates = New-Object System.Collections.Generic.List[string]
    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA)) {
        if ($base) { $candidates.Add((Join-Path $base 'Google\Chrome\Application\chrome.exe')) }
    }
    foreach ($key in @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe',
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe')) {
        try {
            $value = (Get-ItemProperty -LiteralPath $key -ErrorAction Stop).'(default)'
            if ($value) { $candidates.Add($value.Trim('"')) }
        } catch {
            # key does not exist - ignore
        }
    }

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    throw ("Google Chrome was not found. Install it or pass its location, e.g. " +
        "-ChromePath 'C:\Program Files\Google\Chrome\Application\chrome.exe'.")
}

# Runs headless Chrome once and returns its standard output.
function Invoke-Chrome {
    param(
        [string]$Chrome,
        [string]$ProfileDir,
        [string]$Url,
        [string[]]$Extra,
        [int]$Width = 1280,
        [int]$Height = 800
    )

    $argumentList = @(
        '--headless=new',
        '--disable-gpu',
        '--hide-scrollbars',
        '--force-device-scale-factor=1',
        "--window-size=$Width,$Height",
        "--user-data-dir=`"$ProfileDir`"",
        '--no-first-run',
        '--no-default-browser-check',
        '--disable-extensions',
        '--disable-sync',
        '--disable-background-networking',
        '--mute-audio',
        # Grayscale text antialiasing. Without this, Windows renders ClearType (subpixel) text,
        # which leaves colored fringes on every glyph once the image is scaled or viewed elsewhere.
        '--disable-lcd-text',
        # Light mode for the page itself, regardless of the OS theme.
        '--blink-settings=preferredColorScheme=1',
        # Let content.js insert the card (and fonts settle) before the capture.
        '--virtual-time-budget=5000',
        '--run-all-compositor-stages-before-draw'
    )
    if ($Extra) { $argumentList += $Extra }
    $argumentList += "`"$Url`""

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Chrome
    $psi.Arguments = ($argumentList -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    # --dump-dom writes UTF-8; without this the Japanese text would be decoded with the ANSI code page.
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8

    $process = [System.Diagnostics.Process]::Start($psi)
    # Read both streams asynchronously so a full pipe can never block Chrome.
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()

    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        try { $process.Kill() } catch { }
        throw "Chrome did not finish within $TimeoutSeconds s while rendering $Url"
    }
    $process.WaitForExit()

    $stdout = $stdoutTask.Result
    if ($process.ExitCode -ne 0) {
        $log = ($stdout + "`n" + $stderrTask.Result).Trim()
        throw "Chrome exited with code $($process.ExitCode) while rendering $Url`n$log"
    }
    return $stdout
}

function Invoke-ChromeScreenshot {
    param(
        [string]$Chrome,
        [string]$ProfileDir,
        [string]$Url,
        [string]$OutFile,
        [int]$Width,
        [int]$Height
    )

    $null = Invoke-Chrome -Chrome $Chrome -ProfileDir $ProfileDir -Url $Url -Width $Width -Height $Height -Extra @("--screenshot=`"$OutFile`"")
    if (-not (Test-Path -LiteralPath $OutFile -PathType Leaf)) {
        throw "Chrome finished but did not write $OutFile"
    }
}

# ---------------------------------------------------------------------------
# Card sanity check (the real content.js running on store/src/mock-serp.html)
# ---------------------------------------------------------------------------
# Returns the search queries a page passes to mock-serp.html, decoded the way URLSearchParams
# decodes them for content.js ('+' is a space, %XX are UTF-8 bytes), e.g. screenshot-2's
# '%EF%BC%91...' becomes the full-width text it stands for.
function Get-PageQueries([string]$Html) {
    $found = [regex]::Matches($Html, 'mock-serp\.html\?q=([^"&#]+)')
    return @($found | ForEach-Object { [System.Uri]::UnescapeDataString(($_.Groups[1].Value -replace '\+', ' ')) })
}

# Returns the queries a page shows in its fake address bar ("search?q=<b>...</b>").
function Get-AddressQueries([string]$Html) {
    $found = [regex]::Matches($Html, 'search\?q=<b>([^<]*)</b>')
    return @($found | ForEach-Object { [System.Net.WebUtility]::HtmlDecode($_.Groups[1].Value) })
}

# Console-safe text for a query in the log: full-width ASCII (U+FF01-U+FF5E, U+3000) is shown as
# the ASCII it stands for plus "(full-width)", any other non-ASCII character as \uXXXX, so the
# output reads the same in every console code page and when it is redirected to a file.
function Format-Query([string]$Query) {
    $text = New-Object System.Text.StringBuilder
    $fullWidth = $false
    foreach ($ch in $Query.ToCharArray()) {
        $code = [int]$ch
        if ($code -lt 0x80) {
            [void]$text.Append($ch)
        } elseif ($code -ge 0xFF01 -and $code -le 0xFF5E) {
            [void]$text.Append([char]($code - 0xFEE0))
            $fullWidth = $true
        } elseif ($code -eq 0x3000) {
            [void]$text.Append(' ')
            $fullWidth = $true
        } else {
            [void]$text.Append(('\u{0:X4}' -f $code))
        }
    }
    if ($fullWidth) { return ('{0} (full-width)' -f $text.ToString()) }
    return $text.ToString()
}

# Returns '' when the card matches $expectedCards, otherwise a description of the problem.
function Test-Card {
    param([string]$Chrome, [string]$ProfileDir, [string]$Query)

    $label = Format-Query $Query
    $mockUri = ([System.Uri](Join-Path $srcDir 'mock-serp.html')).AbsoluteUri
    $url = $mockUri + '?q=' + [System.Uri]::EscapeDataString($Query)
    $dom = Invoke-Chrome -Chrome $Chrome -ProfileDir $ProfileDir -Url $url -Extra @('--dump-dom')

    if ($dom -notmatch 'id="nimotsu-hiro"') {
        return "content.js inserted no card (#nimotsu-hiro) for q=$label"
    }
    $carriers = @()
    $numbers = @()
    foreach ($link in [regex]::Matches($dom, '<a\b[^>]*\bnimotsu-hiro-link--[a-z]+[^>]*>')) {
        $tag = $link.Value
        $carriers += [regex]::Match($tag, 'nimotsu-hiro-link--([a-z]+)').Groups[1].Value
        $numbers += [regex]::Match($tag, 'href="[^"]*=([A-Za-z0-9]+)"').Groups[1].Value
    }
    $numbers = @($numbers | Select-Object -Unique)
    if ($numbers.Count -ne 1 -or -not $numbers[0]) {
        return "could not read the tracking number from the card for q=$label"
    }
    $number = $numbers[0]
    if (-not $expectedCards.ContainsKey($number)) {
        return "q=$label is shown as $number, which has no entry in `$expectedCards (add one that matches the image captions)"
    }
    $expected = ($expectedCards[$number] -join ',')
    $actual = ($carriers -join ',')
    if ($actual -ne $expected) {
        return "q=$label ($number) shows [$actual] but the images expect [$expected]"
    }
    Write-Host ("Card   : {0,-28} [{1}]  q={2}" -f $number, $actual, $label)
    return ''
}

# ---------------------------------------------------------------------------
# Store icon (System.Drawing, high-quality bicubic, keeps alpha)
# ---------------------------------------------------------------------------
function New-StoreIcon([string]$Source, [string]$OutFile, [int]$CanvasSize, [int]$ArtSize) {
    $offset = [int](($CanvasSize - $ArtSize) / 2)
    $image = $null; $bitmap = $null; $graphics = $null; $attributes = $null
    try {
        $image = [System.Drawing.Image]::FromFile($Source)
        $bitmap = New-Object System.Drawing.Bitmap -ArgumentList $CanvasSize, $CanvasSize, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.CompositingMode    = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

        # icons/icon128.png has see-through "holes": the speed lines (alpha ~208) and the cheeks
        # (alpha ~170) let the page background show through, so on a dark page they turn grey.
        # A white rounded square slightly smaller than the tile is laid underneath, which makes the
        # icon look the same on light and dark pages (exactly as it looks on white). The underlay
        # is inset so it stays hidden behind the opaque tile and never touches the anti-aliased
        # outer edge; the 16px padding stays fully transparent.
        $scale  = $ArtSize / 128.0
        $inset  = 4.0 * $scale
        $radius = 30.0 * $scale
        $x = [single]($offset + $inset)
        $y = [single]($offset + $inset)
        $side = [single]($ArtSize - 2 * $inset)
        $diameter = [single](2 * $radius)
        $underlay = New-Object System.Drawing.Drawing2D.GraphicsPath
        try {
            $underlay.AddArc($x, $y, $diameter, $diameter, [single]180, [single]90)
            $underlay.AddArc([single]($x + $side - $diameter), $y, $diameter, $diameter, [single]270, [single]90)
            $underlay.AddArc([single]($x + $side - $diameter), [single]($y + $side - $diameter), $diameter, $diameter, [single]0, [single]90)
            $underlay.AddArc($x, [single]($y + $side - $diameter), $diameter, $diameter, [single]90, [single]90)
            $underlay.CloseFigure()
            $graphics.FillPath([System.Drawing.Brushes]::White, $underlay)
        } finally {
            $underlay.Dispose()
        }

        # TileFlipXY avoids the semi-transparent seam GDI+ otherwise adds along the edges.
        $attributes = New-Object System.Drawing.Imaging.ImageAttributes
        $attributes.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)

        $dest = New-Object System.Drawing.Rectangle -ArgumentList $offset, $offset, $ArtSize, $ArtSize
        $graphics.DrawImage($image, $dest, 0, 0, $image.Width, $image.Height, [System.Drawing.GraphicsUnit]::Pixel, $attributes)
        $bitmap.Save($OutFile, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        if ($attributes) { $attributes.Dispose() }
        if ($graphics) { $graphics.Dispose() }
        if ($bitmap) { $bitmap.Dispose() }
        if ($image) { $image.Dispose() }
    }
}

# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------
function Test-Png([string]$Path, [int]$Width, [int]$Height, [bool]$ExpectAlpha) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return "missing"
    }
    $image = $null
    try {
        $image = [System.Drawing.Image]::FromFile($Path)
        $problems = @()
        if ($image.RawFormat.Guid -ne [System.Drawing.Imaging.ImageFormat]::Png.Guid) {
            $problems += 'not a PNG'
        }
        if ($image.Width -ne $Width -or $image.Height -ne $Height) {
            $problems += ("size is {0}x{1}, expected {2}x{3}" -f $image.Width, $image.Height, $Width, $Height)
        }
        $hasAlpha = [System.Drawing.Image]::IsAlphaPixelFormat($image.PixelFormat)
        if ($ExpectAlpha -and -not $hasAlpha) {
            $problems += "has no alpha channel ($($image.PixelFormat))"
        }
        if (-not $ExpectAlpha -and $hasAlpha) {
            $problems += "has an alpha channel ($($image.PixelFormat)); the store wants 24-bit PNG without alpha"
        }
        return ($problems -join '; ')
    } finally {
        if ($image) { $image.Dispose() }
    }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
Add-Type -AssemblyName System.Drawing

foreach ($required in @($srcDir, $iconSource, (Join-Path $repoRoot 'content.js'), (Join-Path $repoRoot 'content.css'))) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Required file or folder is missing: $required" }
}
if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

$selectedPages = @($pages | Where-Object { Test-Selected $_.Output })
$iconSelected = Test-Selected $storeIcon.Output
if ($selectedPages.Count -eq 0 -and -not $iconSelected) {
    $names = @($pages | ForEach-Object { $_.Output }) + $storeIcon.Output
    throw ("-Only '{0}' matched no output. Output names: {1}" -f ($Only -join ','), ($names -join ', '))
}
$profileDir = $null

if ($selectedPages.Count -gt 0) {
    $chrome = Resolve-Chrome $ChromePath
    Write-Host "Chrome : $chrome"
    $profileDir = Join-Path ([System.IO.Path]::GetTempPath()) ('nimotsu-hiro-render-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $profileDir | Out-Null
}

try {
    # Check the card for every query the selected pages use before spending time on renders.
    $queries = @()
    $cardProblems = @()
    foreach ($page in $selectedPages) {
        $sourcePath = Join-Path $srcDir $page.Source
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "Source page is missing: $sourcePath" }
        $html = [System.IO.File]::ReadAllText($sourcePath, [System.Text.Encoding]::UTF8)
        $pageQueries = Get-PageQueries $html
        # The number in the address bar and the card under it must come from the same query.
        foreach ($shown in Get-AddressQueries $html) {
            if ($pageQueries -cnotcontains $shown) {
                $problem = "store/src/$($page.Source) shows q=$(Format-Query $shown) in the address bar, but no mock-serp.html iframe on the page searches for it"
                $cardProblems += $problem
                Write-Host ("FAIL   : {0}" -f $problem) -ForegroundColor Red
            }
        }
        $queries += $pageQueries
    }
    # Select-Object -Unique compares strings case-sensitively, so only exact duplicates are merged.
    foreach ($query in @($queries | Select-Object -Unique)) {
        $problem = Test-Card -Chrome $chrome -ProfileDir $profileDir -Query $query
        if ($problem) {
            $cardProblems += $problem
            Write-Host ("FAIL   : {0}" -f $problem) -ForegroundColor Red
        }
    }
    if ($cardProblems.Count -gt 0) {
        throw ("The card drawn by content.js no longer matches the store images:`n  " + ($cardProblems -join "`n  "))
    }

    foreach ($page in $selectedPages) {
        $sourcePath = Join-Path $srcDir $page.Source
        $outPath = Join-Path $outDir $page.Output
        # Remove the old file first so a failed render can never pass verification with stale output.
        if (Test-Path -LiteralPath $outPath) { Remove-Item -LiteralPath $outPath -Force }

        $url = ([System.Uri]$sourcePath).AbsoluteUri
        Write-Host ("Render : {0,-28} <- store/src/{1}" -f $page.Output, $page.Source)
        Invoke-ChromeScreenshot -Chrome $chrome -ProfileDir $profileDir -Url $url -OutFile $outPath -Width $page.Width -Height $page.Height
    }

    if ($iconSelected) {
        $iconOut = Join-Path $outDir $storeIcon.Output
        if (Test-Path -LiteralPath $iconOut) { Remove-Item -LiteralPath $iconOut -Force }
        Write-Host ("Render : {0,-28} <- icons/icon128.png ({1}px art, {2}px padding)" -f $storeIcon.Output, $storeIcon.ArtSize, (($storeIcon.Width - $storeIcon.ArtSize) / 2))
        New-StoreIcon -Source $iconSource -OutFile $iconOut -CanvasSize $storeIcon.Width -ArtSize $storeIcon.ArtSize
    }
} finally {
    if ($profileDir -and (Test-Path -LiteralPath $profileDir)) {
        # Chrome helper processes can hold files for a moment after exit; retry briefly.
        for ($attempt = 0; $attempt -lt 10; $attempt++) {
            try {
                Remove-Item -LiteralPath $profileDir -Recurse -Force -ErrorAction Stop
                break
            } catch {
                Start-Sleep -Milliseconds 300
            }
        }
    }
}

# Verify every asset (not only the ones rendered in this run).
$failures = @()
$checks = @()
foreach ($page in $pages) { $checks += @{ Output = $page.Output; Width = $page.Width; Height = $page.Height; Alpha = $false } }
$checks += @{ Output = $storeIcon.Output; Width = $storeIcon.Width; Height = $storeIcon.Height; Alpha = $true }

foreach ($check in $checks) {
    $path = Join-Path $outDir $check.Output
    $problem = Test-Png -Path $path -Width $check.Width -Height $check.Height -ExpectAlpha $check.Alpha
    $kind = 'RGB'
    if ($check.Alpha) { $kind = 'RGBA' }
    if ($problem) {
        $failures += "$($check.Output): $problem"
        Write-Host ("FAIL   : {0,-28} {1}" -f $check.Output, $problem) -ForegroundColor Red
    } else {
        Write-Host ("OK     : {0,-28} {1}x{2} {3}" -f $check.Output, $check.Width, $check.Height, $kind) -ForegroundColor Green
    }
}

if ($failures.Count -gt 0) {
    throw ("Store asset verification failed:`n  " + ($failures -join "`n  "))
}
Write-Host "All store assets are in $outDir"
