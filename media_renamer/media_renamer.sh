#!/bin/bash
# 
#        d8888 888888b.   8888888888         888      
#       d88888 888  "88b  888                888      
#      d88P888 888  .88P  888                888      
#     d88P 888 8888888K.  8888888   .d8888b  88888b.  
#    d88P  888 888  "Y88b 888       88K      888 "88b 
#   d88P   888 888    888 888       "Y8888b. 888  888 
#  d8888888888 888   d88P 888            X88 888  888 
# d88P     888 8888888P"  8888888888 88888P' 888  888 
# 
# Copyright (c) 2025, Abe Mishler
# Licensed under the Universal Permissive License v 1.0
# as shown at https://oss.oracle.com/licenses/upl/. 
# 
# Media File Renamer - Plex/Netflix/Apple TV Compatible
# Renames movie and TV show files with proper season and episode formatting
# Usage: ./media_renamer.sh [options] <files...>

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default settings
DRY_RUN=false
VERBOSE=false
INTERACTIVE=false
SEASON=""
EPISODE=""
PART=""
YEAR=""
SHOW_NAME=""
AUTO_EXTRACT_TITLES=true  # Default to true for better user experience
USE_EXTRACTED_NUMBERS=true  # Default to true to use numbers from filenames

# Help function
show_help() {
    cat << EOF
Media File Renamer - Plex/Netflix/Apple TV Compatible

USAGE:
    $0 [OPTIONS] <files...>

OPTIONS:
    -h, --help              Show this help message
    -d, --dry-run           Show what would be renamed without actually renaming
    -v, --verbose           Verbose output
    -i, --interactive       Ask for confirmation before each rename
    -s, --season <num>      Set season number (optional)
    -e, --episode <num>     Set starting episode number
    -p, --part <num>        Set starting part number (for movies)
    -y, --year <year>       Set release year (recommended for media platforms)
    -n, --name <name>       Set show/movie name (overrides filename)
    --no-auto-titles        Disable automatic title extraction from filenames
    --sequential            Use sequential numbering instead of extracted numbers

EXAMPLES:
    # TV show episodes with auto-extracted numbers and titles (default)
    $0 -s 1 -y 2024 -n "Amazing Show" *.mkv
    # Result: Amazing Show (2024) - S01E05.mkv (numbers from filename)

    # Use sequential numbering instead of extracted numbers
    $0 --sequential -s 1 -e 1 -y 2024 -n "Amazing Show" *.mkv
    # Result: Amazing Show (2024) - S01E01.mkv (sequential from -e)

    # Movie parts with year
    $0 -p 1 -y 2023 -n "Epic Movie" movie_*.mp4
    # Result: Epic Movie (2023) - Part 1.mp4

    # Disable auto-title extraction if not desired
    $0 -s 1 -y 2024 -n "Show Name" --no-auto-titles existing_*.mp4
    # Result: Show Name (2024) - S01E05.mp4 (no episode titles)

    # Single movie (no parts)
    $0 -y 2023 -n "Great Film" movie.mp4
    # Result: Great Film (2023).mp4

SUPPORTED FORMATS:
    - Video: .mp4, .mkv, .avi, .mov, .wmv, .flv, .webm, .m4v
    - Follows Plex, Netflix, and Apple TV naming standards

STANDARD NAMING PATTERNS:
    TV Shows:     Show Name (Year) - S01E01 - Episode Title.ext
    TV (no title): Show Name (Year) - S01E01.ext
    Movies:       Movie Name (Year).ext
    Movie Parts:  Movie Name (Year) - Part 1.ext

EOF
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${NC}[VERBOSE]${NC} $1"
    fi
}

# Check if file is a supported video format
is_video_file() {
    local file="$1"
    local ext="${file##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    
    case "$ext" in
        mp4|mkv|avi|mov|wmv|flv|webm|m4v)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Extract title from existing filename
