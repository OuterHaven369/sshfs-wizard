$errors = $null
$null = [System.Management.Automation.PSParser]::Tokenize((Get-Content ./install.ps1 -Raw), [ref]$errors)

if ($errors) {
    Write-Host "Syntax Errors Found:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host $_ }
    exit 1
} else {
    Write-Host "PowerShell syntax validation: PASSED" -ForegroundColor Green
    exit 0
}
