# File Renamer

A versatile bash script for batch and single file renaming operations using pattern matching with safety features and comprehensive options.

## Features

- **Single File Renaming**: Rename individual files with pattern matching
- **Batch Processing**: Process multiple files in directories with filtering
- **Recursive Processing**: Include subdirectories in batch operations
- **Pattern Matching**: Support for glob patterns and regex with capture groups
- **Safety Features**: Dry-run mode, backup options, confirmation prompts, undo functionality
- **Flexible Operations**: Find-replace, prefix/suffix, case conversion, regex transformations
- **Progress Reporting**: Status updates for large batch operations
- **Operation Logging**: Comprehensive logging with undo capability
- **Date Processing**: Parse and reformat dates in filenames (planned)

## Installation

1. Make the script executable:
   ```bash
   chmod +x file_renamer.sh
   ```

2. Optional: Add to your PATH for system-wide access

## Usage

### Single File Renaming

Rename a single file:
```bash
./file_renamer.sh -f "old_name.txt" -n "new_name.txt"
```

### Transformation Operations

Apply transformations to single files:

**Find and Replace:**
```bash
./file_renamer.sh -f "file_name.txt" -r "_" "-"
# Result: file-name.txt
```

**Add Prefix:**
```bash
./file_renamer.sh -f "document.txt" --prefix "20241217_"
# Result: 20241217_document.txt
```

**Add Suffix:**
```bash
./file_renamer.sh -f "report.txt" --suffix "_final"
# Result: report_final.txt
```

**Case Conversion:**
```bash
./file_renamer.sh -f "file.txt" --case upper
# Result: FILE.TXT
```

**Combine Multiple Transformations:**
```bash
./file_renamer.sh -f "test_file.txt" --prefix "NEW_" -r "_" "-" --suffix "_v2"
# Result: NEW_test-file_v2.txt
```

### Batch Processing

Process multiple files in a directory:

**All files in directory:**
```bash
./file_renamer.sh -d /path/to/files --prefix "batch_"
```

**Filter by pattern:**
```bash
./file_renamer.sh -d /photos -p "*.jpg" --suffix "_processed"
```

**Recursive processing:**
```bash
./file_renamer.sh -d /documents --recursive --prefix "archived_"
```

**Batch transformations:**
```bash
./file_renamer.sh -d /files -p "*.txt" -r " " "_" --case lower
```

### Undo Operations

Revert rename operations using a log file:

**Undo from log file:**
```bash
./file_renamer.sh --undo /path/to/rename.log
```

**Combined with logging:**
```bash
./file_renamer.sh --log-file operations.log -d /files -p "*.jpg" --prefix "vacation_"
# Later, if needed:
./file_renamer.sh --undo operations.log
```

### Dry Run

Preview changes without executing:
```bash
./file_renamer.sh --dry-run -d /path/to/files -p "*.jpg" -r " " "_"
```

## Command Line Options

| Option | Description |
|--------|-------------|
| `-f, --file FILE` | Single file to rename |
| `-n, --name NEWNAME` | New name for single file operation |
| `-d, --directory DIR` | Directory to process for batch operations |
| `-p, --pattern PATTERN` | File pattern to match (glob) |
| `-r, --replace OLD NEW` | Find and replace operation |
| `--regex PATTERN REPLACEMENT` | Regex pattern matching with capture groups |
| `--transform FUNCTION` | Apply custom transformation function |
| `--template TEMPLATE` | Template-based renaming with placeholders |
| `--prefix PREFIX` | Add prefix to filenames |
| `--suffix SUFFIX` | Add suffix to filenames |
| `--case upper\|lower\|title` | Case conversion |
| `--recursive` | Process subdirectories |
| `--dry-run` | Preview changes without executing |
| `--backup` | Create backup files before renaming |
| `--interactive` | Confirm each operation |
| `--verbose` | Increase verbosity |
| `--log-file FILE` | Log operations to specified file |
| `--undo FILE` | Undo operations from specified log file |
| `--help` | Display help message |
| `--version` | Display version information |

## Examples

