$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$root = 'D:\Simcha\The Pioneer Design Website'
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'

foreach ($d in @('assets', 'assets\img', 'assets\css', 'assets\fonts', 'assets\js')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $root $d) | Out-Null
}

$script:urlMap = @{}
$script:totalBytes = 0
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

function Get-FileName([string]$url) {
    $sha = [Security.Cryptography.SHA1]::Create()
    $hash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($url))) -replace '-', ''
    return $hash.ToLower()
}

function Save-Asset {
    param([string]$url, [string]$kind, [string]$extFallback = '.bin')
    if ([string]::IsNullOrWhiteSpace($url)) { return $null }
    if ($url.StartsWith('data:')) { return $null }
    $abs = Resolve-Url $url
    if ($script:urlMap.ContainsKey($abs)) { return $script:urlMap[$abs] }

    $ext = Get-Ext $abs $extFallback
    $rel = "assets/$kind/$(Get-FileName $abs)$ext"
    $full = Join-Path $root ($rel -replace '/', '\')

    if (-not (Test-Path $full)) {
        $ok = $false
        for ($try = 1; $try -le 3 -and -not $ok; $try++) {
            try {
                Invoke-WebRequest -Uri $abs -OutFile $full -UserAgent $ua -UseBasicParsing -TimeoutSec 90
                $ok = $true
            } catch {
                if ($try -eq 3) {
                    [void]$script:failed.Add("$abs  ::  $($_.Exception.Message)")
                    return $null
                }
                Start-Sleep -Milliseconds 500
            }
        }
        if (Test-Path $full) {
            $script:totalBytes += (Get-Item $full).Length
        }
    }
    $script:urlMap[$abs] = $rel
    return $rel
}

$html = [IO.File]::ReadAllText((Join-Path $root '_src\original.html'))

# ---------- CSS files ----------
$cssUrls = [regex]::Matches($html, "<link\b[^>]*rel='stylesheet'[^>]*>") |
    ForEach-Object { [regex]::Match($_.Value, "href='([^']+)'") } |
    Where-Object { $_.Success } |
    ForEach-Object { Resolve-Url $_.Groups[1].Value } |
    Sort-Object -Unique

Write-Host "CSS files: $($cssUrls.Count)"
foreach ($u in $cssUrls) {
    $local = Save-Asset $u 'css' '.css'
    Write-Host ("  {0} -> {1}" -f $u.Substring(0, [Math]::Min(80, $u.Length)), $local)
}

# ---------- Fonts ----------
$fontUrls = [regex]::Matches($html, "src:url\('([^']+)'\)") |
    ForEach-Object { $_.Groups[1].Value } |
    Where-Object { $_ -match '^https?://' } |
    Sort-Object -Unique

Write-Host "Fonts: $($fontUrls.Count)"
$i = 0
foreach ($u in $fontUrls) {
    $i++
    $local = Save-Asset $u 'fonts' '.woff2'
    if ($i % 20 -eq 0) { Write-Host "  ... $i / $($fontUrls.Count)" }
}

# ---------- Background images (inline styles) ----------
$bgUrls = [regex]::Matches($html, "url\(&apos;(https?://[^&]+(?:&(?!apos;)[^&]*)*)&apos;\)") |
    ForEach-Object { $_.Groups[1].Value } |
    Sort-Object -Unique

Write-Host "Backgrounds: $($bgUrls.Count)"
foreach ($u in $bgUrls) {
    $local = Save-Asset $u 'img' '.jpg'
    Write-Host "  $u"
    Write-Host "    -> $local"
}

# ---------- Inline <img> ----------
$imgTags = [regex]::Matches($html, '<img\b[^>]*>') | ForEach-Object { $_.Value } | Sort-Object -Unique
Write-Host "Images: $($imgTags.Count)"
foreach ($tag in $imgTags) {
    $m = [regex]::Match($tag, 'src="([^"]*)"')
    if (-not $m.Success) { continue }
    $src = $m.Groups[1].Value
    if ($src.StartsWith('data:')) { continue }
    $local = Save-Asset $src 'img' '.jpg'
    if ($local) {
        $script:urlMap["IMG|$src"] = $local
        Write-Host ("  {0}  ->  {1}" -f (Split-Path $src -Leaf), $local)
    }
}

# ---------- CSS url() references ----------
$cssMap = @{}
foreach ($u in $cssUrls) {
    $local = $script:urlMap[(Resolve-Url $u)]
    if (-not $local) { continue }
    $cssMap[$u] = $local
}

foreach ($k in $cssMap.Keys) {
    $cssFile = Join-Path $root ($cssMap[$k] -replace '/', '\')
    $cssText = [IO.File]::ReadAllText($cssFile)
    $refs = [regex]::Matches($cssText, "url\((['""]?)([^)'""]+)\1\)")
    foreach ($r in $refs) {
        $ref = $r.Groups[2].Value.Trim()
        if ($ref.StartsWith('data:') -or $ref.StartsWith('#')) { continue }
        $abs = $null
        try { $abs = ([Uri]::new([Uri](Resolve-Url $k), $ref)).AbsoluteUri } catch { continue }
        $kind = if ((Get-Ext $abs '.png') -match '^\.(woff2?|ttf|otf)$') { 'fonts' } else { 'img' }
        $loc = Save-Asset $abs $kind '.png'
        if ($loc) {
            $rel = '../' + ($loc -replace '^assets/', '')
            $cssText = $cssText.Replace($r.Value, "url($rel)")
        }
    }
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($cssFile, $cssText, $utf8)
}

Write-Host ""
Write-Host "Total downloaded MB: $([Math]::Round($script:totalBytes / 1MB, 2))"
Write-Host "Assets: $($script:urlMap.Count)"
if ($script:failed.Count -gt 0) {
    Write-Host "FAILED:"
    $script:failed | ForEach-Object { Write-Host "  $_" }
}

$script:urlMap | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $root '_src\asset-map.json') -Encoding UTF8
