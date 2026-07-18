<#
.SYNOPSIS
  Check all projects for updates and deploy changed ones.
.DESCRIPTION
  Reads project list from github.txt, fetches remote refs for each project,
  compares local and remote commits. If a project has new remote commits,
  pulls changes and runs the project's deploy.ps1.
.PARAMETER Projects
  Deploy only specific projects by name, comma-separated (e.g. -Projects "python-web,inf-web").
.PARAMETER DryRun
  Show what would happen without executing git pull or deploy.
.PARAMETER SkipPull
  Skip git pull step, only check and deploy.
.PARAMETER Force
  Deploy even if no new commits are detected.
.EXAMPLE
  .\deploy-all.ps1
  .\deploy-all.ps1 -Projects "python-web,inf-web"
  .\deploy-all.ps1 -DryRun
  .\deploy-all.ps1 -Force
#>

param(
  [string]$Projects,
  [switch]$DryRun,
  [switch]$SkipPull,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

# ─── 1. Resolve project list ───
$ScriptDir  = $PSScriptRoot
$ParentDir  = Split-Path -Parent $ScriptDir
$GithubFile = Join-Path $ScriptDir 'github.txt'

if (-not (Test-Path $GithubFile)) {
  Write-Host "ERROR: github.txt not found in $ScriptDir" -ForegroundColor Red
  exit 1
}

$allProjects = Get-Content $GithubFile |
  ForEach-Object { $_.Trim() } |
  Where-Object { $_ -ne '' } |
  ForEach-Object {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($_)
    [PSCustomObject]@{ Name = $name; Url = $_ }
  }

if ($Projects) {
  $projectFilter = $Projects -split '[,\s]+' | Where-Object { $_ -ne '' }
  $allProjects = $allProjects | Where-Object { $projectFilter -contains $_.Name }
  if (-not $allProjects) {
    Write-Host "ERROR: None of the specified projects found in github.txt" -ForegroundColor Red
    exit 1
  }
}

# ─── 2. Header ───
$modeLabel = if ($DryRun) { ' [DRY RUN]' } elseif ($Force) { ' [FORCE]' } else { '' }
Write-Host "`n=== Deploy All Projects${modeLabel} ===" -ForegroundColor Cyan
Write-Host "Projects folder: $ParentDir" -ForegroundColor Gray
Write-Host "Projects to check: $($allProjects.Count)" -ForegroundColor Gray
Write-Host ""

# ─── 3. Process each project ───
$results = @()

foreach ($project in $allProjects) {
  $name = $project.Name
  $dir  = Join-Path $ParentDir $name

  Write-Host "-- $name --" -ForegroundColor Yellow

  # Validate directory
  if (-not (Test-Path $dir)) {
    Write-Host "  Directory not found: $dir" -ForegroundColor Red
    $results += [PSCustomObject]@{ Project = $name; Status = 'ERROR'; Message = 'Directory not found' }
    continue
  }

  if (-not (Test-Path (Join-Path $dir '.git'))) {
    Write-Host "  Not a git repository" -ForegroundColor Red
    $results += [PSCustomObject]@{ Project = $name; Status = 'ERROR'; Message = 'Not a git repo' }
    continue
  }

  # Check for deploy.ps1
  $deployScript = Join-Path $dir 'deploy.ps1'
  if (-not (Test-Path $deployScript)) {
    Write-Host "  deploy.ps1 not found, skipping" -ForegroundColor DarkGray
    $results += [PSCustomObject]@{ Project = $name; Status = 'SKIP'; Message = 'No deploy.ps1' }
    continue
  }

  # git fetch
  Write-Host "  Fetching remote..." -ForegroundColor Gray
  if (-not $DryRun) {
    $global:ProgressPreference = 'SilentlyContinue'
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & git -C $dir fetch origin --quiet 2>&1 | Out-Null
    $fetchExit = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP
    if ($fetchExit -ne 0) {
      Write-Host "  git fetch failed" -ForegroundColor Red
      $results += [PSCustomObject]@{ Project = $name; Status = 'ERROR'; Message = 'git fetch failed' }
      continue
    }
  }

  # Detect default branch (main or master)
  $mainRef = $null
  $prevEAP = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  foreach ($branch in @('main', 'master')) {
    $out = & git -C $dir rev-parse --verify "origin/$branch" 2>&1
    if ($LASTEXITCODE -eq 0) {
      $mainRef = $branch
      break
    }
  }
  $ErrorActionPreference = $prevEAP

  if (-not $mainRef) {
    Write-Host "  Cannot detect default branch (main/master)" -ForegroundColor Red
    $results += [PSCustomObject]@{ Project = $name; Status = 'ERROR'; Message = 'No main/master branch' }
    continue
  }

  # Compare local and remote HEAD
  $prevEAP = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $localSha  = (& git -C $dir rev-parse HEAD 2>&1).Trim()
  $remoteSha = (& git -C $dir rev-parse "origin/$mainRef" 2>&1).Trim()
  $ErrorActionPreference = $prevEAP

  $needsDeploy = $false
  if ($Force) {
    $needsDeploy = $true
    Write-Host "  Force deploy requested" -ForegroundColor Magenta
  } elseif ($localSha -ne $remoteSha) {
    $needsDeploy = $true
    # Count how many commits behind
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $behindCount = (& git -C $dir rev-list HEAD..origin/$mainRef --count 2>&1).Trim()
    $ErrorActionPreference = $prevEAP
    Write-Host "  Local is $behindCount commit(s) behind origin/$mainRef" -ForegroundColor Yellow
  } else {
    Write-Host "  Up to date (HEAD = $mainRef)" -ForegroundColor Green
  }

  if (-not $needsDeploy) {
    $results += [PSCustomObject]@{ Project = $name; Status = 'OK'; Message = 'Up to date' }
    continue
  }

  # git pull
  if (-not $SkipPull) {
    Write-Host "  Pulling changes..." -ForegroundColor Cyan
    if ($DryRun) {
      Write-Host "    [DryRun] git pull origin $mainRef" -ForegroundColor Yellow
    } else {
      $prevEAP = $ErrorActionPreference
      $ErrorActionPreference = 'Continue'
      $pullOutput = & git -C $dir pull origin $mainRef 2>&1 | Out-String
      $pullExit = $LASTEXITCODE
      $ErrorActionPreference = $prevEAP
      if ($pullExit -ne 0) {
        Write-Host "  git pull failed: $($pullOutput.Trim())" -ForegroundColor Red
        $results += [PSCustomObject]@{ Project = $name; Status = 'ERROR'; Message = 'git pull failed' }
        continue
      }
      Write-Host "    OK" -ForegroundColor DarkGray
    }
  }

  # Deploy
  Write-Host "  Deploying..." -ForegroundColor Cyan
  if ($DryRun) {
    Write-Host "    [DryRun] .\deploy.ps1" -ForegroundColor Yellow
    $results += [PSCustomObject]@{ Project = $name; Status = 'DRY'; Message = 'Would deploy' }
  } else {
    & $deployScript
    $deployExit = $LASTEXITCODE

    if ($deployExit -ne 0) {
      Write-Host "  Deploy failed (exit code: $deployExit)" -ForegroundColor Red
      $results += [PSCustomObject]@{ Project = $name; Status = 'ERROR'; Message = "Deploy failed (exit $deployExit)" }
    } else {
      Write-Host "  Deployed successfully" -ForegroundColor Green
      $results += [PSCustomObject]@{ Project = $name; Status = 'DEPLOYED'; Message = 'Done' }
    }
  }

  Write-Host ""
}

# ─── 4. Summary ───
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host ""

$statusColors = @{
  'OK'       = 'Green'
  'DEPLOYED' = 'Green'
  'DRY'      = 'Yellow'
  'SKIP'     = 'DarkGray'
  'ERROR'    = 'Red'
}

foreach ($r in $results) {
  $color = $statusColors[$r.Status]
  if (-not $color) { $color = 'White' }
  $statusPad = $r.Status.PadRight(10)
  Write-Host "  [$statusPad] " -ForegroundColor $color -NoNewline
  Write-Host "$($r.Project) - $($r.Message)"
}

$deployed = ($results | Where-Object { $_.Status -eq 'DEPLOYED' }).Count
$failed   = ($results | Where-Object { $_.Status -eq 'ERROR' }).Count
$skipped  = ($results | Where-Object { $_.Status -eq 'OK' }).Count

Write-Host ""
Write-Host "Deployed: $deployed  |  Up to date: $skipped  |  Errors: $failed" -ForegroundColor Cyan
Write-Host ""

if ($failed -gt 0) {
  exit 1
}