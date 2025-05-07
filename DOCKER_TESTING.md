# Docker Testing Environment

This project includes Docker configuration for running tests and development in a controlled Ruby 2.6.3 environment. This ensures that tests run consistently regardless of your local machine setup.

## Requirements

- Docker

## Available Commands

```bash
# Run all tests (default target)
make all
# or
make test

# Run a specific test file
make test-file FILE=spec/path/to/file_spec.rb

# Update dependencies
make update

# Build the Docker image with Ruby 2.6.3
make build

# Open a shell in the Docker container
make shell
```

## File Structure

- `Dockerfile` - Docker image definition with Ruby 2.6.3
- `Makefile` - Convenient commands for Docker operations

## Tips

1. The first build might take some time to download the Ruby image and install dependencies.
2. Container volumes are mounted from your local directory, so changes to your code are immediately available.
3. Gem dependencies are installed in the `vendor/bundle` directory to avoid permission issues.
4. Your local SSH keys are mounted read-only to enable operations that might require authentication.

## Troubleshooting

If you encounter any issues:

1. **Permission errors**: Docker might create files as root. Fix with `sudo chown -R $(whoami) .`
2. **Bundle errors**: Try running `make shell` and then `bundle install` to see detailed errors 