extract_title() {
    local filename="$1"
    local basename="${filename%.*}"
    local base_name_only="${basename##*/}"  # Remove path
    
    # Common patterns to extract titles from filenames
    
    # Pattern 1: "ShowName Part X - Title" or "ShowName Part X Title"
    if [[ "$base_name_only" =~ Part[[:space:]]*[0-9]+[[:space:]]*-[[:space:]]*(.+)$ ]]; then
        echo "${BASH_REMATCH[1]}" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//'
        return 0
    fi
    
    # Pattern 2: "ShowName_E01_Title" or "ShowName E01 Title"
    if [[ "$base_name_only" =~ ^.*[_[:space:]]+E[0-9]+[_[:space:]]+(.+)$ ]]; then
        echo "${BASH_REMATCH[1]}" | sed 's/[_-]/ /g' | sed 's/  */ /g'
        return 0
    fi
    
    # Pattern 3: "ShowName - Title" (general hyphen separator)
    if [[ "$base_name_only" =~ ^[^-]+-[[:space:]]*(.+)$ ]]; then
        echo "${BASH_REMATCH[1]}" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//'
        return 0
    fi
    
    # Pattern 4: "ShowName Episode X - Title" or "ShowName Ep X - Title"
    if [[ "$base_name_only" =~ (Episode|Ep)[[:space:]]*[0-9]+[[:space:]]*-[[:space:]]*(.+)$ ]]; then
        echo "${BASH_REMATCH[2]}" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//'
        return 0
    fi
    
    # Pattern 5: "ShowName S01E01 - Title" or "ShowName_S01E01_Title"
    if [[ "$base_name_only" =~ S[0-9]+E[0-9]+[_[:space:]]*-?[_[:space:]]*(.+)$ ]]; then
        echo "${BASH_REMATCH[1]}" | sed 's/[_-]/ /g' | sed 's/  */ /g' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//'
        return 0
    fi
    
    # Pattern 6: "ShowName [episode_number] Title" (brackets)
    if [[ "$base_name_only" =~ \[[0-9]+\][[:space:]]*(.+)$ ]]; then
        echo "${BASH_REMATCH[1]}" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//'
        return 0
    fi
    
    # Pattern 7: "ShowName (episode_number) Title" (parentheses)
    if [[ "$base_name_only" =~ \([0-9]+\)[[:space:]]*(.+)$ ]]; then
        echo "${BASH_REMATCH[1]}" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//'
        return 0
    fi
    
    # Pattern 8: "ShowName_Title" or "ShowName Title" (underscore or space, no numbers)
    if [[ "$base_name_only" =~ ^[^0-9]*[_[:space:]]+([^0-9].*)$ ]] && [[ ! "$base_name_only" =~ Part|Episode|Ep|S[0-9]|E[0-9] ]]; then
        echo "${BASH_REMATCH[1]}" | sed 's/[_-]/ /g' | sed 's/  */ /g' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//'
        return 0
    fi
    
    # No title found
    return 1
}

