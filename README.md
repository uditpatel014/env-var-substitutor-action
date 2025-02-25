# Environment Variable Substitutor GitHub Action

Replace `{env.VAR_NAME}` placeholders in files with environment variables during GitHub workflows.

## Features
- Supports custom regex patterns for placeholders
- Parallel processing for large file sets
- Fail-safe mode for missing variables
- Exclude specific files from processing

## Usage

### Basic Example
```yaml
steps:
  - uses: actions/checkout@v4
  - uses: your-username/env-substitutor-action@v1
    with:
      files: 'config/app.conf'
    env:
      API_KEY: ${{ secrets.API_KEY }}
```

### Advanced Example
```yaml
steps:
  - uses: your-username/env-substitutor-action@v1
    with:
      files: '**/*.conf'
      placeholder-regex: '\{\{([^}]+)\}\}'  # Custom {{VAR}} syntax
      exclude: 'secrets/*.conf'
      parallel: 'true'
    env:
      DB_HOST: postgres-prod
      LOG_LEVEL: debug
```

## Inputs
| Name               | Description                          | Default               |
|--------------------|--------------------------------------|-----------------------|
| `files`            | Files to process (comma-separated)   | Required              |
| `placeholder-regex`| Regex pattern for placeholders       | `\{env\.([^}]+)\}`    |
| `fail-on-missing`  | Fail on missing env vars             | `true`                |
| `exclude`          | Files to exclude                     | -                     |
| `parallel`         | Enable parallel processing           | `true`                |

## Contributing
See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License
MIT License. See [LICENSE](LICENSE).

## Future Features
- Support for JSON/YAML file validation
- Dry-run mode for testing
- Variable validation with regex