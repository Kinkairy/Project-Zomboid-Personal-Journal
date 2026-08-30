param(
    [string]$ProjectRoot = $PSScriptRoot,
    [switch]$AllowOnlineNpx
)

$ErrorActionPreference = 'Stop'

$validator = Join-Path $ProjectRoot 'validate_workshop.ps1'
$luaRoot = Join-Path $ProjectRoot 'workshop\Contents\mods\LegacyJournal\42.20\media\lua'
$tests = @(
    'tests\skillbook_policy_test.lua',
    'tests\instant_skillbook_sync_test.lua',
    'tests\media_policy_test.lua',
    'tests\server_protocol_test.lua',
    'tests\client_action_protocol_test.lua',
    'tests\dynamic_page_count_test.lua',
    'tests\journal_continuation_test.lua',
    'tests\client_presentation_test.lua',
    'tests\inventory_item_type_guard_test.lua',
    'tests\context_menu_stack_test.lua',
    'tests\write_delta_no_change_test.lua',
    'tests\restore_paths_test.lua'
)

& $validator -ProjectRoot $ProjectRoot

$luaFiles = Get-ChildItem -LiteralPath $luaRoot -Recurse -Filter '*.lua'
foreach ($file in $luaFiles) {
    if ($AllowOnlineNpx) {
        & npx.cmd --yes 'luaparse@0.3.0' $file.FullName *> $null
    }
    else {
        & npx.cmd --yes --offline 'luaparse@0.3.0' $file.FullName *> $null
    }
    if ($LASTEXITCODE -ne 0) {
        $hint = if ($AllowOnlineNpx) { '' } else { ' Re-run with -AllowOnlineNpx only if the pinned package is not cached.' }
        throw "Lua syntax failed: $($file.FullName).$hint"
    }
}
Write-Host "Lua syntax validation: PASS ($($luaFiles.Count) files)"

Push-Location $ProjectRoot
try {
    foreach ($test in $tests) {
        $testPath = Join-Path $ProjectRoot $test
        if ($AllowOnlineNpx) {
            $testOutput = & npx.cmd --yes '--package=fengari-node-cli@0.1.0' fengari $testPath 2>&1
        }
        else {
            $testOutput = & npx.cmd --yes --offline '--package=fengari-node-cli@0.1.0' fengari $testPath 2>&1
        }
        $testOutput | Write-Host
        if ($LASTEXITCODE -ne 0 -or $testOutput -match '(?im)(stack traceback|\berror:|not found)') {
            throw "Unit test failed: $test"
        }
    }
}
finally {
    Pop-Location
}

Write-Host 'Legacy Journal complete offline test suite: PASS'
