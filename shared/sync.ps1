<#
.SYNOPSIS
  Sync shared ecosystem components (shared/) into projects.
.DESCRIPTION
  Copies canonical files from shared/ into projects. Projects stay
  self-contained for deployment (tar over project root); canonical
  source of truth lives in shared/.
.EXAMPLE
  .\sync.ps1
#>

$ErrorActionPreference = 'Stop'

# shared/ живёт внутри проекта na-web; корень экосистемы — на два уровня выше
$shared = $PSScriptRoot
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# --- Copy map: [source] -> [target list] ---
$map = @{
  (Join-Path $shared 'php\auth-client\AuthClient.php') = @(
    (Join-Path $root 'contest-web\includes\AuthClient.php'),
    (Join-Path $root 'python-web\sandbox\AuthClient.php'),
    (Join-Path $root 'ai-web\sandbox\AuthClient.php'),
    (Join-Path $root 'j-web\src\AuthClient.php')
  )
  (Join-Path $shared 'php\progress-reporter\ProgressReporter.php') = @(
    (Join-Path $root 'python-web\sandbox\ProgressReporter.php'),
    (Join-Path $root 'ai-web\sandbox\ProgressReporter.php')
  )
  (Join-Path $shared 'css\design-tokens.css') = @(
    (Join-Path $root 'na-web\css\design-tokens.css'),
    (Join-Path $root 'oge-web\assets\design-tokens.css'),
    (Join-Path $root 'office-web\assets\css\design-tokens.css'),
    (Join-Path $root 'inf-web\css\design-tokens.css'),
    (Join-Path $root 'vpr7\assets\design-tokens.css')
  )
  (Join-Path $shared 'js\progress-client.js') = @(
    (Join-Path $root 'oge-web\js\progress-client.js'),
    (Join-Path $root 'office-web\assets\js\progress-client.js'),
    (Join-Path $root 'inf-web\js\progress-client.js'),
    (Join-Path $root 'vpr7\js\progress-client.js'),
    (Join-Path $root 'na-web\js\progress-client.js')
  )
  (Join-Path $root 'auth-web\assets\js\tracking-client.js') = @(
    (Join-Path $root 'oge-web\js\tracking-client.js'),
    (Join-Path $root 'office-web\assets\js\tracking-client.js'),
    (Join-Path $root 'inf-web\js\tracking-client.js'),
    (Join-Path $root 'vpr7\js\tracking-client.js'),
    (Join-Path $root 'na-web\js\tracking-client.js'),
    (Join-Path $root 'j-web\assets-src\public\tracking-client.js')
  )
  (Join-Path $shared 'js\progress-sync\oge.js') = @(
    (Join-Path $root 'oge-web\js\progress-sync.js')
  )
  (Join-Path $shared 'js\progress-sync\office.js') = @(
    (Join-Path $root 'office-web\assets\js\progress-sync.js')
  )
  (Join-Path $shared 'js\progress-sync\inf.js') = @(
    (Join-Path $root 'inf-web\js\progress-sync.js')
  )
  (Join-Path $shared 'js\progress-sync\vpr.js') = @(
    (Join-Path $root 'vpr7\js\progress-sync.js')
  )
  (Join-Path $shared 'pwa\offline.html') = @(
    (Join-Path $root 'oge-web\offline.html'),
    (Join-Path $root 'office-web\offline.html'),
    (Join-Path $root 'vpr7\offline.html'),
    (Join-Path $root 'ai-web\offline.html')
  )
  (Join-Path $shared 'pwa\404.html') = @(
    (Join-Path $root 'oge-web\404.html'),
    (Join-Path $root 'office-web\404.html'),
    (Join-Path $root 'vpr7\404.html'),
    (Join-Path $root 'ai-web\404.html')
  )
}

foreach ($src in $map.Keys) {
  if (-not (Test-Path -LiteralPath $src)) {
    Write-Host "SKIP (no source): $src" -ForegroundColor Yellow
    continue
  }
  foreach ($dst in $map[$src]) {
    $dstDir = Split-Path -Parent $dst
    if (-not (Test-Path -LiteralPath $dstDir)) {
      New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $src -Destination $dst -Force
    Write-Host "SYNC: $($dst.Replace($root, '.'))" -ForegroundColor Green
  }
}

Write-Host "Done. Shared components synced." -ForegroundColor Cyan
