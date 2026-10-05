# python-template

A [Copier](https://copier.readthedocs.io/) template for Python projects managed with Poetry, set up for ruff, mypy,
pytest and PyCharm.

Two project types:

- **app:** not a package (`package-mode = false`), one Python version.
- **lib:** a typed PyPI package (`py.typed`), tested with nox on every supported Python version from the chosen minimum
  up to the newest the template knows. Ships GitHub Actions for pull-request checks and PyPI publishing (trusted
  publishing on a GitHub release), dependabot, and optional Codecov uploads.

## Prerequisites

- [Copier](https://copier.readthedocs.io/) 9.6.0 or newer.
- [Poetry](https://python-poetry.org/) 2.x.
- The project's Python version available on `PATH` as `python3.X`. Poetry does not download Python.

## Generate a project

```bash
copier copy --trust gh:zerlok/python-template <dest>
```

Copier asks for the GitHub repository link first and derives the default project name from it.

To skip typing the author on every project, set the defaults once in Copier's
[user settings file](https://copier.readthedocs.io/en/stable/settings/) (`~/.config/copier/settings.yml` on Linux),
for example by creating it from the global git config:

```bash
mkdir -p ~/.config/copier
printf 'defaults:\n  author_name: %s\n  author_email: %s\n' \
  "$(git config --global user.name)" "$(git config --global user.email)" > ~/.config/copier/settings.yml
```

`--trust` lets Copier run the template's tasks: `git init` (first copy only), `poetry env use 3.X` and
`poetry install`. The venv is created at `<dest>/.venv`, where PyCharm detects it.

Run Copier outside an activated virtualenv (including `poetry run copier`). Poetry in the generated project otherwise
installs into that active environment instead of creating `.venv`.

## Update a project

In the generated project, with a clean git tree:

```bash
copier update --trust --defaults   # keep the previous answers; drop --defaults to revise them
git diff                           # review the merged template changes
```

`README.md` is never overwritten by updates.

## Versioning

Release the template with git tags such as `v1.0.0`. Generated projects record the tag they were rendered from in
`.copier-answers.yml` as `_commit`, and `copier update` uses it to compute the diff. Never delete or rewrite a
released tag.

To start testing libs on a new Python release, add it to `known_python_versions` in `copier.yml`; updated libs pick it
up in nox, CI and classifiers.

## Migrations

For structural changes between versions (renamed directories and the like), add `_migrations` to `copier.yml`. See
[Copier migrations](https://copier.readthedocs.io/en/stable/configuring/#migrations).

## PyCharm

Unless `idea_enabled` is off, the template ships the shareable `.idea` files: the module (`<project_name>.iml`),
`modules.xml`, run configurations (ruff format, ruff check, mypy, pytest debug, pytest all) and file watchers. It never
ships an interpreter path: run configurations use the module's interpreter, the module inherits the project interpreter,
and PyCharm sets that to `.venv` on first open.

The file watchers (ruff format and ruff fix on save) require the File Watchers plugin.

## Developing the template

```bash
poetry install              # installs Copier into this repo's .venv
scripts/smoke-test.sh       # generates an app and a lib from the working tree and checks them
```

The smoke test uses the template's default Python versions (the newest for an app, the oldest for a lib). On a machine
that lacks them, override with `PYTHON_VERSION=3.X scripts/smoke-test.sh`.
