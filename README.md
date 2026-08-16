# dbscrape

`dbscrape` writes a local snapshot of PostgreSQL table and column metadata under `/tmp/tables`.

## Install

Requires Bash 3.2 or newer, `curl`, and the PostgreSQL `psql` client.

```bash
curl -fsSL https://raw.githubusercontent.com/frittlechasm/dbscrape/main/install.sh | bash
```

The installer places `dbscrape` in `$HOME/.local/bin`, which must be on `PATH`. Run the same command again to upgrade to the latest release.

To choose another directory:

```bash
curl -fsSL https://raw.githubusercontent.com/frittlechasm/dbscrape/main/install.sh \
  | bash -s -- --bin-dir "$HOME/bin"
```

To uninstall, remove the installed executable:

```bash
rm "$HOME/.local/bin/dbscrape"
```

## Usage

```bash
dbscrape <username> <host[:port]> <database>
```

`dbscrape` prompts for the password without echoing it. For automation, provide the password through the runtime's secret store:

```bash
PGPASSWORD="$DB_PASSWORD" dbscrape app_user localhost app_database
```

Bracketed IPv6 hosts are supported, for example `[::1]:5433`.

## Output

A successful scrape replaces `/tmp/tables` with a fresh snapshot:

```text
/tmp/tables/
├── tables.txt
├── table-paths.jsonl
├── users/
│   ├── columns.txt
│   └── full-details.txt
└── audit.events/
    ├── columns.txt
    └── full-details.txt
```

- `tables.txt` lists schema-qualified table names.
- `table-paths.jsonl` maps output directories to exact PostgreSQL identifiers.
- `columns.txt` lists columns in their defined order.
- `full-details.txt` contains the output of `psql`'s `\d` command.

## Supported tables and names

`dbscrape` includes ordinary, non-partition tables from user schemas. It excludes views, materialized views, foreign tables, partitioned tables, partitions, `information_schema`, and PostgreSQL-managed schemas.

Folder names are lowercase and portable:

- `Order Items` becomes `order-items`.
- `path/table` becomes `path-table`.
- `100% done` becomes `100%-done`.
- `café` becomes `cafe`.

Tables in `public` use `<table>`. Other schemas use `<schema>.<table>`. If normalized names collide, each directory receives a stable hash suffix. Use `table-paths.jsonl` to recover the exact schema and table names.

## Run behavior

- Scrapes up to five tables concurrently.
- Keeps the previous snapshot if discovery or scraping fails.
- Refuses to replace `/tmp/tables` when it is a symbolic link or is not owned by the current user.

## Development

Run the local behavior suite:

```bash
./tests/run.sh
```
