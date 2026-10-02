# B4U

B4U is a configurable multithreaded task runner designed to integrate into any git project. It allows you to implement your own quality checks before git actions (commits, pushes, etc.).

B4U is intended to be fast, configurable and (importantly) not annoying.

## Quick Start

1. **Install:** `gem install B4U`
2. **Initialize:** `B4U --init`
3. **Configure tasks** in `.B4U/commit.yml` and `.B4U/push.yml`
4. **Commit these files** to your version control
5. **Team setup:** `B4U --enable` (after cloning)

## Installation

Install the gem:

```bash
gem install B4U
```

Or add to your Gemfile:

```ruby
bundle add B4U
```

## Configuration

B4U uses YAML configuration files in the `.B4U` directory:

- `.B4U/commit.yml` - Tasks to run before commits
- `.B4U/push.yml` - Tasks to run before pushes

### Configuration Format

Each task requires a `name` and `command`. Optionally add `ignore: true` for non-blocking tasks:

```yaml
linters:
  - name: "Unit tests"
    command: "bundle exec rspec"
    ignore: true  # Won't block commit if this fails
  - name: "Rubocop"
    command: "bundle exec rubocop"
  - name: "ESLint"
    command: "npm run lint"
  - name: "Type checking"
    command: "npm run type-check"
```

**Important:** Tasks run in parallel, so only use read-only commands to avoid conflicts.

### Conditional steps (`conditions` and `run_if`)

Define conditions once at the top of the config, then point linters at them with `run_if: <id>`. Each condition that a linter uses runs once, before any linter starts, so linters sharing a condition don't re-run it.

```yaml
conditions:
  ruby-staged:
    description: "Ruby files staged"   # optional, used for logging
    command: "! git diff --staged --quiet -- '*.rb'"
  folder-staged:
    description: "source-code folder changed"
    command: "! git diff --staged --quiet -- dir-with-change"

linters:
  - name: "Rubocop"
    command: "bundle exec rubocop"
    run_if: ruby-staged
  - name: "RSpec"
    command: "bundle exec rspec"
    run_if: ruby-staged
```

Conditions follow the shell exit-code convention:

| Condition exit code | Result |
|---|---|
| `0` | Linters using it run |
| Any other code | Linters using it are skipped 🦘 (never blocks) |
| `126` / `127` (not executable / command not found) | Broken condition: B4U stops before running any linter |

A `run_if` that names a condition that doesn't exist also stops B4U before anything runs.

Note the `!`: `git diff --quiet` exits `0` when there are *no* changes, so it has to be negated to mean "run if Ruby files are staged".
```

```sh
#!/bin/sh
# exit 0 (run) if any JS files are staged
if git diff --staged --quiet -- '*.js'; then
  exit 1
fi
exit 0
```

Conditions run in parallel, so keep them read-only too.

For pre-push, B4U doesn't forward the refs git passes to the hook on stdin, so compare against the upstream instead, e.g. `! git diff --quiet @{u}...HEAD -- '*.rb'`.

## Usage

### Command Line Options

```bash
B4U --help     # Show help
B4U --version  # Show version
B4U --init     # Initialize B4U in current project
B4U --enable   # Enable B4U hooks in current project
B4U --commit   # Run pre-commit tasks
B4U --push     # Run pre-push tasks
```

## Setup

Running `B4U --init` will:
- Create a `.B4U` directory with configuration files.
- Set up git hooks for pre-commit and pre-push events.

Running `B4U --enable` will:
- Set up your local git hooks for pre-commit and pre-push events.

**Important:** Anyone who clones the project needs to run `B4U --enable` to activate the hooks locally so should add this to your setup script and/or README.md.

## Troubleshooting

**"Command not found: B4U"**
- If you're seeing this error and you already have installed B4U, it is likely caused by your IDE or version manager.

  B4U runs by calling itself from the shell scripts in the `.B4U` folder, so you can add any logic needed to point to the correct version of Ruby or even install the gem to the current version. 

## Contributing

Bug reports and pull requests are welcome on GitHub. This project is intended to be a safe, welcoming space for collaboration.

1. Fork the repository.
2. Create your feature branch (`git checkout -b feature/amazing-feature`).
3. Commit your changes (`git commit -am 'Add amazing feature'`).
4. Push to the branch (`git push origin feature/amazing-feature`).
5. Open a Pull Request.

Please make sure to update tests as appropriate and adhere to the [code of conduct](CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the B4U project's codebases, issue trackers, and discussions is expected to follow the [code of conduct](CODE_OF_CONDUCT.md).