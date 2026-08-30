# Testing

Run the complete Linux/NUC gate from the repository root:

```bash
npm ci --ignore-scripts
npm test
```

Windows users can run `validate_workshop.ps1` for the static contract and
`run_offline_tests.ps1` for the behavior suite after installing Node.js.

The automated gate verifies:

- exact 1.01 and 1.02 recovery archives and manifests;
- exact alignment between the 1.02 accepted baseline and every current runtime
  or metadata file; the retired non-runtime `common/readme.txt` is preserved
  only in the immutable release artifact;
- required Workshop metadata, translations, and server-authoritative protocol;
- Lua syntax for all six payload files;
- twelve deterministic behavior tests.

In-game acceptance should use a disposable test save. Verify both supported
vanilla diaries, interrupted continuation, same-account recovery, non-author
read-only behavior, stacked inventory entries, reconnect persistence, and each
sandbox category toggle. Back up any live save before changing its Mod list.
