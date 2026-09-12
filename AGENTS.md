# Repository Guidelines

- Keep shell code compatible with Bash 3.2 and prefer existing tools.
- Preserve the CLI and `/tmp/tables` output contract unless asked otherwise.
- Failed scrapes must leave the previous snapshot intact.
- Run `bash -n` on changed shell files, including `dbscrape`.
- Run `./tests/run.sh` when scrape behavior or its tests change.
- Verify SQL and `psql` formatting changes against a disposable PostgreSQL database.
- The fake `psql` tests use precomputed records and cannot validate SQL.
- Keep `README.md` a concise user guide; update it when behavior or usage changes.
- Keep the release asset named exactly `dbscrape`; the installer depends on it.
