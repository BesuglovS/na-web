<#
.SYNOPSIS
  Проверка, что вендоренные копии канонических файлов экосистемы не разошлись.
.DESCRIPTION
  Сверяет SHA256 копий с канонами по карте sync-map.ps1. Ничего не меняет.
.PARAMETER FailOnDrift
  Код возврата 1 при любом расхождении (для CI/деплой-пайплайнов).
.EXAMPLE
  .\check-sync.ps1                 # отчёт
  .\check-sync.ps1 -FailOnDrift    # отчёт + ненулевой код возврата
#>
param(
    [switch]$FailOnDrift
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'sync-map.ps1')

$map = Get-SyncMap
$root = $_root
$drift = 0

foreach ($src in $map.Keys) {
    $srcName = $src.Replace($root, '.')
    if (-not (Test-Path -LiteralPath $src)) {
        Write-Host "NO SOURCE: $srcName" -ForegroundColor Yellow
        continue
    }
    $srcHash = (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash
    foreach ($dst in $map[$src]) {
        if (-not (Test-Path -LiteralPath $dst)) {
            Write-Host "MISSING : $($dst.Replace($root, '.'))" -ForegroundColor Yellow
            $drift++
            continue
        }
        $dstHash = (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash
        if ($dstHash -ne $srcHash) {
            Write-Host "DRIFT   : $($dst.Replace($root, '.'))" -ForegroundColor Red
            $drift++
        }
    }
}

if ($drift -eq 0) {
    Write-Host "OK: все вендоренные копии идентичны канонам." -ForegroundColor Green
    exit 0
}

Write-Host "$drift расхождений. Запустите .\shared\sync.ps1 для исправления." -ForegroundColor Red
if ($FailOnDrift) {
    exit 1
}
exit 0
