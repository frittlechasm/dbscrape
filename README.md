# dbscrape

`dbscrape` writes a local snapshot of PostgreSQL table and column metadata under `/tmp/tables`.

## Requirements

- Bash 3.2 or newer
- The PostgreSQL `psql` client
- `curl` when using the installer
- PostgreSQL credentials with access to the schemas being inspected

## Installation

Download and run the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/frittlechasm/dbscrape/main/install.sh | bash
```

The installer downloads the `dbscrape` asset from the latest GitHub release. It does not pin a version, so running the same command again upgrades an existing installation to the newest release.

By default, it installs `dbscrape` at `$HOME/.local/bin/dbscrape`. `$HOME/.local/bin` must already be on `PATH`; the installer exits with instructions when the default directory is not available on `PATH`.

To use another absolute directory:

```bash
curl -fsSL https://raw.githubusercontent.com/frittlechasm/dbscrape/main/install.sh \
  | bash -s -- --bin-dir "$HOME/bin"
```

An explicit directory is always honored. The installer warns when that directory is not on the current `PATH`. It does not invoke `sudo` or modify shell configuration.

Each GitHub release must include an asset named exactly `dbscrape` for release installation to work. Until the first such release is published, install from a local checkout:

```bash
./install.sh --source ./dbscrape --bin-dir "$HOME/.local/bin"
```

The installer checks its dependencies, downloads into a temporary file, validates the script with `bash -n`, installs it with executable permissions, and verifies the installed file.

### Upgrading

Rerun the installation command. The stable download URL follows GitHub's latest release and replaces the existing executable only after the downloaded script passes validation.

### Uninstalling

Remove the installed executable. For the default installation:

```bash
rm "$HOME/.local/bin/dbscrape"
```

## Usage

Pass exactly three positional arguments:

```bash
./dbscrape <username> <host> <database>
```

When run from an interactive terminal, `dbscrape` prompts for the password without echoing it.

The host may include a port, such as `localhost:5433`. Bracketed IPv6 hosts with an optional port are also supported:

```bash
./dbscrape app_user '[::1]:5433' app_database
```

## Output

A successful scrape produces the following layout:

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

- `tables.txt` lists schema-qualified PostgreSQL relation names.
- `table-paths.jsonl` maps each normalized directory to its exact schema and table names.
- `columns.txt` lists column names in ordinal order.
- `full-details.txt` contains the human-readable output from `psql`'s `\d` command.
- Tables in `public` use their table name as the directory name.
- Tables in other schemas use `<schema>.<table>`.

Only ordinary, non-partition tables are included. Views, materialized views, foreign tables, partitioned tables, and their partitions are deferred for future support.

All user schemas are inspected. PostgreSQL-managed schemas and `information_schema` are excluded.

Every legal PostgreSQL identifier is converted into a portable lowercase folder name:

- Spaces, path separators, punctuation, and unsupported characters become hyphens.
- Common Latin accents are folded to ASCII, so `café` becomes `cafe`.
- Percent signs are retained, so `100% done` becomes `100%-done`.
- Repeated or leading and trailing hyphens are collapsed or removed.
- A name that contains no usable characters falls back to `table` or `schema`.

Normalization can map different identifiers to the same name. When that happens, every conflicting directory receives a stable eight-character suffix. For example, `Order Items` and `Order-Items` become `order-items--03000deb` and `order-items--62b48187` in the same schema.

## Run behavior

Tables are scraped in batches of up to five. The command exits with a non-zero status and does not print the completion message if table discovery or any table scrape fails.

Each run is staged in a private temporary directory. A successful run replaces the previous `/tmp/tables` snapshot. A failed scrape leaves the previous snapshot unchanged.

The command refuses to replace `/tmp/tables` when it is a symbolic link or is not owned by the current user.

## Password handling

Passwords are never accepted as command-line arguments. This keeps them out of shell history and process argument listings.

For automated or non-interactive use, inject `PGPASSWORD` through the CI or runtime secret store:

```bash
PGPASSWORD="$DB_PASSWORD" ./dbscrape app_user localhost app_database
```

The command exits before connecting when standard input is not an interactive terminal and `PGPASSWORD` is unset.

## Tests

Run the local behavior suite:

```bash
./tests/run.sh
```

The suite uses a fake `psql` command and preserves any existing user-owned `/tmp/tables` directory.
