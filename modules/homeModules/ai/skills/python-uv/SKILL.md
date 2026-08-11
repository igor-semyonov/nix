---
name: python-uv
description: Manage Python projects, environments, and dependencies with uv. Use for creating Python projects, adding dependencies, running code, and locking environments.
---

# Python with uv

`uv` is the fast, all-in-one Python project and environment manager. Prefer it over pip/venv/poetry.

## Projects

```bash
uv init myproject          # new project with pyproject.toml
cd myproject
uv add numpy scipy         # add + lock dependencies
uv add --dev pytest ruff   # dev dependencies
uv remove numpy            # remove
```

## Running

```bash
uv run python script.py    # runs in the project env, syncing first
uv run pytest              # run tools without activating a venv
uv sync                    # materialize .venv from uv.lock
```

`uv run` auto-creates and updates `.venv` from `uv.lock`, so you rarely activate manually.

## Python versions

```bash
uv python install 3.12
uv python pin 3.12         # writes .python-version
```

## One-off tools

```bash
uvx ruff check .           # run a tool in an ephemeral env (like pipx)
```

## Notes

- Commit `pyproject.toml` and `uv.lock`; do not commit `.venv`.
- Lint/format with `ruff` (`uv run ruff check .` / `uv run ruff format .`).
- On Nix, `uv` itself comes from nixpkgs; let it manage the Python env inside the project.
