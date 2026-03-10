# Contributing

Thank you for contributing to **dbscrape**.

---

## Core Team

| Name | GitHub | Role |
|------|--------|------|
| frittlechasm | [@frittlechasm](https://github.com/frittlechasm) | Creator & maintainer |

---

## How to Contribute

Contributions are welcome. A few good ways to help:

- **Bug reports** — open an issue with the database version, OS, and the command you ran
- **Feature requests** — open an issue describing the use case and proposed behavior
- **Pull requests** — keep changes focused and open a PR against `main`

For larger changes, open an issue first so the approach can be discussed before implementation.

### Guidelines

- Preserve the current positional-argument CLI unless the change requires otherwise
- Keep the `/tmp` output behavior unless the change is intentional and documented
- Prefer simple Bash and the existing shell tools already used by `dbscrape`
- Run `bash -n dbscrape` after script changes
- Update `README.md` when behavior or usage changes

---

*To add yourself here, include a note in your pull request and I will add you after merge.*