# Extract episode number from existing filename
extract_episode_number() {
    local filename="$1"
    local basename="${filename%.*}"
    local base_name_only="${basename##*/}"  # Remove path
    
    # Pattern 1: "Part X" - extract X
    if [[ "$base_name_only" =~ Part[[:space:]]*([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    
    # Pattern 2: "Episode X" or "Ep X" - extract X
    if [[ "$base_name_only" =~ (Episode|Ep)[[:space:]]*([0-9]+) ]]; then
        echo "${BASH_REMATCH[2]}"
        return 0
    fi
    
    # Pattern 3: "S01E05" - extract 05
    if [[ "$base_name_only" =~ S[0-9]+E([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    
    # Pattern 4: "E05" - extract 05
    if [[ "$base_name_only" =~ E([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    
    # Pattern 5: "[05]" - extract 05
    if [[ "$base_name_only" =~ \[([0-9]+)\] ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    
    # Pattern 6: "(05)" - extract 05
    if [[ "$base_name_only" =~ \(([0-9]+)\) ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    
    # Pattern 7: "_05_" or "_05" - extract standalone numbers
    if [[ "$base_name_only" =~ [^0-9]([0-9]+)[^0-9]*$ ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    
    # No episode number found
    return 1
}

# Extract season number from existing filename
extract_season_number() {
    local filename="$1"
    local basename="${filename%.*}"
    local base_name_only="${basename##*/}"  # Remove path
    
    # Pattern 1: "S01E05" - extract 01
    if [[ "$base_name_only" =~ S([0-9]+)E[0-9]+ ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    
    # Pattern 2: "Season 1" - extract 1
    if [[ "$base_name_only" =~ Season[[:space:]]*([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    
    # No season number found
    return 1
}

# Sanitize filename for cross-platform compatibility
sanitize_filename() {
    local filename="$1"
    
    # Remove or replace ALL special characters for maximum compatibility
    
    # First, replace full-width characters with regular equivalents
    filename=$(echo "$filename" | sed 's/？/?/g')  # Full-width question mark
    filename=$(echo "$filename" | sed 's/！/!/g')   # Full-width exclamation
    filename=$(echo "$filename" | sed 's/：/:/g')   # Full-width colon
    
    # Replace smart quotes and apostrophes with regular ones
    filename=$(echo "$filename" | tr '""''' ''"'"'"')
    
    # Remove ALL special characters except letters, numbers, spaces, hyphens, and parentheses
    # Keep: a-z A-Z 0-9 space - ( )
    filename=$(echo "$filename" | sed 's/[^a-zA-Z0-9 ().-]//g')
    
    # Remove leading/trailing spaces and dots
    filename=$(echo "$filename" | sed 's/^[[:space:].]*//; s/[[:space:].]*$//')
    
    # Replace multiple consecutive spaces with single space
    filename=$(echo "$filename" | sed 's/[[:space:]]\+/ /g')
    
    # Remove multiple consecutive hyphens
    filename=$(echo "$filename" | sed 's/-\+/-/g')
    
    # Remove control characters (ASCII 0-31 and 127)
    filename=$(echo "$filename" | tr -d '\000-\037\177')
    
    # Ensure filename is not empty
    if [[ -z "$filename" ]]; then
        filename="video"
    fi
    
    echo "$filename"
}

# Generate standard filename format
generate_filename() {
    local show_name="$1"
    local year="$2"
    local season="$3"
    local episode="$4"
    local part="$5"
    local episode_title="$6"
    local extension="$7"
    
    # Sanitize show name
    local clean_show_name
    clean_show_name=$(sanitize_filename "$show_name")
    
    local result="$clean_show_name"
    
    # Add year if provided
    if [[ -n "$year" ]]; then
        result="${clean_show_name} (${year})"
    fi
    
    # Add season/episode or part information
    if [[ -n "$part" ]]; then
        # Movie part format: "Movie Name (Year) - Part 1"
        result="${result} - Part ${part}"
    elif [[ -n "$season" ]] && [[ -n "$episode" ]]; then
        # TV show format: "Show Name (Year) - S01E01"
        result="${result} - $(printf "S%02dE%02d" "$season" "$episode")"
    elif [[ -n "$episode" ]]; then
        # Episode without season: "Show Name (Year) - E01"
        result="${result} - $(printf "E%02d" "$episode")"
    fi
    
    # Add episode title if provided (sanitize it)
    if [[ -n "$episode_title" ]]; then
        local clean_title
        clean_title=$(sanitize_filename "$episode_title")
        result="${result} - ${clean_title}"
    fi
    
    # Final sanitization of the complete filename (before extension)
    result=$(sanitize_filename "$result")
    
    echo "${result}.${extension}"
}

# Confirm rename operation
confirm_rename() {
    local old_name="$1"
    local new_name="$2"
    
    if [[ "$INTERACTIVE" == true ]]; then
        echo -n "Rename '$(basename "$old_name")' to '$(basename "$new_name")'? [y/N] "
        read -r response
        case "$response" in
            [yY]|[yY][eE][sS])
                return 0
                ;;
            *)
                return 1
                ;;
        esac
    fi
    return 0
}

# Rename a single file
rename_file() {
    local file="$1"
    local show_name="$2"
    local year="$3"
    local season="$4"
    local episode="$5"
    local part="$6"
    
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi
    
    if ! is_video_file "$file"; then
        log_warning "Skipping non-video file: $file"
        return 0
    fi
    
    # Extract file parts
    local extension="${file##*.}"
    local dir_path="$(dirname "$file")"
    
    # Use provided show name or extract from filename
    local final_show_name="$show_name"
    if [[ -z "$final_show_name" ]]; then
        local basename="${file%.*}"
        final_show_name="$(basename "$basename")"
        # Clean up common patterns
        final_show_name=$(echo "$final_show_name" | sed 's/_E[0-9].*$//' | sed 's/[_-]/ /g' | sed 's/  */ /g')
    fi
    
    # Extract episode/season numbers from filename if available and enabled
    local final_episode="$episode"
    local final_season="$season"
    local final_part="$part"
    
    # Try to extract episode number from filename if extraction is enabled
    if [[ "$USE_EXTRACTED_NUMBERS" == true ]] && extract_episode_number "$file" >/dev/null; then
        local extracted_episode
        extracted_episode=$(extract_episode_number "$file")
        final_episode="$extracted_episode"
        log_verbose "Extracted episode number: $extracted_episode"
    fi
    
    # Try to extract season number from filename if not provided and extraction is enabled
    if [[ "$USE_EXTRACTED_NUMBERS" == true ]] && [[ -z "$final_season" ]] && extract_season_number "$file" >/dev/null; then
        final_season=$(extract_season_number "$file")
        log_verbose "Extracted season number: $final_season"
    fi
    
    # Extract episode title if auto-extract is enabled
    local episode_title=""
    if [[ "$AUTO_EXTRACT_TITLES" == true ]]; then
        if extract_title "$file" >/dev/null; then
            episode_title=$(extract_title "$file")
            log_verbose "Extracted title: $episode_title"
        fi
    fi
    
    # Generate new filename
    local new_basename
    new_basename=$(generate_filename "$final_show_name" "$year" "$final_season" "$final_episode" "$final_part" "$episode_title" "$extension")
    local new_path="${dir_path}/${new_basename}"
    
    if [[ "$file" == "$new_path" ]]; then
        log_verbose "File already has correct name: $(basename "$file")"
        return 0
    fi
    
    if [[ -f "$new_path" ]] && [[ "$file" != "$new_path" ]]; then
        log_error "Target file already exists: $(basename "$new_path")"
        return 1
    fi
    
    log_verbose "Processing: $(basename "$file") -> $(basename "$new_path")"
    
    if confirm_rename "$file" "$new_path"; then
        if [[ "$DRY_RUN" == true ]]; then
            echo "DRY RUN: Would rename '$(basename "$file")' to '$(basename "$new_path")'"
        else
            if mv "$file" "$new_path"; then
                log_success "Renamed: $(basename "$file") -> $(basename "$new_path")"
            else
                log_error "Failed to rename: $(basename "$file")"
                return 1
            fi
        fi
    else
        log_info "Skipped: $(basename "$file")"
    fi
}

# Parse command line arguments
FILES=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -i|--interactive)
            INTERACTIVE=true
            shift
            ;;
        -s|--season)
            SEASON="$2"
            shift 2
            ;;
        -e|--episode)
            EPISODE="$2"
            shift 2
            ;;
        -p|--part)
            PART="$2"
            shift 2
            ;;
        -y|--year)
            YEAR="$2"
            shift 2
            ;;
        -n|--name)
            SHOW_NAME="$2"
            shift 2
            ;;
        --no-auto-titles)
            AUTO_EXTRACT_TITLES=false
            shift
            ;;
        --sequential)
            USE_EXTRACTED_NUMBERS=false
            shift
            ;;
        -*)
            log_error "Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
        *)
            FILES+=("$1")
            shift
            ;;
    esac
done

# Validate arguments
if [[ ${#FILES[@]} -eq 0 ]]; then
    log_error "No files specified"
    echo "Use --help for usage information."
    exit 1
fi

# Validate numeric arguments
if [[ -n "$SEASON" ]] && ! [[ "$SEASON" =~ ^[0-9]+$ ]]; then
    log_error "Season must be a number: $SEASON"
    exit 1
fi

if [[ -n "$EPISODE" ]] && ! [[ "$EPISODE" =~ ^[0-9]+$ ]]; then
    log_error "Episode must be a number: $EPISODE"
    exit 1
fi

if [[ -n "$PART" ]] && ! [[ "$PART" =~ ^[0-9]+$ ]]; then
    log_error "Part must be a number: $PART"
    exit 1
fi

if [[ -n "$YEAR" ]] && ! [[ "$YEAR" =~ ^[0-9]{4}$ ]]; then
    log_error "Year must be a 4-digit number: $YEAR"
    exit 1
fi

# Check for conflicting options
if [[ -n "$PART" ]] && [[ -n "$EPISODE" ]]; then
    log_error "Cannot specify both --part and --episode"
    exit 1
fi

# Show configuration
if [[ "$VERBOSE" == true ]]; then
    log_info "Configuration:"
    echo "  Dry run: $DRY_RUN"
    echo "  Interactive: $INTERACTIVE"
    echo "  Season: ${SEASON:-"not set"}"
    echo "  Episode: ${EPISODE:-"not set"}"
    echo "  Part: ${PART:-"not set"}"
    echo "  Year: ${YEAR:-"not set"}"
    echo "  Show name: ${SHOW_NAME:-"auto-detect"}"
    echo "  Auto-extract titles: $AUTO_EXTRACT_TITLES"
    echo "  Files: ${#FILES[@]}"
fi

# Process files
current_episode="$EPISODE"
current_part="$PART"
error_count=0

for file in "${FILES[@]}"; do
    # Use the current episode/part numbers for sequential mode
    # or empty for extraction mode (handled in rename_file function)
    file_episode="$current_episode"
    file_part="$current_part"
    
    if rename_file "$file" "$SHOW_NAME" "$YEAR" "$SEASON" "$file_episode" "$file_part"; then
        # Increment episode or part number for next file only if using sequential numbering
        if [[ "$USE_EXTRACTED_NUMBERS" == false ]] && [[ -n "$current_episode" ]]; then
            ((current_episode++))
        fi
        if [[ "$USE_EXTRACTED_NUMBERS" == false ]] && [[ -n "$current_part" ]]; then
            ((current_part++))
        fi
    else
        ((error_count++))
    fi
done

# Summary
if [[ "$error_count" -gt 0 ]]; then
    log_warning "Completed with $error_count error(s)"
    exit 1
else
    log_success "All files processed successfully"
fi