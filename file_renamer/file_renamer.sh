#!/bin/bash
#
# File Renamer Script - ABE's Shell Scripts (abesh)
# https://github.com/0ABE/abesh
#
# A versatile bash script for batch and single file renaming operations
# using pattern matching with safety features and comprehensive options.
#
# Version: 0.1.0
# Author: ABE
# License: See repository LICENSE file

set -o errexit  # Exit on any error
# set -o nounset  # Exit on undefined variables (disabled for bash 3.2 compatibility)
# set -o pipefail # Exit on pipe failures (not available in bash 3.2)

# =============================================================================
# CONFIGURATION AND DEFAULTS
# =============================================================================

# Script metadata
readonly SCRIPT_NAME="file_renamer"
readonly SCRIPT_VERSION="0.1.0"
readonly SCRIPT_AUTHOR="ABE"

# Default configuration
DRY_RUN=false
VERBOSE=0
BACKUP=false
INTERACTIVE=false
RECURSIVE=false
CASE_SENSITIVE=false
COUNTER=0
TEMPLATE_COUNTER=0

# Logging configuration
LOG_LEVEL=1  # 0=error, 1=warn, 2=info, 3=debug
LOG_FILE=""

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Logging functions
log_error() {
    echo "ERROR: $*" >&2
    if [[ -n "$LOG_FILE" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR: $*" >> "$LOG_FILE"
    fi
}

log_warn() {
    echo "WARNING: $*" >&2
    if [[ -n "$LOG_FILE" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') WARN: $*" >> "$LOG_FILE"
    fi
}

log_info() {
    echo "INFO: $*" >&2
    if [[ -n "$LOG_FILE" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') INFO: $*" >> "$LOG_FILE"
    fi
}

log_debug() {
    echo "DEBUG: $*" >&2
    if [[ -n "$LOG_FILE" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') DEBUG: $*" >> "$LOG_FILE"
    fi
}

# Print usage information
usage() {
    cat << EOF
${SCRIPT_NAME} v${SCRIPT_VERSION} - File Renaming Utility

USAGE:
    ${SCRIPT_NAME}.sh [OPTIONS] [FILES...]

DESCRIPTION:
    A versatile tool for renaming files with pattern matching, safety features,
    and comprehensive options for batch and single file operations.

OPTIONS:
    -f, --file FILE          Single file to rename
    -n, --name NEWNAME       New name for single file operation
    -d, --directory DIR      Directory to process for batch operations
    -p, --pattern PATTERN    File pattern to match (glob or regex)
    -r, --replace OLD NEW    Find and replace operation
    --regex PATTERN REPLACEMENT    Regex pattern matching with capture groups
    --transform FUNCTION           Apply custom transformation function
    --template TEMPLATE            Template-based renaming with placeholders
    --prefix PREFIX          Add prefix to filenames
    --suffix SUFFIX          Add suffix to filenames
    --case upper|lower|title Case conversion
    --dry-run                Preview changes without executing
    --backup                 Create backup files before renaming
    --interactive            Confirm each operation
    --recursive              Process subdirectories
    --verbose                Increase verbosity (can be used multiple times)
    --log-file FILE          Log operations to specified file
    --undo FILE              Undo operations from specified log file
    -h, --help               Display this help message
    -v, --version            Display version information

EXAMPLES:
    # Single file rename
    ${SCRIPT_NAME}.sh -f old_name.txt -n new_name.txt

    # Single file transformations
    ${SCRIPT_NAME}.sh -f file.txt --prefix "NEW_" -r " " "_" --suffix "_v1"

    # Batch replace spaces with underscores
    ${SCRIPT_NAME}.sh -d /path/to/files -p "*.txt" -r " " "_"

    # Batch add prefix to all JPG files
    ${SCRIPT_NAME}.sh -d /photos --prefix "vacation_" -p "*.jpg"

    # Recursive batch processing
    ${SCRIPT_NAME}.sh -d /documents --recursive --suffix "_backup" -p "*.doc"

    # Dry run to preview changes
    ${SCRIPT_NAME}.sh --dry-run -d /path/to/files -p "*.jpg" -r " " "_"

    # Add prefix with date
    ${SCRIPT_NAME}.sh --prefix "$(date +%Y%m%d)_" -d /path/to/files

    # Regex transformation with capture groups
    ${SCRIPT_NAME}.sh -d /photos -p "IMG_*.jpg" --regex "IMG_(.*)" "vacation_\1"

    # Custom transformation (add date)
    ${SCRIPT_NAME}.sh -d /files -p "*.txt" --transform date

    # Template-based renaming
    ${SCRIPT_NAME}.sh -d /files -p "*.jpg" --template "{date}_{counter}_{basename}"

    # Undo operations from log file
    ${SCRIPT_NAME}.sh --undo /path/to/logfile.log

For more examples and detailed documentation, see the README.md file.

AUTHOR:
    ${SCRIPT_AUTHOR}

LICENSE:
    See repository LICENSE file
EOF
}

# Display version information
version() {
    echo "${SCRIPT_NAME} v${SCRIPT_VERSION}"
    echo "Author: ${SCRIPT_AUTHOR}"
    echo "License: See repository LICENSE file"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Validate file exists and is readable
validate_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        log_error "File does not exist: $file"
        return 1
    fi
    if [[ ! -r "$file" ]]; then
        log_error "File is not readable: $file"
        return 1
    fi
    return 0
}

# Validate directory exists and is accessible
validate_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        log_error "Directory does not exist: $dir"
        return 1
    fi
    if [[ ! -r "$dir" ]] || [[ ! -x "$dir" ]]; then
        log_error "Directory is not accessible: $dir"
        return 1
    fi
    return 0
}

# Check dependencies
check_dependencies() {
    local missing_deps=()

    # Required dependencies
    local required=("mv" "cp" "find" "sed")
    for dep in "${required[@]}"; do
        if ! command_exists "$dep"; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        return 1
    fi

    # Note: Bash 3.2 compatibility - some advanced features may be limited
    log_debug "Using Bash version: ${BASH_VERSION}"

    return 0
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

# Initialize variables for argument parsing
SINGLE_FILE=""
NEW_NAME=""
DIRECTORY=""
PATTERN=""
REPLACE_OLD=""
REPLACE_NEW=""
REGEX_PATTERN=""
REGEX_REPLACE=""
PREFIX=""
SUFFIX=""
CASE_CONVERSION=""
UNDO_OPERATION=false
UNDO_FILE=""
TRANSFORM_FUNCTION=""
TEMPLATE=""

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--file)
                SINGLE_FILE="$2"
                shift 2
                ;;
            -n|--name)
                NEW_NAME="$2"
                shift 2
                ;;
            -d|--directory)
                DIRECTORY="$2"
                shift 2
                ;;
            -p|--pattern)
                PATTERN="$2"
                shift 2
                ;;
            -r|--replace)
                REPLACE_OLD="$2"
                REPLACE_NEW="$3"
                shift 3
                ;;
            --regex)
                REGEX_PATTERN="$2"
                REGEX_REPLACE="$3"
                shift 3
                ;;
            --transform)
                TRANSFORM_FUNCTION="$2"
                shift 2
                ;;
            --template)
                TEMPLATE="$2"
                shift 2
                ;;
            --prefix)
                PREFIX="$2"
                shift 2
                ;;
            --suffix)
                SUFFIX="$2"
                shift 2
                ;;
            --case)
                CASE_CONVERSION="$2"
                shift 2
                ;;
            --undo)
                UNDO_OPERATION=true
                UNDO_FILE="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --backup)
                BACKUP=true
                shift
                ;;
            --interactive)
                INTERACTIVE=true
                shift
                ;;
            --recursive)
                RECURSIVE=true
                shift
                ;;
            --verbose)
                ((VERBOSE++))
                ((LOG_LEVEL++))
                shift
                ;;
            --log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -v|--version)
                version
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                echo "Use --help for usage information" >&2
                exit 1
                ;;
            *)
                # Positional arguments (files to process)
                break
                ;;
        esac
    done

    # Store remaining arguments as files to process
    FILES_TO_PROCESS=("$@")
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

