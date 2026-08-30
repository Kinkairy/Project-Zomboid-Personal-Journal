param(
    [string]$ProjectRoot = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$validator = Join-Path $PSScriptRoot 'tools\validate_workshop.py'
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    throw 'Python is required to run the cross-platform Workshop contract gate.'
}

& $python.Source $validator --project-root $ProjectRoot
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
