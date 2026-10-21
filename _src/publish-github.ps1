<#
    Publishes the site to GitHub using the REST API (no git installation needed).

    Usage:
        .\publish-github.ps1 -Token ghp_xxx -RepoName pioneer-design-website -Public

    Creates the repository if it does not exist, uploads every site file in a single
    commit, then turns on GitHub Pages so the site gets a live URL.
#>
param(
    [Parameter(Mandatory = $true)][string]$Token,
    [string]$RepoName = 'pioneer-design-website',
    [string]$Description = 'The Pioneer Design - interior design website',
    [switch]$Public
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$root = Split-Path $PSScriptRoot -Parent
$headers = @{
    Authorization          = "Bearer $Token"
    'User-Agent'           = 'pioneer-design-publisher'
    Accept                 = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
}
$api = 'https://api.github.com'

function Invoke-GitHub {
    param(
        [string]$Method,
        [string]$Uri,
        $Body,
        [int[]]$AcceptStatus = @(200, 201)
    )
    $params = @{ Method = $Method; Uri = $Uri; Headers = $headers; UseBasicParsing = $true }
    if ($null -ne $Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 10 -Compress)
        $params.ContentType = 'application/json; charset=utf-8'
    }
    for ($try = 1; $try -le 3; $try++) {
        try {
            $resp = Invoke-WebRequest @params
            return ($resp.Content | ConvertFrom-Json)
        } catch {
            $code = $null
            if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
            if ($try -eq 3) { throw }
            if ($code -in 500, 502, 503, 504) { Start-Sleep -Seconds (2 * $try); continue }
            throw
        }
    }
}

Write-Host 'Authenticating...'
$me = Invoke-GitHub -Method GET -Uri "$api/user"
$owner = $me.login
Write-Host "  signed in as $owner"

Write-Host "Creating repository $owner/$RepoName ..."
try {
    $repo = Invoke-GitHub -Method POST -Uri "$api/user/repos" -Body @{
        name        = $RepoName
        description = $Description
        private     = (-not $Public)
        has_issues  = $true
        has_wiki    = $false
        has_projects = $false
        auto_init   = $false
    }
} catch {
    $code = $null
    if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
    if ($code -eq 422) {
        throw "A repository named '$RepoName' already exists for $owner. Re-run with a different -RepoName or delete it first."
    }
    throw
}
Write-Host "  created $($repo.html_url)"

# ------------------------------------------------------------------ files
$skip = '\\(\.git|_src\\tmp)\\'
$files = Get-ChildItem $root -Recurse -File -Force |
    Where-Object { $_.FullName -notmatch $skip } |
    Sort-Object FullName

Write-Host "Uploading $($files.Count) files ..."
$tree = New-Object System.Collections.ArrayList
$n = 0
foreach ($f in $files) {
    $n++
    $rel = $f.FullName.Substring($root.Length + 1).Replace('\', '/')
    $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($f.FullName))
    $blob = Invoke-GitHub -Method POST -Uri "$api/repos/$owner/$RepoName/git/blobs" -Body @{
        content  = $b64
        encoding = 'base64'
    }
    [void]$tree.Add(@{
        path = $rel
        mode = '100644'
        type = 'blob'
        sha  = $blob.sha
    })
    if ($n % 10 -eq 0 -or $n -eq $files.Count) { Write-Host "  $n / $($files.Count)" }
}

Write-Host 'Creating tree, commit and branch ...'
$newTree = Invoke-GitHub -Method POST -Uri "$api/repos/$owner/$RepoName/git/trees" -Body @{ tree = $tree }
$commit = Invoke-GitHub -Method POST -Uri "$api/repos/$owner/$RepoName/git/commits" -Body @{
    message = "The Pioneer Design website`n`nHome, About, Projects and 404 pages with embedded fonts,`nlocal images and vanilla JS interactions."
    tree    = $newTree.sha
}
[void](Invoke-GitHub -Method POST -Uri "$api/repos/$owner/$RepoName/git/refs" -Body @{
    ref = 'refs/heads/main'
    sha = $commit.sha
})

# ------------------------------------------------------------------ pages
$pagesUrl = $null
Write-Host 'Enabling GitHub Pages ...'
try {
    $pages = Invoke-GitHub -Method POST -Uri "$api/repos/$owner/$RepoName/pages" -Body @{
        source = @{ branch = 'main'; path = '/' }
    }
    $pagesUrl = $pages.html_url
} catch {
    try {
        $pages = Invoke-GitHub -Method PUT -Uri "$api/repos/$owner/$RepoName/pages" -Body @{
            source = @{ branch = 'main'; path = '/' }
        }
        $pagesUrl = $pages.html_url
    } catch {
        Write-Host '  (Pages could not be enabled automatically - turn it on in Settings > Pages)'
    }
}

Write-Host ''
Write-Host '========================================================'
Write-Host "Repository : $($repo.html_url)"
if ($pagesUrl) { Write-Host "Live site  : $pagesUrl" }
Write-Host '========================================================'
