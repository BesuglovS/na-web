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

# shared/ живёт внутри проекта na-web; корень экосистемы — на два уровня выше.
# Карта источников/приёмников — в sync-map.ps1 (общая с check-sync.ps1).
$shared = $PSScriptRoot
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $PSScriptRoot 'sync-map.ps1')
$map = Get-SyncMap

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
