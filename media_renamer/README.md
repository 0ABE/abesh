# Media File Renamer - Plex/Netflix/Apple TV Compatible

A professional bash script to rename movie and TV show files using industry-standard naming formats compatible with Plex, Netflix, Apple TV, and other media platforms.

## Key Features

- **Industry Standard Formats**: Compatible with Plex, Netflix, Apple TV naming conventions
- **Automatic Title Extraction**: Automatically extracts episode titles from existing filenames (enabled by default)
- **Enhanced Pattern Recognition**: Supports 8+ different filename patterns for title extraction
- **Flexible Naming**: Support for TV shows, movies, and multi-part content
- **Safe Operations**: Dry-run mode and interactive confirmation
- **Professional Output**: Clean, standardized naming that media platforms recognize

## Quick Start

```bash
# Make executable
chmod +x media_renamer.sh

# TV Series with auto-extracted titles (default behavior)
./media_renamer.sh -s 1 -e 1 -y 2024 -n "Show Name" *.mp4

# Movie parts
./media_renamer.sh -p 1 -y 2023 -n "Movie Name" movie_*.mp4

# Always test first with dry-run
./media_renamer.sh --dry-run -s 1 -e 1 -y 2024 -n "Show Name" *.mp4

# Disable auto-title extraction if not wanted
./media_renamer.sh --no-auto-titles -s 1 -e 1 -y 2024 -n "Show Name" *.mp4
```

## Standard Output Formats

### TV Shows
- **Format**: `Show Name (Year) - S01E01 - Episode Title.ext`
- **Example**: `Breaking Bad (2008) - S01E01 - Pilot.mkv`

### Movies
- **Single File**: `Movie Name (Year).ext`
- **Multi-Part**: `Movie Name (Year) - Part 1.ext`
- **Examples**: 
  - `Avengers Endgame (2019).mp4`
  - `The Godfather (1972) - Part 1.mp4`

## Options

| Option | Description | Example |
|--------|-------------|---------|
| `-s, --season <num>` | Season number | `-s 1` |
| `-e, --episode <num>` | Starting episode | `-e 1` |
| `-p, --part <num>` | Starting part number | `-p 1` |
| `-y, --year <year>` | Release year (recommended) | `-y 2024` |
| `-n, --name <name>` | Show/movie name | `-n "Amazing Show"` |
| `--no-auto-titles` | Disable auto title extraction | `--no-auto-titles` |
| `-d, --dry-run` | Preview changes only | `-d` |
| `-v, --verbose` | Detailed output | `-v` |
| `-i, --interactive` | Confirm each rename | `-i` |

## Automatic Title Extraction

The script automatically extracts episode titles from existing filenames using 8+ different patterns:

| Pattern | Example Input | Extracted Title |
|---------|---------------|-----------------|
| Part X - Title | `Adventure Part 1 - Beginning.mp4` | `Beginning` |
| Show_E01_Title | `Show_E01_Great_Episode.mp4` | `Great Episode` |
| Show - Title | `MyShow - Amazing Story.mp4` | `Amazing Story` |
| Episode X - Title | `Show Episode 5 - Finale.mp4` | `Finale` |
| S01E01 - Title | `Show_S01E01_Pilot.mp4` | `Pilot` |
| Show [01] Title | `Series [01] First Episode.mp4` | `First Episode` |
| Show (01) Title | `Series (01) Intro.mp4` | `Intro` |
| Show_Title | `MyShow_Great_Story.mp4` | `Great Story` |

**Note**: Title extraction is enabled by default. Use `--no-auto-titles` to disable.

## Usage Examples

### TV Series with Extracted Titles
```bash
# Input: "ShowName Part 1 - Great Episode.mp4"
./media_renamer.sh -s 1 -e 1 -y 2024 -n "Show Name" -a *.mp4
# Output: "Show Name (2024) - S01E01 - Great Episode.mp4"
```

### Movie Collection
```bash
# Input: "epic_movie_part1.mp4", "epic_movie_part2.mp4"
./media_renamer.sh -p 1 -y 2023 -n "Epic Movie" epic_movie_*.mp4
# Output: "Epic Movie (2023) - Part 1.mp4", "Epic Movie (2023) - Part 2.mp4"
```

### Simple TV Series
```bash
# Input: "episode01.mkv", "episode02.mkv"
./media_renamer.sh -s 1 -e 1 -y 2024 -n "Great Series" episode*.mkv
# Output: "Great Series (2024) - S01E01.mkv", "Great Series (2024) - S01E02.mkv"
```

## Platform Compatibility

✅ **Plex Media Server** - Perfect metadata recognition  
✅ **Netflix-style naming** - Industry standard format  
✅ **Apple TV** - Proper season/episode detection  
✅ **Emby/Jellyfin** - Standard library scanning  
✅ **Kodi** - Compatible with scrapers  

## Best Practices

1. **Always include year** (`-y`) for better platform recognition
2. **Use dry-run first** (`-d`) to preview changes
3. **Consistent naming** across entire series/collections
4. **Descriptive show names** help with metadata matching
5. **Auto-extract titles** (`-a`) for better organization

## Supported Formats

- `.mp4` - Most compatible format
- `.mkv` - High quality container
- `.avi` - Legacy support
- `.mov` - Apple format
- `.wmv` - Windows format
- `.flv` - Flash video
- `.webm` - Web format
- `.m4v` - iTunes format

## Error Handling

- File existence validation
- Supported format checking
- Duplicate name prevention
- Numeric input validation
- Clear error messages with suggested fixes

## Safety Features

- **Dry-run mode**: See all changes before applying
- **Interactive mode**: Confirm each rename individually  
- **Collision detection**: Won't overwrite existing files
- **Verbose logging**: Detailed operation information
- **Error recovery**: Continues processing if individual files fail