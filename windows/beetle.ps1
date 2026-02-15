function Show-Banner {
    . "$PSScriptRoot\lib\banner.ps1"
}

function Show-Help {
    . "$PSScriptRoot\lib\help.ps1"
}

function Show-Version {
    Write-Host "Beetle Framework v1.0.0" -ForegroundColor Green
}

if ($args.Count -eq 0) {
    Show-Banner
    exit
}

switch ($args[0]) {
    "--help" { Show-Help }
    "-h"     { Show-Help }
    "help"   { Show-Help }

    "banner" { Show-Banner }

    "version" { Show-Version }
    "-v"      { Show-Version }

    default {
        Write-Host "Unknown command: $($args[0])" -ForegroundColor Red
        Write-Host "Try: beetle --help"
    }
}
