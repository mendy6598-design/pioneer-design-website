$ErrorActionPreference = 'Stop'
$root = 'D:\Simcha\The Pioneer Design Website'
$port = 8123
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()
Write-Host "Serving $root on http://localhost:$port/"

$mime = @{
    '.html' = 'text/html; charset=utf-8'; '.css' = 'text/css; charset=utf-8';
    '.js' = 'application/javascript; charset=utf-8'; '.json' = 'application/json';
    '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'; '.png' = 'image/png';
    '.webp' = 'image/webp'; '.gif' = 'image/gif'; '.svg' = 'image/svg+xml';
    '.woff2' = 'font/woff2'; '.woff' = 'font/woff'; '.ttf' = 'font/ttf';
    '.ico' = 'image/x-icon'
}

while ($listener.IsListening) {
    try {
        $ctx = $listener.GetContext()
        $req = $ctx.Request
        $res = $ctx.Response
        $path = [Uri]::UnescapeDataString($req.Url.AbsolutePath)
        if ($path -eq '/') { $path = '/index.html' }
        $file = Join-Path $root ($path.TrimStart('/') -replace '/', '\')
        if (Test-Path $file -PathType Leaf) {
            $bytes = [IO.File]::ReadAllBytes($file)
            $ext = [IO.Path]::GetExtension($file).ToLower()
            $res.ContentType = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
            $res.ContentLength64 = $bytes.Length
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            $res.StatusCode = 404
            $msg = [Text.Encoding]::UTF8.GetBytes("Not found: $path")
            $res.OutputStream.Write($msg, 0, $msg.Length)
        }
        $res.OutputStream.Close()
    } catch {
        # keep serving
    }
}
