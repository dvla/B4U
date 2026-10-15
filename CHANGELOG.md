## [1.1.0]

- Add a top-level `conditions:` section. Linters reference one with `run_if: <id>` and are skipped when it exits non-zero. Each condition runs once, before any linter
- Add a `--quiet` flag to prevent large stack traces being output to console
- Cleaner terminal output

## [1.0.1] - 2025-08-22

- Remove 3.0 ruby from build

## [1.0.0] - 2025-08-22

- Initial release
