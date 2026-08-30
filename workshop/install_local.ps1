Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-TreeHashes([string]$Root) {
    $prefix = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\') + '\'
    $map = @{}
    Get-ChildItem -LiteralPath $Root -File -Recurse | ForEach-Object {
        $relative = $_.FullName.Substring($prefix.Length).Replace('\', '/')
        $map[$relative] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }
    return $map
}

function Assert-TreeEqual([string]$ExpectedRoot, [string]$ActualRoot) {
    $expected = Get-TreeHashes $ExpectedRoot
    $actual = Get-TreeHashes $ActualRoot
    if ($expected.Count -ne $actual.Count) {
        throw "文件数不一致：源=$($expected.Count)，目标=$($actual.Count)"
    }
    foreach ($path in $expected.Keys) {
        if (-not $actual.ContainsKey($path) -or $actual[$path] -ne $expected[$path]) {
            throw "SHA-256 读回验证失败：$path"
        }
    }
}

$sourceMod = Join-Path $PSScriptRoot 'Contents\mods\LegacyJournal'
$modsRoot = Join-Path $env:USERPROFILE 'Zomboid\mods'
$targetRoot = Join-Path $modsRoot 'LegacyJournal'
$backupRoot = Join-Path $modsRoot '.backups'
$stagingRoot = Join-Path $modsRoot '.staging'
$modInfo = Join-Path $sourceMod '42.20\mod.info'

if (-not (Test-Path -LiteralPath $modInfo)) {
    throw '没有找到 Contents\mods\LegacyJournal\42.20\mod.info。请在解压后的 ZIP 根目录运行此脚本。'
}

New-Item -ItemType Directory -Force -Path $modsRoot, $backupRoot, $stagingRoot | Out-Null
$nonce = [guid]::NewGuid().ToString('N')
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
$stage = Join-Path $stagingRoot "LegacyJournal_${stamp}_${nonce}"
$stagedMod = Join-Path $stage 'LegacyJournal'
$backup = $null
$deployed = $false

try {
    New-Item -ItemType Directory -Force -Path $stage | Out-Null
    Copy-Item -LiteralPath $sourceMod -Destination $stagedMod -Recurse -Force
    Assert-TreeEqual $sourceMod $stagedMod
    if (Test-Path -LiteralPath $targetRoot) {
        $backup = Join-Path $backupRoot "LegacyJournal_${stamp}_${nonce}"
        Move-Item -LiteralPath $targetRoot -Destination $backup -ErrorAction Stop
    }
    Move-Item -LiteralPath $stagedMod -Destination $targetRoot -ErrorAction Stop
    $deployed = $true
    Assert-TreeEqual $sourceMod $targetRoot
}
catch {
    $installError = $_
    $rollbackError = $null
    try {
        if ($deployed -and (Test-Path -LiteralPath $targetRoot)) {
            Move-Item -LiteralPath $targetRoot -Destination (Join-Path $stage 'failed-deploy') -ErrorAction Stop
        }
        if ($backup -and (Test-Path -LiteralPath $backup) -and -not (Test-Path -LiteralPath $targetRoot)) {
            Move-Item -LiteralPath $backup -Destination $targetRoot -ErrorAction Stop
        }
    }
    catch { $rollbackError = $_ }
    if ($rollbackError) {
        throw "安装失败：$installError；回滚也失败：$rollbackError。保留暂存目录：$stage"
    }
    throw "安装失败，已回滚：$installError。保留暂存目录：$stage"
}

if (Test-Path -LiteralPath $stage) {
    Remove-Item -LiteralPath $stage -Force -ErrorAction SilentlyContinue
}
Write-Host ''
Write-Host 'Legacy Journal 安装完成，并已通过 SHA-256 读回验证。' -ForegroundColor Green
Write-Host "位置：$targetRoot"
if ($backup) { Write-Host "旧版本备份：$backup" -ForegroundColor Yellow }
