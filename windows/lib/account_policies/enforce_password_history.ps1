# Audit Only – Enforce Password History
# CIS Recommendation: >= 24

$Expected = 24
$current = $null

$output = net accounts 2>$null

foreach ($line in $output) {
    if ($line -match "Length of password history maintained:\s*(\d+)") {
        $current = [int]$matches[1]
        break
    }
}

if ($null -eq $current) {
    Write-Host "[ERROR] Unable to read password history value." -ForegroundColor Red
    Write-Host "Raw output:"
    $output
    return
}

Write-Host "Control : Enforce password history" -ForegroundColor Cyan
Write-Host "Current : $current"
Write-Host "Expected: >= $Expected"

if ($current -ge $Expected) {
    Write-Host "[PASS] System is compliant" -ForegroundColor Green
}
else {
    Write-Host "[FAIL] System is NOT compliant" -ForegroundColor Red
}