# Validate parsed arguments
validate_arguments() {
    # Check for conflicting options
    if [[ -n "$SINGLE_FILE" ]] && [[ -n "$DIRECTORY" ]]; then
        log_error "Cannot specify both --file and --directory"
        return 1
    fi

    if [[ -n "$SINGLE_FILE" ]] && [[ -n "$PATTERN" ]]; then
        log_error "Cannot specify both --file and --pattern"
        return 1
    fi

    # Validate single file operation
    if [[ -n "$SINGLE_FILE" ]]; then
        if [[ -z "$NEW_NAME$REPLACE_OLD$REGEX_PATTERN$TRANSFORM_FUNCTION$TEMPLATE$PREFIX$SUFFIX$CASE_CONVERSION" ]]; then
            log_error "Single file operation requires at least one transformation option (--name, --replace, --regex, --transform, --template, --prefix, --suffix, or --case)"
            return 1
        fi
        validate_file "$SINGLE_FILE" || return 1
    fi

    # Validate directory operation
    if [[ -n "$DIRECTORY" ]]; then
        if [[ -z "$REPLACE_OLD$REGEX_PATTERN$TRANSFORM_FUNCTION$TEMPLATE$PREFIX$SUFFIX$CASE_CONVERSION" ]]; then
            log_error "Batch operation requires at least one transformation option (--replace, --regex, --transform, --template, --prefix, --suffix, or --case)"
            return 1
        fi
        validate_directory "$DIRECTORY" || return 1
    fi

    # Validate case conversion
    if [[ -n "$CASE_CONVERSION" ]]; then
        case "$CASE_CONVERSION" in
            upper|lower|title)
                ;;
            *)
                log_error "Invalid case conversion: $CASE_CONVERSION (must be upper, lower, or title)"
                return 1
                ;;
        esac
    fi

    return 0
}