```bash
# Basic rename
./file_renamer.sh -f document.txt -n report.txt

# Find and replace
./file_renamer.sh -f "file_name.txt" -r "_" "-"

# Regex with capture groups (rename IMG_001.jpg to photo_001.jpg)
./file_renamer.sh -f "IMG_001.jpg" --regex "IMG_(.*)" "photo_\1"

# Batch regex transformation
./file_renamer.sh -d /photos -p "IMG_*.jpg" --regex "IMG_(.*)" "vacation_\1"

# Date format conversion (simple YYYY-MM-DD to YYMMDD)
./file_renamer.sh -f "2023-01-15_report.pdf" --regex "([0-9]{4})-([0-9]{2})-([0-9]{2})" "\3\2\1"

# Parse dates from filenames (Month name to YYMMDD)
./file_renamer.sh -f "January, 15 2023 - lesson.mp3" --transform parsedate
# Result: 230115 - lesson.mp3

./file_renamer.sh -d /audio -p "*, * *" --transform parsedate

# Combined operations with logging
./file_renamer.sh --log-file operations.log -d /files -p "*.txt" --prefix "2024_" -r " " "_"

# Custom transformation functions
./file_renamer.sh -d /files -p "*.txt" --transform date
./file_renamer.sh -d /files -p "*.jpg" --transform counter
./file_renamer.sh -d /files -p "*.png" --transform random

# Template-based renaming
./file_renamer.sh -d /files -p "*.jpg" --template "{date}_{counter}_{basename}"
./file_renamer.sh -d /files -p "*.txt" --template "{dirname}_{random}_{extension}"

# Undo operations
./file_renamer.sh --undo operations.log

# Dry run to preview
./file_renamer.sh --dry-run -f document.txt -n report.txt

# Verbose output
./file_renamer.sh --verbose -f document.txt -n report.txt
```

## Custom Transformation Functions

The `--transform` option supports built-in functions that append information before the file extension:

| Function | Description | Example |
|----------|-------------|---------|
| `date` | Append current date (YYYYMMDD) | `file.txt` → `file_20251217.txt` |
| `datetime` | Append date and time | `file.txt` → `file_20251217_143022.txt` |
| `counter` | Append sequential number | `file.txt` → `file_001.txt` |
| `random` | Append random 4-char string | `file.txt` → `file_a8X2.txt` |
| `hash` | Append file MD5 hash (8 chars) | `file.txt` → `file_a1b2c3d4.txt` |
| `parsedate` | Parse date from filename to YYMMDD | `January 15, 2023 file.mp3` → `230115 file.mp3` |

**Note:** For case conversion, use the `--case upper\|lower\|title` option instead.

## Template-Based Renaming

The `--template` option allows complex renaming using placeholders:

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `{basename}` | Filename without extension | `document` |
| `{extension}` | File extension | `txt` |
| `{dirname}` | Parent directory name | `documents` |
| `{date}` | Current date (YYYYMMDD) | `20251217` |
| `{datetime}` | Date and time | `20251217_143022` |
| `{counter}` | Sequential counter | `001`, `002`, etc. |
| `{random}` | Random 4-character string | `a8X2` |
| `{hash}` | File MD5 hash (first 8 chars) | `a1b2c3d4` |

**Examples:**
- `{date}_{counter}_{basename}.{extension}` → `20251217_001_document.txt`
- `{dirname}_{random}_{basename}` → `documents_a8X2_document`

## Requirements

- Bash 3.2+
- Standard Unix utilities: `mv`, `cp`, `find`, `sed`

## Current Status

**Phase 1 (Core Infrastructure)**: ✅ Complete
- Basic script structure with argument parsing
- Dry-run functionality
- File validation and error handling
- Logging framework

**Phase 2 (Single File Operations)**: ✅ Complete
- Find-and-replace functionality
- Prefix and suffix operations
- Case conversion (upper/lower/title)
- Combined transformations support

**Phase 3 (Batch Processing)**: ✅ Complete
- Directory traversal with file filtering
- Recursive processing options
- Progress indicators for batch operations
- Pattern-based file selection

**Phase 4 (Advanced Features)**: ✅ Complete
- ✅ Regex pattern matching with capture groups
- ✅ Undo/rollback functionality with operation logging
- ✅ Custom transformation functions
- ✅ Template-based renaming
- ⏳ Date processing and parsing
- ⏳ GUI interface

## Development

This script is developed according to the plan in `PLAN.md`. See the plan for detailed development roadmap and implementation phases.

## License

See repository LICENSE file.

## Author

ABE