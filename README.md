# dbscrape

`dbscrape` writes a local snapshot of PostgreSQL table and column metadata under `/tmp/tables`.

## Requirements

- Bash 3.2 or newer
- The PostgreSQL `psql` client
- PostgreSQL credentials with access to the schemas being inspected

## Usage

Pass exactly four positional arguments:

```bash
./dbscrape <username> <password> <host> <database>
```

The host may include a port, such as `localhost:5433`. Bracketed IPv6 hosts with an optional port are also supported:

```bash
./dbscrape app_user secret '[::1]:5433' app_database
```

## Output

A successful scrape produces the following layout:

```text
/tmp/tables/
├── tables.txt
├── users/
│   ├── columns.txt
│   └── full-details.txt
└── audit.Events/
    ├── columns.txt
    └── full-details.txt
```

- `tables.txt` lists schema-qualified PostgreSQL relation names.
- `columns.txt` lists column names in ordinal order.
- `full-details.txt` contains the human-readable output from `psql`'s `\d` command.
- Tables in `public` use their table name as the directory name.
- Tables in other schemas use `<schema>.<table>`.

All schemas except PostgreSQL's catalog and information schema are inspected. Schema and table names containing characters other than letters, numbers, and underscores are rejected because they cannot be mapped safely to the fixed output directory.

## Run behavior

Tables are scraped in batches of up to five. The command exits with a non-zero status and does not print the completion message if table discovery or any table scrape fails.

Each run is staged in a private temporary directory. A successful run replaces the previous `/tmp/tables` snapshot. A failed scrape leaves the previous snapshot unchanged.

The command refuses to replace `/tmp/tables` when it is a symbolic link or is not owned by the current user.

## Password handling

The script passes the password to `psql` through `PGPASSWORD`, so URI metacharacters in credentials do not require percent-encoding. The password remains visible in the `dbscrape` command's arguments and may be saved in shell history.

## Tests

Run the local behavior suite:

```bash
./tests/run.sh
```

The suite uses a fake `psql` command and preserves any existing user-owned `/tmp/tables` directory.