# =============================================================================
# CORE FUNCTIONALITY
# =============================================================================

# Execute or simulate file operation
execute_operation() {
    local operation="$1"
    local description="$2"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would execute: $description"
        return 0
    else
        log_debug "Executing: $description"
        if eval "$operation"; then
            log_info "✓ $description"
            return 0
        else
            log_error "✗ Failed: $description"
            return 1
        fi
    fi
}

# Create backup of file
create_backup() {
    local file="$1"
    local backup_file="${file}.bak"

    if [[ "$BACKUP" == true ]]; then
        execute_operation "cp '$file' '$backup_file'" "Backup: $file → $backup_file"
    fi
}

# Apply find and replace operation
apply_find_replace() {
    local text="$1"
    local old_pattern="$2"
    local new_pattern="$3"

    # Use sed for find and replace
    echo "$text" | sed "s/$old_pattern/$new_pattern/g"
}

# Apply regex pattern matching with capture groups
apply_regex_transform() {
    local text="$1"
    local pattern="$2"
    local replacement="$3"

    # Use sed with extended regex for capture group support
    echo "$text" | sed -E "s/$pattern/$replacement/g"
}

# Apply custom transformation function
apply_custom_transform() {
    local filename="$1"
    local transform="$2"
    local suffix=""

    case "$transform" in
        date)
            # Add current date in YYYYMMDD format
            suffix="_$(date +%Y%m%d)"
            ;;
        datetime)
            # Add current date and time
            suffix="_$(date +%Y%m%d_%H%M%S)"
            ;;
        counter)
            # Add sequential counter (global counter)
            if [[ -z "${COUNTER:-}" ]]; then
                COUNTER=1
            else
                ((COUNTER++))
            fi
            suffix=$(printf "_%03d" "$COUNTER")
            ;;
        random)
            # Add random 4-character string (macOS compatible)
            local random_str=""
            for i in {1..4}; do
                local char=$((RANDOM % 36))
                if [[ $char -lt 10 ]]; then
                    random_str="${random_str}$char"
                else
                    random_str="${random_str}$(printf \\$(printf '%03o' $((char + 87))))"
                fi
            done
            suffix="_${random_str}"
            ;;
        hash)
            # Add MD5 hash of file (if file exists)
            local file_path="$3"
            if [[ -f "$file_path" ]] && command_exists "md5"; then
                local file_hash=$(md5 -q "$file_path" 2>/dev/null | cut -c1-8)
                suffix="_${file_hash}"
            elif [[ -f "$file_path" ]] && command_exists "md5sum"; then
                local file_hash=$(md5sum "$file_path" 2>/dev/null | cut -c1-8)
                suffix="_${file_hash}"
            else
                # Fallback if no hash command available
                suffix="_hash"
            fi
            ;;
        parsedate)
            # Parse date from filename and convert to YYMMDD format
            # Supports formats like "December 1, 2025" → "251201"
            # Replaces the date pattern in the filename
            if [[ "$filename" =~ ([A-Za-z]+)\ ([0-9]{1,2}),\ ([0-9]{4}) ]]; then
                local month_name="${BASH_REMATCH[1]}"
                local day="${BASH_REMATCH[2]}"
                local year="${BASH_REMATCH[3]}"

                # Convert month name to number
                case "$month_name" in
                    January|january) month_num="01" ;;
                    February|february) month_num="02" ;;
                    March|march) month_num="03" ;;
                    April|april) month_num="04" ;;
                    May|may) month_num="05" ;;
                    June|june) month_num="06" ;;
                    July|july) month_num="07" ;;
                    August|august) month_num="08" ;;
                    September|september) month_num="09" ;;
                    October|october) month_num="10" ;;
                    November|november) month_num="11" ;;
                    December|december) month_num="12" ;;
                    *) month_num="" ;;
                esac

                if [[ -n "$month_num" ]]; then
                    # Format as YYMMDD
                    local yy="${year: -2}"
                    local dd=$(printf "%02d" "$day")
                    local parsed_date="${yy}${month_num}${dd}"

                    # Replace the date pattern with the parsed date
                    echo "${filename/$month_name $day, $year/$parsed_date}"
                    return
                fi
            fi

            # If no date pattern found, return original filename
            echo "$filename"
            ;;
        *)
            log_warn "Unknown transformation function: $transform"
            echo "$filename"
            return
            ;;
    esac

    # Insert suffix before file extension
    if [[ "$filename" =~ \. ]]; then
        echo "${filename%.*}${suffix}.${filename##*.}"
    else
        echo "${filename}${suffix}"
    fi
}

