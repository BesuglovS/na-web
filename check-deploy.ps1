<#
.SYNOPSIS
  Compare the deployed version (version.json on the server) with the local repo.

.DESCRIPTION
  Reads DEPLOY_* from each project's .env, fetches version.json (HTTPS first,
  SSH cat from the webroot as a fallback) and compares commit/tree with the
  current local git state.

  Statuses:
    MATCH     - deployed content equals the local working tree
    STALE     - production runs an older commit
    DIFFERS   - production was built from an uncommitted state and differs
    DIVERGED  - production commit is not in the local history (other branch/repo)
    NO_MARKER - version.json is missing (deploy happened before the marker)
    NO_GIT    - no local git repository

.PARAMETER Projects
  Comma/space separated project names (default: all).

.PARAMETER Ssh
  Skip HTTPS and read version.json over SSH only.

.PARAMETER Json
  Print the result as JSON.

.PARAMETER Quiet
  Do not print the table (used by deploy-all.ps1).

.PARAMETER PassThru
  Return result objects (used by deploy-all.ps1).

.EXAMPLE
  .\check-deploy.ps1
  .\check-deploy.ps1 -Projects "inf-web,ai-web"
  .\check-deploy.ps1 -Json
#>

param(
  [string]$Projects,
  [switch]$Ssh,
  [switch]$Json,
  [switch]$Quiet,
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$root = Split-Path -Parent $PSScriptRoot

# data-web is intentionally absent: the local folder is not the source of production.
$map = @(
  @{ Name = 'ai-web';      Domain = 'ai.nayanovaacademy.ru';      MarkerRel = 'version.json' },
  @{ Name = 'python-web';  Domain = 'python.nayanovaacademy.ru';  MarkerRel = 'version.json' },
  @{ Name = 'auth-web';    Domain = 'auth.nayanovaacademy.ru';    MarkerRel = 'version.json' },
  @{ Name = 'contest-web'; Domain = 'contest.nayanovaacademy.ru'; MarkerRel = 'version.json' },
  @{ Name = 'inf-web';     Domain = 'inf.nayanovaacademy.ru';     MarkerRel = 'version.json' },
  @{ Name = 'vpr7';        Domain = 'vpr.nayanovaacademy.ru';     MarkerRel = 'version.json' },
  @{ Name = 'office-web';  Domain = 'office.nayanovaacademy.ru';  MarkerRel = 'version.json' },
  @{ Name = 'na-web';      Domain = 'nayanovaacademy.ru';         MarkerRel = 'version.json' },
  @{ Name = 'r-web';       Domain = 'r.nayanovaacademy.ru';       MarkerRel = 'version.json' },
  @{ Name = 'oge-web';     Domain = 'oge.nayanovaacademy.ru';     MarkerRel = 'version.json' },
  @{ Name = 'j-web';       Domain = 'j.nayanovaacademy.ru';       MarkerRel = 'public/version.json' }
)

if ($Projects) {
  $filter = $Projects -split '[,\s]+' | Where-Object { $_ }
  $map = @($map | Where-Object { $filter -contains $_.Name })
  if ($map.Count -eq 0) {
    Write-Host "ERROR: unknown project(s): $Projects" -ForegroundColor Red
    exit 2
  }
}

function Read-DotEnv([string]$dir) {
  $h = @{}
  $f = Join-Path $dir '.env'
  if (Test-Path $f) {
    Get-Content $f -Encoding UTF8 | ForEach-Object {
      if ($_ -match '^\s*([^#=]+?)\s*=\s*(.+?)\s*$') { $h[$matches[1].Trim()] = $matches[2].Trim() }
    }
  }
  return $h
}

function Get-SshArgs([string]$name, $cfg) {
  $port = $cfg['DEPLOY_SSH_PORT']; if (-not $port) { $port = '22' }
  $key = $cfg['DEPLOY_SSH_KEY']
  if ($key -and -not [IO.Path]::IsPathRooted($key)) { $key = Join-Path (Join-Path $root $name) $key }
  $a = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=15')
  if ($port -ne '22') { $a += @('-p', $port) }
  if ($key) { $a += @('-i', $key) }
  $a += "$($cfg['DEPLOY_SSH_USER'])@$($cfg['DEPLOY_SSH_HOST'])"
  return $a
}

function Get-RemoteMarker([string]$name, [string]$domain, [string]$markerRel, [hashtable]$cfg) {
  if (-not $Ssh -and $domain) {
    try {
      $uri = "https://$domain/$markerRel`?t=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
      $m = Invoke-RestMethod -Uri $uri -TimeoutSec 15 -UseBasicParsing -ErrorAction Stop
      # nginx may serve index.html for a missing path: accept only a real marker
      if ($m -and $m.PSObject.Properties['project'] -and $m.PSObject.Properties['commit']) { return $m }
    } catch { }
  }

  $remotePath = $cfg['DEPLOY_REMOTE_PATH']
  if (-not $remotePath -or -not $cfg['DEPLOY_SSH_HOST']) { return $null }
  $remotePath = $remotePath.TrimEnd('/')
  $sshArgs = Get-SshArgs $name $cfg
  $conn = $sshArgs[0..($sshArgs.Count - 2)]
  $remote = $sshArgs[-1]
  $rp = $remotePath -replace "'", "'\''"
  $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try {
    $out = & ssh @conn $remote "cat '$rp/$markerRel' 2>/dev/null" 2>$null
    $code = $LASTEXITCODE
  } finally { $ErrorActionPreference = $prev }
  if ($code -ne 0 -or -not $out) { return $null }
  try { return (($out -join "`n") | ConvertFrom-Json) } catch { return $null }
}

function Get-LocalState([string]$dir) {
  if (-not (Test-Path (Join-Path $dir '.git'))) { return $null }
  $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try {
    $head   = (& git -C $dir rev-parse HEAD 2>$null | Select-Object -First 1)
    $branch = (& git -C $dir rev-parse --abbrev-ref HEAD 2>$null | Select-Object -First 1)
    # Real content changes only (EOL-only noise from builds is ignored)
    $tracked   = @(& git -C $dir diff HEAD --numstat 2>$null)
    $untracked = @(& git -C $dir ls-files -o --exclude-standard 2>$null)
    $dirty = $tracked.Count + $untracked.Count
    $tree = $null
    if ($dirty -gt 0) {
      $stash = (& git -C $dir stash create 2>$null | Select-Object -First 1)
      if ($stash) { $tree = (& git -C $dir rev-parse "$($stash.Trim())^{tree}" 2>$null | Select-Object -First 1) }
    } else {
      $tree = (& git -C $dir rev-parse 'HEAD^{tree}' 2>$null | Select-Object -First 1)
    }
  } finally { $ErrorActionPreference = $prev }
  return [pscustomobject]@{
    Head   = if ($head)   { ([string]$head).Trim() }   else { $null }
    Branch = if ($branch) { ([string]$branch).Trim() } else { $null }
    Tree   = if ($tree)   { ([string]$tree).Trim() }   else { $null }
    Dirty  = [int]$dirty
  }
}

function Compare-WithProd($m, $l, [string]$dir) {
  if (-not $m) { return @{ Status = 'NO_MARKER'; Detail = 'version.json not found on server' } }
  if (-not $l) { return @{ Status = 'NO_GIT';    Detail = 'no local git repository' } }

  if ($m.tree -and $l.Tree -and $m.tree -eq $l.Tree) {
    return @{ Status = 'MATCH'; Detail = 'content equals local working tree' }
  }
  if ($m.commit -and $m.commit -eq $l.Head -and -not $m.dirty -and $l.Dirty -eq 0) {
    return @{ Status = 'MATCH'; Detail = "commit $(([string]$l.Head).Substring(0, 7))" }
  }

  $treeFiles = $null; $ancestor = $false; $behind = $null
  $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try {
    if ($m.tree -and $l.Tree) {
      & git -C $dir cat-file -e "$($m.tree)^{tree}" 2>$null
      if ($LASTEXITCODE -eq 0) {
        $treeFiles = @(& git -C $dir diff --name-only $m.tree $l.Tree 2>$null)
        if ($LASTEXITCODE -ne 0) { $treeFiles = $null }
      }
    }
    if ($m.commit) {
      & git -C $dir merge-base --is-ancestor $m.commit $l.Head 2>$null
      $ancestor = ($LASTEXITCODE -eq 0)
      if ($ancestor -and $m.commit -ne $l.Head) {
        $behind = (& git -C $dir rev-list --count "$($m.commit)..$($l.Head)" 2>$null | Select-Object -First 1)
      }
    }
  } finally { $ErrorActionPreference = $prev }

  if ($null -ne $treeFiles) {
    if ($treeFiles.Count -eq 0) { return @{ Status = 'MATCH'; Detail = 'trees are equal' } }
    $status = if ($ancestor) { 'STALE' } else { 'DIFFERS' }
    $detail = if ($ancestor -and $m.commit -ne $l.Head) {
      "prod is $behind commit(s) behind; files differ: $($treeFiles.Count)"
    } elseif ($ancestor) {
      "prod built from a dirty tree; files differ: $($treeFiles.Count)"
    } else {
      "prod differs; files differ: $($treeFiles.Count)"
    }
    return @{ Status = $status; Detail = $detail; Files = @($treeFiles | Select-Object -First 10) }
  }

  if ($m.commit -and $m.commit -eq $l.Head) {
    return @{ Status = 'DIFFERS'; Detail = 'prod built from a dirty tree (tree object unavailable)' }
  }
  if ($ancestor) { return @{ Status = 'STALE'; Detail = "prod is $behind commit(s) behind" } }
  $prodCommit = if ($m.commit) { ([string]$m.commit).Substring(0, 7) } else { 'n/a' }
  return @{ Status = 'DIVERGED'; Detail = "prod commit $prodCommit is not in local history" }
}

$results = New-Object System.Collections.Generic.List[object]

foreach ($p in $map) {
  $dir = Join-Path $root $p.Name
  if (-not (Test-Path $dir)) {
    $results.Add([pscustomobject]@{ Project = $p.Name; Prod = 'n/a'; Local = 'n/a'; Status = 'NO_DIR'; Detail = 'project directory not found'; Files = @(); DeployedAt = $null })
    continue
  }
  $cfg = Read-DotEnv $dir
  $marker = Get-RemoteMarker $p.Name $p.Domain $p.MarkerRel $cfg
  $local = Get-LocalState $dir
  $cmp = Compare-WithProd $marker $local $dir

  $prodLabel = if ($marker -and $marker.commit) {
    $c = ([string]$marker.commit).Substring(0, 7)
    if ($marker.dirty) { "$c*" } else { $c }
  } else { 'n/a' }
  $localLabel = if ($local) {
    $c = ([string]$local.Head).Substring(0, 7)
    if ($local.Dirty -gt 0) { "$c*" } else { $c }
  } else { 'n/a' }

  $results.Add([pscustomobject]@{
    Project    = $p.Name
    Prod       = $prodLabel
    Local      = $localLabel
    Status     = $cmp.Status
    Detail     = $cmp.Detail
    Files      = $cmp.Files
    DeployedAt = if ($marker) { $marker.deployedAt } else { $null }
  })
}

if ($Json) {
  $results | Select-Object Project, Prod, Local, Status, Detail, DeployedAt, Files | ConvertTo-Json -Depth 5
} elseif (-not $Quiet) {
  $colors = @{
    'MATCH' = 'Green'; 'STALE' = 'Yellow'; 'DIFFERS' = 'Yellow'
    'DIVERGED' = 'Red'; 'NO_MARKER' = 'DarkGray'; 'NO_GIT' = 'DarkYellow'; 'NO_DIR' = 'Red'
  }
  Write-Host ("{0,-12} {1,-9} {2,-9} {3,-10} {4}" -f 'PROJECT', 'PROD', 'LOCAL', 'STATUS', 'DETAIL') -ForegroundColor Cyan
  foreach ($r in $results) {
    $color = $colors[$r.Status]; if (-not $color) { $color = 'White' }
    Write-Host ("{0,-12} {1,-9} {2,-9} {3,-10} {4}" -f $r.Project, $r.Prod, $r.Local, $r.Status, $r.Detail) -ForegroundColor $color
    if ($r.Status -in @('STALE', 'DIFFERS') -and $r.Files) {
      foreach ($f in ($r.Files | Select-Object -First 5)) { Write-Host ("{0,-12} {1}" -f '', "  - $f") -ForegroundColor DarkGray }
    }
  }
  $bad = @($results | Where-Object { $_.Status -ne 'MATCH' }).Count
  Write-Host ''
  if ($bad -eq 0) { Write-Host 'All projects match the local repositories.' -ForegroundColor Green }
  else { Write-Host "Projects with differences: $bad" -ForegroundColor Yellow }
}

if ($PassThru) { return $results }

$exitBad = @($results | Where-Object { $_.Status -ne 'MATCH' }).Count
if ($exitBad -gt 0) { exit 1 }
