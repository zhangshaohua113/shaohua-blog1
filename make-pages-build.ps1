# Generate GitHub Pages build: rewrite absolute links to relative ones.
# Portable: paths are derived from this script's location.
#   repo  = this script's folder (D:\ai\shaohua-site-mirror\ on this machine)
#   pages = sibling folder "<parent>\shaohua-pages-build"
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File make-pages-build.ps1
$ErrorActionPreference = 'Stop'
$src = $PSScriptRoot
$dst = Join-Path (Split-Path $PSScriptRoot -Parent) 'shaohua-pages-build'

if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
New-Item -ItemType Directory -Path $dst -Force | Out-Null

# copy ONLY site files/dirs (never .git, never scripts)
$items = @('index.html', 'about.html', 'css', 'js', 'api', 'posts', 'kb')
foreach ($it in $items) {
    $from = Join-Path $src $it
    if (Test-Path $from) { Copy-Item $from $dst -Recurse -Force }
}

# patch main.js: absolute api path -> relative
$mainJs = Join-Path $dst 'js\main.js'
$js = Get-Content $mainJs -Raw -Encoding UTF8
$js = $js.Replace("fetch('/api/posts.json'", "fetch('api/posts.json'")
[System.IO.File]::WriteAllText($mainJs, $js, (New-Object System.Text.UTF8Encoding($false)))

$files = Get-ChildItem $dst -Recurse -Filter '*.html'
$fixed = 0

foreach ($f in $files) {
    $rel = $f.FullName.Substring($dst.Length + 1).Replace('\', '/')
    $depth = ($rel -split '/').Count - 1
    $prefix = if ($depth -eq 0) { '' } else { ('../' * $depth) }

    $html = Get-Content $f.FullName -Raw -Encoding UTF8

    # 1) href="/  src="/  ->  href="<prefix>
    $step1 = [regex]::Replace($html, '(href|src)="/', { param($m) "$($m.Groups[1].Value)=`"$prefix" })

    # 2) normalize local paths: add index.html/.html suffix where needed
    $step2 = [regex]::Replace($step1, '(href|src)="(' + [regex]::Escape($prefix) + ')([^"#?]*)(#[^"]*)?"', {
        param($m)
        $attr = $m.Groups[1].Value
        $tail = $m.Groups[3].Value
        $frag = $m.Groups[4].Value
        if ($tail -eq '' -or $tail -eq 'index.html' -or $tail -eq '#') {
            return "$attr=`"$prefix" + 'index.html' + $frag + '"'
        }
        if ($tail -match '\.(css|js|json|png|jpg|svg|ico|webp|html)(/.*)?$') {
            return "$attr=`"$prefix$tail$frag`""
        }
        if ($tail -match '/$') { return "$attr=`"$prefix$tail$frag`"" }
        if ($tail -match '^(kb|kb/[^/]+)$') { return "$attr=`"$prefix$tail/index.html$frag`"" }
        if ($tail -match '^(posts/|kb/|about$|api/)') { return "$attr=`"$prefix$tail.html$frag`"" }
        return "$attr=`"$prefix$tail$frag`""
    })

    if ($step2 -ne $html) {
        [System.IO.File]::WriteAllText($f.FullName, $step2, (New-Object System.Text.UTF8Encoding($false)))
        $fixed++
    }
}

Write-Host ("Rewritten files: {0} / {1}" -f $fixed, $files.Count)
$bad = (Get-ChildItem $dst -Recurse -Filter '*.html' | Select-String -Pattern '(href|src)="/' | Measure-Object).Count
Write-Host ("Residual absolute links: {0} (should be 0)" -f $bad)

# 3) link integrity check: every relative target must exist
$missing = @()
foreach ($f in (Get-ChildItem $dst -Recurse -Filter '*.html')) {
    $html = Get-Content $f.FullName -Raw -Encoding UTF8
    foreach ($m in [regex]::Matches($html, '(?:href|src)="([^"#?]+)"')) {
        $target = $m.Groups[1].Value
        if ($target -match '^(https?:|data:|mailto:|//)') { continue }
        $full = [System.IO.Path]::GetFullPath((Join-Path $f.DirectoryName ($target -replace '/', '\')))
        if (-not (Test-Path $full)) { $missing += "$($f.Name) -> $target" }
    }
}
if ($missing.Count -eq 0) { Write-Host 'Link check: ALL OK' } else { Write-Host ('Link check missing: ' + $missing.Count); $missing | Select-Object -First 15; exit 1 }