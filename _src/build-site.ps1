$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Drawing

$root = 'D:\Simcha\The Pioneer Design Website'
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
$utf8 = New-Object System.Text.UTF8Encoding($false)

$assetsDir = Join-Path $root 'assets'
foreach ($d in @('assets\img', 'assets\css', 'assets\fonts', 'assets\js', '_src\tmp')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $root $d) | Out-Null
}

$script:urlMap = @{}
$script:failed = New-Object System.Collections.ArrayList

function Resolve-Url([string]$url) {
    $u = $url.Trim()
    $u = $u -replace '&amp;', '&' -replace '&#0?38;', '&' -replace '&#0?39;', "'" -replace '&apos;', "'"
    if ($u.StartsWith('//')) { return 'https:' + $u }
    if ($u.StartsWith('/')) { return 'https://thepioneerdesign.com' + $u }
    return $u
}

function Get-Ext([string]$url, [string]$fallback) {
    $pathPart = ($url -split '[?#]')[0]
    $ext = [IO.Path]::GetExtension($pathPart)
    if ($ext -match '^\.(jpg|jpeg|png|webp|gif|svg|woff2|woff|ttf|otf|css|ico)$') { return $ext.ToLower() }
    return $fallback
}

function Get-Hash([string]$url) {
    $sha = [Security.Cryptography.SHA1]::Create()
    return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($url))) -replace '-', '').ToLower()
}

function Invoke-Download([string]$url, [string]$outFile) {
    for ($try = 1; $try -le 3; $try++) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $outFile -UserAgent $ua -UseBasicParsing -TimeoutSec 90
            return $true
        } catch {
            if ($try -eq 3) {
                [void]$script:failed.Add("$url  ::  $($_.Exception.Message)")
                return $false
            }
            Start-Sleep -Milliseconds 600
        }
    }
}

function Test-Alpha([System.Drawing.Image]$img) {
    $tw = 64
    $th = [Math]::Max(1, [int]($img.Height * ($tw / $img.Width)))
    $bmp = New-Object System.Drawing.Bitmap($tw, $th, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.DrawImage($img, 0, 0, $tw, $th)
    $g.Dispose()
    $found = $false
    for ($y = 0; $y -lt $th -and -not $found; $y++) {
        for ($x = 0; $x -lt $tw; $x++) {
            if ($bmp.GetPixel($x, $y).A -lt 250) { $found = $true; break }
        }
    }
    $bmp.Dispose()
    return $found
}

function Save-Jpeg([System.Drawing.Image]$img, [string]$outFile, [int]$quality = 86) {
    $bmp = New-Object System.Drawing.Bitmap($img.Width, $img.Height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($img, 0, 0, $img.Width, $img.Height)
    $g.Dispose()
    $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
    $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]$quality)
    $bmp.Save($outFile, $codec, $ep)
    $ep.Dispose()
    $bmp.Dispose()
}

