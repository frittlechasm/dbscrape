# dbscrape
- A simple script which parses through a database and gets the necessary database schema along with per table schema
- Currently **_only supports Postgres Databases_**
- Files are generated in the `/tmp` directory.

## Usage

`dbscrape` requires the PostgreSQL `psql` client and exactly four arguments:

```bash
./dbscrape <username> <password> <host> <database>
```
