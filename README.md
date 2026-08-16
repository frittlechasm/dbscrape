# dbscrape
- A simple script which parses through a database and gets the necessary database schema along with per table schema
- Currently **_only supports Postgres Databases_**
- Files are generated in the `/tmp` directory.

## Usage

`dbscrape` requires the PostgreSQL `psql` client and exactly four arguments:

```bash
./dbscrape <username> <password> <host> <database>
```

The host may include a port, such as `localhost:5433`. Bracketed IPv6 hosts with an optional port are also supported.

The script passes the password to `psql` through `PGPASSWORD`, so URI metacharacters in credentials do not require percent-encoding. The password remains visible in the `dbscrape` command's arguments and may be saved in shell history.

All user-defined schemas are inspected. Tables in `public` retain their table-name directory, while tables in other schemas use `<schema>.<table>`. Schema and table names containing characters other than letters, numbers, and underscores are rejected because they cannot be mapped safely to the fixed output directory.

Column names are read from `information_schema.columns` in ordinal order instead of being parsed from the human-readable `\d` output.

Tables are scraped in batches of up to five. The command exits with a non-zero status and does not print the completion message if table discovery or any table scrape fails.

Each run is staged in a private temporary directory. A successful run replaces the previous `/tmp/tables` snapshot, while a failed scrape leaves the previous snapshot unchanged. The command refuses to replace `/tmp/tables` when it is a symbolic link or is not owned by the current user.

## Tests

Run the local behavior suite:

```bash
./tests/run.sh
```

The suite uses a fake `psql` command and preserves any existing user-owned `/tmp/tables` directory.