function Convert-ImageAsset {
    param([string]$srcFile, [string]$hashBase, [int]$maxWidth = 1500)
    $img = [System.Drawing.Image]::FromFile($srcFile)
    try {
        $ratio = [Math]::Min(1.0, $maxWidth / $img.Width)
        $w = [Math]::Max(1, [int][Math]::Round($img.Width * $ratio))
        $h = [Math]::Max(1, [int][Math]::Round($img.Height * $ratio))

        $resized = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($resized)
        $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.DrawImage($img, 0, 0, $w, $h)
        $g.Dispose()

        $transparent = Test-Alpha $resized
        if ($transparent) {
            $rel = "assets/img/$hashBase.png"
            $resized.Save((Join-Path $root ($rel -replace '/', '\')), [System.Drawing.Imaging.ImageFormat]::Png)
        } else {
            $rel = "assets/img/$hashBase.jpg"
            Save-Jpeg $resized (Join-Path $root ($rel -replace '/', '\')) 86
        }
        $resized.Dispose()
        return $rel
    } finally {
        $img.Dispose()
    }
}

# =====================================================================
$html = [IO.File]::ReadAllText((Join-Path $root '_src\original.html'))

# ---------------------------------------------------------------- 1. stylesheets
$cssUrls = [regex]::Matches($html, "<link\b[^>]*rel='stylesheet'[^>]*>") |
    ForEach-Object { [regex]::Match($_.Value, "href='([^']+)'") } |
    Where-Object { $_.Success } |
    ForEach-Object { Resolve-Url $_.Groups[1].Value } |
    Sort-Object -Unique

$cssLocal = @{}
foreach ($u in $cssUrls) {
    $hash = Get-Hash $u
    $rel = "assets/css/$hash.css"
    $full = Join-Path $root ($rel -replace '/', '\')
    if (-not (Test-Path $full)) { [void](Invoke-Download $u $full) }
    if (Test-Path $full) {
        $text = [IO.File]::ReadAllText($full)
        $refs = [regex]::Matches($text, "url\((['""]?)([^)'""]+)\1\)")
        foreach ($r in $refs) {
            $ref = $r.Groups[2].Value.Trim()
            if ($ref.StartsWith('data:') -or $ref.StartsWith('#')) { continue }
            $abs = $null
            try { $abs = ([Uri]::new([Uri]$u, $ref)).AbsoluteUri } catch { continue }
            $hash2 = Get-Hash $abs
            $ext = Get-Ext $abs '.png'
            $kind = if ($ext -match '^\.(woff2?|ttf|otf)$') { 'fonts' } else { 'img' }
            $rel2 = "assets/$kind/$hash2$ext"
            $full2 = Join-Path $root ($rel2 -replace '/', '\')
            if (-not (Test-Path $full2)) { [void](Invoke-Download $abs $full2) }
            $text = $text.Replace($r.Value, "url(../$kind/$hash2$ext)")
        }
        [IO.File]::WriteAllText($full, $text, $utf8)
        $cssLocal[$u] = $rel
        Write-Host "CSS  $rel"
    }
}

# ---------------------------------------------------------------- 2. fonts (embed as data URIs)
$fontBlocks = [regex]::Matches($html, '@font-face\{[^}]*\}') | ForEach-Object { $_.Value }
$html = [regex]::Replace($html, '@font-face\{[^}]*\}', '')

$keepFamilies = @{
    'Bricolage Grotesque' = @('200', '300', '400', '700');
    'Overpass'            = @('100', '300', '400', '700');
    'Roboto'              = @('300', '400', '500', '700');
    'Inter'               = @('100', '400');
    'Montserrat'          = @('100', '400', '600', '700');
    'Rubik'               = @('400', '500', '700');
}

$fontCss = New-Object System.Text.StringBuilder
$fontCount = 0
foreach ($block in $fontBlocks) {
    $fam = [regex]::Match($block, 'font-family:([^;]+);').Groups[1].Value.Trim()
    $wgt = [regex]::Match($block, 'font-weight:([^;]+);').Groups[1].Value.Trim()
    if (-not $keepFamilies.ContainsKey($fam)) { continue }
    if ($keepFamilies[$fam] -notcontains $wgt) { continue }
    $srcMatch = [regex]::Match($block, "src:url\('([^']+)'\)\s*format\('([^']+)'\)")
    if (-not $srcMatch.Success) { continue }
    $url = Resolve-Url $srcMatch.Groups[1].Value
    $fmt = $srcMatch.Groups[2].Value
    $ext = Get-Ext $url '.woff2'
    $tmp = Join-Path $root "_src\tmp\font_$(Get-Hash $url)$ext"
    if (-not (Test-Path $tmp)) {
        if (-not (Invoke-Download $url $tmp)) { continue }
    }
    $mime = switch ($ext) { '.woff2' { 'font/woff2' } '.woff' { 'font/woff' } '.ttf' { 'font/ttf' } default { 'application/octet-stream' } }
    $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($tmp))
    [void]$fontCss.AppendLine("@font-face{font-family:$fam;font-style:normal;font-weight:$wgt;font-display:swap;src:url(data:$mime;base64,$b64) format('$fmt');}")
    $fontCount++
}
[IO.File]::WriteAllText((Join-Path $root 'assets\css\fonts.css'), $fontCss.ToString(), $utf8)
Write-Host "Fonts embedded: $fontCount"

# ---------------------------------------------------------------- 3. background images
$bgUrls = [regex]::Matches($html, "url\(&apos;(https?://[^&]+(?:&(?!apos;)[^&]*)*)&apos;\)") |
    ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique

$bgLocal = @{}
foreach ($u in $bgUrls) {
    $abs = Resolve-Url $u
    $hash = Get-Hash $abs
    $tmp = Join-Path $root "_src\tmp\bg_$hash.jpg"
    if (-not (Test-Path $tmp)) { if (-not (Invoke-Download $abs $tmp)) { continue } }
    $rel = Convert-ImageAsset $tmp $hash 2400
    $bgLocal[$u] = $rel
    Write-Host "BG   $rel"
}

# ---------------------------------------------------------------- 4. images
$imgTags = [regex]::Matches($html, '<img\b[^>]*>') | ForEach-Object { $_.Value } | Sort-Object -Unique
$imgMap = @{}       # raw tag -> new tag
$imgCount = 0
foreach ($tag in $imgTags) {
    $m = [regex]::Match($tag, 'src="([^"]*)"')
    if (-not $m.Success) { continue }
    $raw = $m.Groups[1].Value
    if ($raw.StartsWith('data:')) { continue }
    $abs = Resolve-Url $raw

    if ($abs -match '^https://(pixel|stats)\.wp\.com/' -or $abs -match 'gravatar\.com') {
        $imgMap[$tag] = ''       # drop trackers
        continue
    }
    if ($abs -match '^https://thepioneerdesign\.com/wp-content/uploads/' -and $abs -match '\.(jpe?g|png|webp)$') {
        $abs = ($abs -split '\?')[0] + '?w=1500'
    }
    $hash = Get-Hash $abs
    $ext = Get-Ext $abs '.jpg'
    $tmp = Join-Path $root "_src\tmp\img_$hash$ext"
    if (-not (Test-Path $tmp)) { if (-not (Invoke-Download $abs $tmp)) { continue } }

    if ($ext -in @('.webp', '.gif', '.svg')) {
        $rel = "assets/img/$hash$ext"
        Copy-Item $tmp (Join-Path $root ($rel -replace '/', '\')) -Force
    } else {
        $rel = Convert-ImageAsset $tmp $hash 1500
    }

    $newTag = $tag
    $newTag = [regex]::Replace($newTag, 'src="[^"]*"', "src=`"$rel`"")
    $newTag = [regex]::Replace($newTag, '\s+srcset="[^"]*"', '')
    $newTag = [regex]::Replace($newTag, '\s+sizes="[^"]*"', '')
    $newTag = [regex]::Replace($newTag, '\s+data-orig-file="[^"]*"', '')
    $newTag = [regex]::Replace($newTag, '\s+data-large-file="[^"]*"', '')
    $imgMap[$tag] = $newTag
    $imgCount++
}
foreach ($k in $imgMap.Keys) { $html = $html.Replace($k, $imgMap[$k]) }
Write-Host "Images processed: $imgCount"

# ---------------------------------------------------------------- 5. icons / head links
$linkTags = [regex]::Matches($html, '<link\b[^>]*>') | ForEach-Object { $_.Value } | Sort-Object -Unique
foreach ($tag in $linkTags) {
    if ($tag -match 'rel=''stylesheet''') {
        $raw = [regex]::Match($tag, "href='([^']+)'").Groups[1].Value
        $abs = Resolve-Url $raw
        if ($cssLocal.ContainsKey($abs)) {
            $newTag = [regex]::Replace($tag, "href='[^']+'", "href=`"$($cssLocal[$abs])`"")
            $newTag = [regex]::Replace($newTag, "\s+crossorigin='anonymous'", '')
            $html = $html.Replace($tag, $newTag)
        }
        continue
    }
    if ($tag -match 'rel="(icon|apple-touch-icon)"') {
        $raw = [regex]::Match($tag, 'href="([^"]+)"').Groups[1].Value
        $abs = Resolve-Url $raw
        $hash = Get-Hash $abs
        $ext = Get-Ext $abs '.png'
        $rel = "assets/img/$hash$ext"
        $full = Join-Path $root ($rel -replace '/', '\')
        if (-not (Test-Path $full)) { [void](Invoke-Download $abs $full) }
        $html = $html.Replace($tag, ([regex]::Replace($tag, 'href="[^"]+"', "href=`"$rel`"")))
        continue
    }
    if ($tag -match 'rel=.dns-prefetch.' -or $tag -match 'rel=.modulepreload.' -or $tag -match 'rel=.alternate.') {
        $html = $html.Replace($tag, '')
    }
}

# ---------------------------------------------------------------- 6. scripts out
$html = [regex]::Replace($html, '<script\b[^>]*>[\s\S]*?</script>', '')
$html = [regex]::Replace($html, '<script\b[^>]*/>', '')

# ---------------------------------------------------------------- 7. background urls in inline CSS
foreach ($u in $bgLocal.Keys) {
    $html = $html.Replace($u, $bgLocal[$u])
}

# ---------------------------------------------------------------- 8. strip interaction attrs, tracking bits
$html = [regex]::Replace($html, '\s+data-wp-[^=\s>]+=(\x27[^\x27]*\x27|"[^"]*")', '')
$html = [regex]::Replace($html, '\s+data-carousel-extra=\x27[^\x27]*\x27', '')
$html = [regex]::Replace($html, "<input type='hidden' name='jetpack_contact_form_jwt'[^>]*>", '')
$html = [regex]::Replace($html, '<meta name="msapplication-TileImage"[^>]*>', '')
$html = $html -replace '&nbsp;', ' '

# ---------------------------------------------------------------- 9. inject local css + js
$html = $html.Replace('</head>', @"
<link rel="stylesheet" href="assets/css/fonts.css" />
<link rel="stylesheet" href="assets/css/site.css" />
</head>
"@)
$html = $html.Replace('</body>', @"
<script src="assets/js/main.js"></script>
</body>
"@)

# Body classes for our interactions
$html = $html.Replace('<body class="home blog', '<body class="home blog')

[IO.File]::WriteAllText((Join-Path $root 'index.html'), $html, $utf8)

Write-Host ""
Write-Host "index.html KB: $([Math]::Round((Get-Item (Join-Path $root 'index.html')).Length / 1KB, 1))"
Write-Host "fonts.css KB: $([Math]::Round((Get-Item (Join-Path $root 'assets\css\fonts.css')).Length / 1KB, 1))"
Write-Host "img total MB: $([Math]::Round((Get-ChildItem (Join-Path $root 'assets\img') | Measure-Object Length -Sum).Sum / 1MB, 2))"
if ($script:failed.Count -gt 0) {
    Write-Host "FAILED ($($script:failed.Count)):"
    $script:failed | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" }
}
