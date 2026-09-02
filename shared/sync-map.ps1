<#
.SYNOPSIS
   Единая карта синхронизации канонических файлов экосистемы.
.DESCRIPTION
   Используется sync.ps1 (копирование) и check-sync.ps1 (проверка хэшей),
   чтобы список источников/приёмников не расходился между скриптами.
#>

$script:_shared = $PSScriptRoot
$script:_root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Get-SyncMap {
    @{
        (Join-Path $_shared 'php\auth-client\AuthClient.php') = @(
            (Join-Path $_root 'contest-web\includes\AuthClient.php'),
            (Join-Path $_root 'python-web\sandbox\AuthClient.php'),
            (Join-Path $_root 'ai-web\sandbox\AuthClient.php'),
            (Join-Path $_root 'j-web\src\AuthClient.php')
        )
        (Join-Path $_shared 'php\progress-reporter\ProgressReporter.php') = @(
            (Join-Path $_root 'python-web\sandbox\ProgressReporter.php'),
            (Join-Path $_root 'ai-web\sandbox\ProgressReporter.php')
        )
        (Join-Path $_shared 'css\design-tokens.css') = @(
            (Join-Path $_root 'na-web\css\design-tokens.css'),
            (Join-Path $_root 'oge-web\assets\design-tokens.css'),
            (Join-Path $_root 'office-web\assets\css\design-tokens.css'),
            (Join-Path $_root 'inf-web\css\design-tokens.css'),
            (Join-Path $_root 'vpr7\assets\design-tokens.css')
        )
        (Join-Path $_shared 'js\progress-client.js') = @(
            (Join-Path $_root 'oge-web\js\progress-client.js'),
            (Join-Path $_root 'office-web\assets\js\progress-client.js'),
            (Join-Path $_root 'inf-web\js\progress-client.js'),
            (Join-Path $_root 'vpr7\js\progress-client.js'),
            (Join-Path $_root 'na-web\js\progress-client.js')
        )
        # tracking-client.js каноничен в auth-web, а не в na-web/shared
        (Join-Path $_root 'auth-web\assets\js\tracking-client.js') = @(
            (Join-Path $_root 'oge-web\js\tracking-client.js'),
            (Join-Path $_root 'office-web\assets\js\tracking-client.js'),
            (Join-Path $_root 'inf-web\js\tracking-client.js'),
            (Join-Path $_root 'vpr7\js\tracking-client.js'),
            (Join-Path $_root 'na-web\js\tracking-client.js'),
            (Join-Path $_root 'j-web\assets-src\public\tracking-client.js')
        )
        (Join-Path $_shared 'js\progress-sync\oge.js') = @(
            (Join-Path $_root 'oge-web\js\progress-sync.js')
        )
        (Join-Path $_shared 'js\progress-sync\office.js') = @(
            (Join-Path $_root 'office-web\assets\js\progress-sync.js')
        )
        (Join-Path $_shared 'js\progress-sync\inf.js') = @(
            (Join-Path $_root 'inf-web\js\progress-sync.js')
        )
        (Join-Path $_shared 'js\progress-sync\vpr.js') = @(
            (Join-Path $_root 'vpr7\js\progress-sync.js')
        )
        (Join-Path $_shared 'pwa\offline.html') = @(
            (Join-Path $_root 'oge-web\offline.html'),
            (Join-Path $_root 'office-web\offline.html'),
            (Join-Path $_root 'vpr7\offline.html'),
            (Join-Path $_root 'ai-web\offline.html')
        )
        (Join-Path $_shared 'pwa\404.html') = @(
            (Join-Path $_root 'oge-web\404.html'),
            (Join-Path $_root 'office-web\404.html'),
            (Join-Path $_root 'vpr7\404.html'),
            (Join-Path $_root 'ai-web\404.html')
        )
    }
}
