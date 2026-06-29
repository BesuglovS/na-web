# PowerShell script to clone all repositories from github.txt into the current folder
# following the server structure at 79.143.31.184

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$GithubFile = Join-Path $ScriptDir "github.txt"

if (-not (Test-Path $GithubFile)) {
    Write-Error "File github.txt not found in $ScriptDir"
    exit 1
}

$RepoUrls = Get-Content $GithubFile

Write-Host "=== Cloning repositories ===" -ForegroundColor Cyan
Write-Host "Target folder: $ScriptDir" -ForegroundColor Gray
Write-Host ""

foreach ($Url in $RepoUrls) {
    $Url = $Url.Trim()
    if ([string]::IsNullOrWhiteSpace($Url)) {
        continue
    }

    $RepoName = [System.IO.Path]::GetFileNameWithoutExtension($Url)
    $TargetDir = Join-Path $ScriptDir $RepoName

    Write-Host "Repository: $RepoName" -ForegroundColor Yellow

    if (Test-Path $TargetDir) {
        Write-Host "  Folder '$RepoName' exists. Updating (git pull)..." -ForegroundColor Yellow
        Push-Location $TargetDir
        git pull 2>&1 | ForEach-Object {
            if ($_ -match "fatal|error") {
                Write-Host "  $_" -ForegroundColor Red
            } else {
                Write-Host "  $_" -ForegroundColor DarkGray
            }
        }
        Pop-Location
    } else {
        Write-Host "  Cloning $Url into $TargetDir ..." -ForegroundColor Green
        git clone $Url $TargetDir 2>&1 | ForEach-Object {
            if ($_ -match "fatal|error") {
                Write-Host "  $_" -ForegroundColor Red
            } else {
                Write-Host "  $_" -ForegroundColor DarkGray
            }
        }
    }

    Write-Host ""
}

Write-Host "=== Done! ===" -ForegroundColor Cyan

# Show folder structure
Write-Host ""
Write-Host "Local folders with git repos:" -ForegroundColor Cyan
Get-ChildItem $ScriptDir -Directory | Where-Object {
    Test-Path (Join-Path $_.FullName ".git")
} | ForEach-Object {
    Write-Host "  $($_.Name)" -ForegroundColor White
}