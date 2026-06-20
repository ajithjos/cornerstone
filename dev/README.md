# Developer Layer

This directory holds repo-local developer ergonomics. Product runtime and deployment inputs stay in their product-owned directories.

- Source shell helpers with `source dev/sourceme`.
- Use `make context` for the repo command map and live status. `make help` aliases `make context`.
- Use `make doctor` for local prerequisite and deployment-identity checks.
- Use `make clean`, `make clean-python`, `make clean-all`, or `make clean-deps` for cleanup.
- Put optional machine-local shell overrides in ignored `dev/env/local.env`.
