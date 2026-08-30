#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd -- "$project_root"

python3 tools/validate_workshop.py --project-root "$project_root"

mapfile -t lua_files < <(find workshop/Contents/mods/LegacyJournal/42.20/media/lua -type f -name '*.lua' -print | LC_ALL=C sort)
if [[ "${#lua_files[@]}" -ne 6 ]]; then
    echo "ERROR: expected 6 payload Lua files, found ${#lua_files[@]}" >&2
    exit 1
fi
for lua_file in "${lua_files[@]}"; do
    npx --offline --yes --package=luaparse@0.3.0 luaparse -q -f "$lua_file" </dev/null
done
echo "Legacy Journal Lua parse gate: PASS (${#lua_files[@]} files)"

tests=(
    tests/skillbook_policy_test.lua
    tests/instant_skillbook_sync_test.lua
    tests/media_policy_test.lua
    tests/server_protocol_test.lua
    tests/client_action_protocol_test.lua
    tests/journal_continuation_test.lua
    tests/client_presentation_test.lua
    tests/inventory_item_type_guard_test.lua
    tests/context_menu_stack_test.lua
    tests/write_delta_no_change_test.lua
    tests/restore_paths_test.lua
    tests/dynamic_page_count_test.lua
)
for test_file in "${tests[@]}"; do
    if ! test_output="$(npx --offline --yes --package=fengari-node-cli@0.1.0 \
        fengari "$test_file" </dev/null 2>&1)"; then
        printf '%s\n' "$test_output" >&2
        echo "ERROR: behavior test process failed: $test_file" >&2
        exit 1
    fi
    printf '%s\n' "$test_output"
    if grep -Eiq 'stack traceback|(^|[^[:alpha:]])error:|not found' <<<"$test_output"; then
        echo "ERROR: behavior test reported a Lua failure: $test_file" >&2
        exit 1
    fi
done
echo "Legacy Journal behavior gate: PASS (${#tests[@]} tests)"
