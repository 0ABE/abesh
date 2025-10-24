# ABE's Shell Scripts (abesh)

A collection of custom bash shell scripts for various automation and utility tasks.

## Overview

This repository contains a curated collection of bash shell scripts designed to simplify common tasks and automate workflows. Each script is self-contained and follows best practices for shell scripting, including proper error handling, documentation, and safety features.

## Scripts

### Media Renamer
**Location**: `media_renamer/`

A professional bash script for renaming movie and TV show files using industry-standard naming formats compatible with Plex, Netflix, Apple TV, and other media platforms.

- **Features**: Automatic title extraction, multiple naming patterns, dry-run mode
- **Use Case**: Organizing media files for media servers and streaming platforms
- **Documentation**: See `media_renamer/README.md` for detailed usage instructions

## Getting Started

1. Clone this repository:
   ```bash
   git clone https://github.com/0ABE/abesh.git
   cd abesh
   ```

2. Make scripts executable:
   ```bash
   chmod +x "media_renamer/media_renamer.sh"
   ```

3. Run any script with the `--help` flag to see usage instructions:
   ```bash
   ./media_renamer/media_renamer.sh --help
   ```

## Script Development Guidelines

All scripts in this repository follow these guidelines:

- **Safety First**: Include dry-run modes and confirmation prompts where appropriate
- **Documentation**: Each script includes usage instructions and examples
- **Error Handling**: Proper error checking and meaningful error messages
- **Portability**: Compatible with common Unix/Linux environments and macOS
- **Best Practices**: Follow shell scripting best practices and conventions

## Contributing

When adding new scripts to this repository:

1. Create a dedicated folder for complex scripts with their own documentation
2. Include a README.md for scripts that require detailed explanation
3. Add appropriate help text accessible via `--help` flag
4. Test on multiple platforms when possible
5. Include examples of common use cases

## License

See the [LICENSE](LICENSE) file for license information.

## Author

Created and maintained by 0ABE.