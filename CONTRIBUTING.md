# Contributing

Please open an issue before making a substantial behavior or persistence change.
Keep multiplayer state authoritative on the server, preserve vanilla item and UI
behavior, and include tests for every changed logic path.

Before submitting a pull request, run:

```bash
npm ci --ignore-scripts
npm test
```

Do not commit credentials, server addresses, private logs, local Workshop
publisher paths, generated caches, or third-party artwork.
