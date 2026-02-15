$cliPath = "$PSScriptRoot"

$path = [Environment]::GetEnvironmentVariable("Path", "User")

if ($path -notlike "*$cliPath*") {
    [Environment]::SetEnvironmentVariable(
        "Path",
        "$path;$cliPath",
        "User"
    )
    Write-Host "Beetle added to PATH. Restart terminal." -ForegroundColor Green
} else {
    Write-Host "Beetle is already in PATH." -ForegroundColor Yellow
}
