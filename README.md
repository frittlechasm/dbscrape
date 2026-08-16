# dbscrape
- A simple script which parses through a database and gets the necessary database schema along with per table schema
- Currently **_only supports Postgres Databases_**
- Files are generated in the `/tmp` directory.

## Usage

`dbscrape` requires the PostgreSQL `psql` client and exactly four arguments:

```bash
./dbscrape <username> <password> <host> <database>
```

The script passes the password to `psql` through `PGPASSWORD`, so URI metacharacters in credentials do not require percent-encoding. The password remains visible in the `dbscrape` command's arguments and may be saved in shell history.

All user-defined schemas are inspected. Tables in `public` retain their table-name directory, while tables in other schemas use `<schema>.<table>`. Schema and table names containing characters other than letters, numbers, and underscores are rejected because they cannot be mapped safely to the fixed output directory.

Column names are read from `information_schema.columns` in ordinal order instead of being parsed from the human-readable `\d` output.