# Apply template-based renaming
apply_template() {
    local original_file="$1"
    local template="$2"

    # Extract file components
    local dirname=$(dirname "$original_file")
    local basename=$(basename "$original_file")
    local filename="${basename%.*}"
    local extension=""

    if [[ "$basename" == *.* ]]; then
        extension="${basename##*.}"
    fi

    # Replace placeholders in template
    local result="$template"

    # Replace {basename} with filename without extension
    result="${result//\{basename\}/$filename}"

    # Replace {extension} with file extension
    result="${result//\{extension\}/$extension}"

    # Replace {dirname} with directory name
    result="${result//\{dirname\}/$(basename "$dirname")}"

    # Replace {date} with current date
    result="${result//\{date\}/$(date +%Y%m%d)}"

    # Replace {datetime} with current date and time
    result="${result//\{datetime\}/$(date +%Y%m%d_%H%M%S)}"

    # Replace {counter} with sequential counter
    result="${result//\{counter\}/$(printf "%03d" "$TEMPLATE_COUNTER")}"

    # Replace {random} with random string
    if [[ "$result" == *"{random}"* ]]; then
        local random_str=""
        for i in {1..4}; do
            local char=$((RANDOM % 36))
            if [[ $char -lt 10 ]]; then
                random_str="${random_str}$char"
            else
                random_str="${random_str}$(printf \\$(printf '%03o' $((char + 87))))"
            fi
        done
        result="${result//\{random\}/$random_str}"
    fi

    # Replace {hash} with file hash
    if [[ "$result" == *"{hash}"* ]]; then
        if command_exists "md5"; then
            local file_hash=$(md5 -q "$original_file" 2>/dev/null | cut -c1-8)
            result="${result//\{hash\}/$file_hash}"
        elif command_exists "md5sum"; then
            local file_hash=$(md5sum "$original_file" 2>/dev/null | cut -c1-8)
            result="${result//\{hash\}/$file_hash}"
        else
            result="${result//\{hash\}/hash}"
        fi
    fi

    echo "$result"
}

