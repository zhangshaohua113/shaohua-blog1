# 一键双推：main（备份镜像）提交推送 → 重建 Pages 版 → gh-pages 提交推送
# 路径全部相对脚本位置派生，换电脑后整个文件夹搬走即可用
$ErrorActionPreference = 'Continue'
$repo = $PSScriptRoot
$parent = Split-Path $PSScriptRoot -Parent
$pagesBuild = Join-Path $parent 'shaohua-pages-build'
$worktree = Join-Path $parent 'shaohua-pages-worktree'
$env:GIT_TERMINAL_PROMPT = '0'
$goodIPs = @('140.82.114.3','20.27.177.113','140.82.121.4','20.200.245.247')

function Push-Branch([string]$branch) {
    Set-Location $repo
    foreach ($ip in $goodIPs) {
        $out = git -c http.curlopt.resolve="github.com:443:$ip" -c http.version=HTTP/1.1 push origin $branch 2>&1
        if ($LASTEXITCODE -eq 0) { Write-Host "  OK push $branch via $ip"; return $true }
        Write-Host "  push $branch failed ($ip), try next node..."; Start-Sleep -Seconds 4
    }
    Write-Host "  FAILED: $branch (network), rerun script later"
    return $false
}

Write-Host '=== [1/3] commit + push main (backup mirror) ==='
Set-Location $repo
git add -A 2>&1 | Out-Null; $null = $LASTEXITCODE
$changed = git status --porcelain
if ($changed) {
    git commit -m "site mirror update $(Get-Date -Format 'yyyy-MM-dd HH:mm')" 2>&1 | Out-Null
    Write-Host "  committed: $((git log --oneline -1))"
} else { Write-Host '  no change, skip commit' }
if (-not (Push-Branch 'main')) { exit 1 }

Write-Host '=== [2/3] rebuild pages version (relative links) ==='
& (Join-Path $repo 'make-pages-build.ps1')
if ($LASTEXITCODE -ne 0) { Write-Host 'FAILED: pages build'; exit 1 }

Write-Host '=== [3/3] sync into gh-pages worktree and push ==='
if (-not (Test-Path $worktree)) {
    git worktree add $worktree gh-pages 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Host 'FAILED: worktree (gh-pages branch missing?)'; exit 1 }
    Write-Host "  worktree ready: $worktree"
}
robocopy $pagesBuild $worktree /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
Set-Location $worktree
git add -A 2>&1 | Out-Null; $null = $LASTEXITCODE
$changed2 = git status --porcelain
if ($changed2) {
    git commit -m "pages build update $(Get-Date -Format 'yyyy-MM-dd HH:mm')" 2>&1 | Out-Null
    Write-Host "  committed gh-pages: $((git log --oneline -1))"
} else { Write-Host '  gh-pages no change, skip commit' }
Set-Location $repo
if (-not (Push-Branch 'gh-pages')) { exit 1 }

Write-Host ''
Write-Host '=== ALL DONE: backup + pages both pushed ==='