# Undo operations from log file
undo_operations() {
    local log_file="$1"

    if [[ ! -f "$log_file" ]]; then
        log_error "Log file not found: $log_file"
        return 1
    fi

    log_info "Reading undo operations from: $log_file"

    # Read log file in reverse order (most recent first)
    local operations=()
    while IFS= read -r line; do
        if [[ "$line" =~ RENAME:\ \'([^\']+)\'\ →\ \'([^\']+)\' ]]; then
            local old_file="${BASH_REMATCH[1]}"
            local new_file="${BASH_REMATCH[2]}"
            operations+=("$new_file:$old_file")
        fi
    done < <(tac "$log_file" 2>/dev/null || tail -r "$log_file" 2>/dev/null || cat "$log_file")

    if [[ ${#operations[@]} -eq 0 ]]; then
        log_warn "No rename operations found in log file"
        return 0
    fi

    log_info "Found ${#operations[@]} operations to undo"

    local undone=0
    local errors=0

    for operation in "${operations[@]}"; do
        IFS=':' read -r new_file old_file <<< "$operation"

        if [[ -f "$new_file" ]] && [[ ! -f "$old_file" ]]; then
            # Execute undo
            if execute_operation "mv '$new_file' '$old_file'" "Undo: $(basename "$new_file") → $(basename "$old_file")"; then
                ((undone++))
            else
                ((errors++))
                log_warn "Failed to undo: $new_file → $old_file"
            fi
        else
            log_debug "Skipping undo: $new_file → $old_file (files not in expected state)"
        fi
    done

    log_info "Undo completed: $undone operations undone"
    if [[ $errors -gt 0 ]]; then
        log_warn "$errors operations could not be undone"
    fi
}

# Apply case conversion
apply_case_conversion() {
    local text="$1"
    local case_type="$2"

    case "$case_type" in
        upper)
            echo "$text" | tr '[:lower:]' '[:upper:]'
            ;;
        lower)
            echo "$text" | tr '[:upper:]' '[:lower:]'
            ;;
        title)
            # Simple title case: capitalize first letter of each word
            echo "$text" | sed 's/\b\w/\U&/g'
            ;;
        *)
            echo "$text"
            ;;
    esac
}

# Generate new filename by applying all transformations
generate_new_filename() {
    local original_file="$1"
    local result

    # Get the base filename (without path)
    local filename
    filename=$(basename "$original_file")

    # If template is specified, use template-based renaming (replaces all other transformations)
    if [[ -n "$TEMPLATE" ]]; then
        log_debug "Applying template: '$TEMPLATE'"
        result=$(apply_template "$original_file" "$TEMPLATE")
        echo "$result"
        return 0
    fi

    # If a specific new name was provided, use it without transformations
    if [[ -n "$NEW_NAME" ]]; then
        echo "$NEW_NAME"
        return 0
    fi

    # Start with the filename
    result="$filename"

    # Apply find and replace if specified
    if [[ -n "$REPLACE_OLD" ]]; then
        log_debug "Applying find-replace: '$REPLACE_OLD' → '$REPLACE_NEW'"
        result=$(apply_find_replace "$result" "$REPLACE_OLD" "$REPLACE_NEW")
    fi

    # Apply regex transformation if specified
    if [[ -n "$REGEX_PATTERN" ]]; then
        log_debug "Applying regex transform: '$REGEX_PATTERN' → '$REGEX_REPLACE'"
        result=$(apply_regex_transform "$result" "$REGEX_PATTERN" "$REGEX_REPLACE")
    fi

    # Apply custom transformation if specified
    if [[ -n "$TRANSFORM_FUNCTION" ]]; then
        log_debug "Applying custom transform: '$TRANSFORM_FUNCTION'"
        result=$(apply_custom_transform "$result" "$TRANSFORM_FUNCTION" "$original_file")
    fi

    # Apply prefix if specified
    if [[ -n "$PREFIX" ]]; then
        log_debug "Applying prefix: '$PREFIX'"
        result="${PREFIX}${result}"
    fi

    # Apply suffix if specified (before extension)
    if [[ -n "$SUFFIX" ]]; then
        log_debug "Applying suffix: '$SUFFIX'"
        # Insert suffix before file extension
        if [[ "$result" =~ \. ]]; then
            result="${result%.*}${SUFFIX}.${result##*.}"
        else
            result="${result}${SUFFIX}"
        fi
    fi

    # Apply case conversion if specified
    if [[ -n "$CASE_CONVERSION" ]]; then
        log_debug "Applying case conversion: $CASE_CONVERSION"
        result=$(apply_case_conversion "$result" "$CASE_CONVERSION")
    fi

    # Apply template if specified (this replaces the entire filename)
    if [[ -n "$TEMPLATE" ]]; then
        log_debug "Applying template: '$TEMPLATE'"
        result=$(apply_template "$original_file" "$TEMPLATE")
    fi

    echo "$result"
}

# Rename single file with transformations
rename_single_file() {
    local old_file="$1"
    local final_name

    # Increment template counter if template is being used
    if [[ -n "$TEMPLATE" ]]; then
        ((TEMPLATE_COUNTER++))
    fi

    # Generate the new filename with all transformations applied
    final_name=$(generate_new_filename "$old_file")

    # Get the directory of the original file
    local dir
    dir=$(dirname "$old_file")

    # Construct full path for new file
    local new_file="${dir}/${final_name}"

    # Check if source and destination are the same
    if [[ "$old_file" == "$new_file" ]]; then
        log_info "No changes needed for: $old_file"
        return 0
    fi

    # Check if target file already exists
    if [[ -f "$new_file" ]]; then
        log_error "Target file already exists: $new_file"
        return 1
    fi

    # Create backup if requested
    create_backup "$old_file"

    # Execute rename
    execute_operation "mv '$old_file' '$new_file'" "Rename: $(basename "$old_file") → $final_name"

    # Log operation for potential undo (if not dry run)
    if [[ "$DRY_RUN" != true ]] && [[ -n "$LOG_FILE" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') RENAME: '$old_file' → '$new_file'" >> "$LOG_FILE"
    fi
}

# Find files in directory matching pattern
find_files() {
    local directory="$1"
    local pattern="$2"
    local recursive="$3"

    if [[ "$recursive" == true ]]; then
        # Recursive search
        find "$directory" -type f -name "$pattern" 2>/dev/null
    else
        # Non-recursive search
        find "$directory" -maxdepth 1 -type f -name "$pattern" 2>/dev/null
    fi
}

# Process batch of files
process_batch() {
    local directory="$1"
    local pattern="$2"

    log_info "Scanning directory: $directory"
    log_debug "Pattern: $pattern, Recursive: $RECURSIVE"

    # Find all matching files and store in array
    local files=()
    while IFS= read -r -d $'\n' file; do
        files+=("$file")
    done < <(find_files "$directory" "$pattern" "$RECURSIVE")

    local file_count=${#files[@]}
    log_info "Found $file_count file(s) matching pattern"

    if [[ $file_count -eq 0 ]]; then
        log_warn "No files found matching pattern: $pattern"
        return 0
    fi

    # Process each file
    local processed=0
    local errors=0

    for file in "${files[@]}"; do
        ((processed++))
        log_debug "Processing file $processed/$file_count: $file"

        if ! rename_single_file "$file"; then
            ((errors++))
            if [[ "$INTERACTIVE" != true ]]; then
                log_warn "Failed to process: $file"
            fi
        fi

        # Progress indicator for large batches
        if [[ $((processed % 10)) -eq 0 ]] && [[ $file_count -gt 10 ]]; then
            log_info "Progress: $processed/$file_count files processed"
        fi
    done

    # Summary
    log_info "Batch processing completed: $processed files processed"
    if [[ $errors -gt 0 ]]; then
        log_warn "$errors file(s) failed to process"
    fi
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    # Parse command line arguments
    parse_arguments "$@"

    # Check dependencies
    check_dependencies || exit 1

    # Validate arguments
    validate_arguments || exit 1

    # Set up logging if requested
    if [[ -n "$LOG_FILE" ]]; then
        # Create log directory if it doesn't exist
        local log_dir
        log_dir=$(dirname "$LOG_FILE")
        if [[ ! -d "$log_dir" ]]; then
            mkdir -p "$log_dir" 2>/dev/null || {
                log_error "Cannot create log directory: $log_dir"
                exit 1
            }
        fi
        log_info "Logging to: $LOG_FILE"
    fi

    log_info "Starting file_renamer v0.1.0"

    # Handle undo operation first
    if [[ "$UNDO_OPERATION" == true ]]; then
        if [[ -z "$UNDO_FILE" ]]; then
            log_error "Undo operation requires a log file path"
            echo "Use --undo FILE to specify the log file" >&2
            exit 1
        fi
        undo_operations "$UNDO_FILE"
        log_info "Undo operation completed"
        exit 0
    fi

    # Display configuration in debug mode
    log_debug "Configuration:"
    log_debug "  Dry run: $DRY_RUN"
    log_debug "  Verbose: $VERBOSE"
    log_debug "  Backup: $BACKUP"
    log_debug "  Interactive: $INTERACTIVE"
    log_debug "  Recursive: $RECURSIVE"
    log_debug "  Log level: $LOG_LEVEL"
    log_debug "  Single file: '$SINGLE_FILE'"
    log_debug "  New name: '$NEW_NAME'"
    log_debug "  Directory: '$DIRECTORY'"
    log_debug "  Pattern: '$PATTERN'"
    log_debug "  Replace: '$REPLACE_OLD' → '$REPLACE_NEW'"
    log_debug "  Regex: '$REGEX_PATTERN' → '$REGEX_REPLACE'"
    log_debug "  Transform: '$TRANSFORM_FUNCTION'"
    log_debug "  Template: '$TEMPLATE'"
    log_debug "  Prefix: '$PREFIX'"
    log_debug "  Suffix: '$SUFFIX'"
    log_debug "  Case conversion: '$CASE_CONVERSION'"

    # Process single file operation
    if [[ -n "$SINGLE_FILE" ]]; then
        log_info "Processing single file: $SINGLE_FILE"
        rename_single_file "$SINGLE_FILE"
        log_info "Single file operation completed"
        exit 0
    fi

    # Process batch operations
    if [[ -n "$DIRECTORY" ]]; then
        # Set default pattern if not specified
        local batch_pattern="${PATTERN:-*}"
        process_batch "$DIRECTORY" "$batch_pattern"
        log_info "Batch operation completed"
        exit 0
    fi

    # If no specific operation specified, show help
    if [[ $# -eq 0 ]] || [[ -z "$SINGLE_FILE$DIRECTORY" ]]; then
        log_error "No operation specified"
        echo "Use --help for usage information" >&2
        exit 1
    fi

    log_info "${SCRIPT_NAME} completed successfully"
}

# =============================================================================
# SCRIPT ENTRY POINT
# =============================================================================

# Handle script being sourced vs executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi