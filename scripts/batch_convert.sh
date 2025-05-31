#!/bin/bash

# Dreamcast batch asset conversion script
# Processes multiple assets in batch for Dreamcast development

set -e

# Default values
INPUT_DIR=""
OUTPUT_DIR="./dreamcast_assets"
CONFIG_FILE="/etc/dreamcast/asset_pipeline.json"
PARALLEL_JOBS=4
FILE_TYPES="png,jpg,jpeg,bmp,tga,obj,fbx,3ds,dae,wav,mp3,ogg"
QUALITY="high"
VERBOSE=false
DRY_RUN=false

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Usage function
usage() {
    cat << EOF
Usage: $0 -i INPUT_DIR [-o OUTPUT_DIR] [-c CONFIG] [-t FILE_TYPES] [-j JOBS] [-q QUALITY] [-n] [-v]

Batch convert assets for Dreamcast development.

Options:
    -i INPUT_DIR    Input directory containing assets (required)
    -o OUTPUT_DIR   Output directory (default: ./dreamcast_assets)
    -c CONFIG       Configuration file (default: /etc/dreamcast/asset_pipeline.json)
    -t FILE_TYPES   Comma-separated file types to process (default: all supported)
    -j JOBS         Number of parallel jobs (default: 4)
    -q QUALITY      Quality preset: low, medium, high (default: high)
    -n              Dry run - show what would be processed
    -v              Verbose output
    -h              Show this help message

Supported file types:
    Images: png, jpg, jpeg, bmp, tga, tiff, gif
    Models: obj, fbx, 3ds, dae, stl, ply, gltf, glb
    Audio:  wav, mp3, ogg, flac, aiff, m4a

Examples:
    $0 -i assets/ -o dc_assets/
    $0 -i unity_export/ -t "png,jpg,fbx" -j 8 -q medium
    $0 -i raw_assets/ -n -v  # Dry run with verbose output

EOF
    exit 1
}

# Parse command line arguments
while getopts "i:o:c:t:j:q:nvh" opt; do
    case $opt in
        i) INPUT_DIR="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        c) CONFIG_FILE="$OPTARG" ;;
        t) FILE_TYPES="$OPTARG" ;;
        j) PARALLEL_JOBS="$OPTARG" ;;
        q) QUALITY="$OPTARG" ;;
        n) DRY_RUN=true ;;
        v) VERBOSE=true ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Validate required arguments
if [ -z "$INPUT_DIR" ]; then
    echo -e "${RED}Error: Input directory is required${NC}"
    usage
fi

if [ ! -d "$INPUT_DIR" ]; then
    echo -e "${RED}Error: Input directory does not exist: $INPUT_DIR${NC}"
    exit 1
fi

# Function to log messages
log() {
    if [ "$VERBOSE" = true ]; then
        echo -e "$1"
    fi
}

# Create output directory structure
if [ "$DRY_RUN" = false ]; then
    mkdir -p "$OUTPUT_DIR/textures"
    mkdir -p "$OUTPUT_DIR/models"
    mkdir -p "$OUTPUT_DIR/audio"
    mkdir -p "$OUTPUT_DIR/materials"
    mkdir -p "$OUTPUT_DIR/logs"
fi

# Get absolute paths
INPUT_DIR=$(cd "$INPUT_DIR" && pwd)
OUTPUT_DIR=$(cd "$OUTPUT_DIR" && pwd)

# Log file
LOG_FILE="$OUTPUT_DIR/logs/batch_convert_$(date +%Y%m%d_%H%M%S).log"

# Function to process image files
process_image() {
    local file="$1"
    local basename=$(basename "$file" | sed 's/\.[^.]*$//')
    
    echo -e "${BLUE}Processing image: $file${NC}"
    
    if [ "$DRY_RUN" = true ]; then
        echo "  Would convert to: $OUTPUT_DIR/textures/${basename}.pvr"
        return
    fi
    
    # Use optimize_texture.sh if available
    if [ -x "$(dirname "$0")/optimize_texture.sh" ]; then
        "$(dirname "$0")/optimize_texture.sh" \
            -i "$file" \
            -o "$OUTPUT_DIR/textures" \
            -f pvr \
            -q "$QUALITY" \
            ${VERBOSE:+-v} >> "$LOG_FILE" 2>&1
    else
        echo -e "${YELLOW}  Warning: optimize_texture.sh not found, skipping${NC}"
    fi
}

# Function to process model files
process_model() {
    local file="$1"
    local basename=$(basename "$file" | sed 's/\.[^.]*$//')
    
    echo -e "${BLUE}Processing model: $file${NC}"
    
    if [ "$DRY_RUN" = true ]; then
        echo "  Would convert to: $OUTPUT_DIR/models/${basename}.dcm"
        return
    fi
    
    # Use optimize_model.sh if available
    if [ -x "$(dirname "$0")/optimize_model.sh" ]; then
        "$(dirname "$0")/optimize_model.sh" \
            -i "$file" \
            -o "$OUTPUT_DIR/models" \
            -f dcm \
            ${VERBOSE:+-V} >> "$LOG_FILE" 2>&1
    else
        echo -e "${YELLOW}  Warning: optimize_model.sh not found, skipping${NC}"
    fi
}

# Function to process audio files
process_audio() {
    local file="$1"
    local basename=$(basename "$file" | sed 's/\.[^.]*$//')
    
    echo -e "${BLUE}Processing audio: $file${NC}"
    
    if [ "$DRY_RUN" = true ]; then
        echo "  Would convert to: $OUTPUT_DIR/audio/${basename}.adx"
        return
    fi
    
    # Convert to WAV first if needed
    local wav_file="$OUTPUT_DIR/audio/${basename}.wav"
    
    if [[ "$file" != *.wav ]]; then
        log "  Converting to WAV..."
        ffmpeg -i "$file" -ar 22050 -ac 1 "$wav_file" -y >> "$LOG_FILE" 2>&1
    else
        cp "$file" "$wav_file"
    fi
    
    # Convert to ADPCM
    if command -v adxtool &> /dev/null; then
        log "  Converting to ADPCM..."
        adxtool -e "$wav_file" "$OUTPUT_DIR/audio/${basename}.adx" >> "$LOG_FILE" 2>&1
        rm -f "$wav_file"
    else
        echo -e "${YELLOW}  Warning: adxtool not found, keeping WAV format${NC}"
    fi
}

# Function to process files in parallel
export -f process_image process_model process_audio log
export OUTPUT_DIR LOG_FILE QUALITY VERBOSE DRY_RUN

# Convert file types to find pattern
IFS=',' read -ra TYPES <<< "$FILE_TYPES"
FIND_PATTERN=""
for type in "${TYPES[@]}"; do
    type=$(echo "$type" | xargs)  # Trim whitespace
    if [ -n "$FIND_PATTERN" ]; then
        FIND_PATTERN="$FIND_PATTERN -o"
    fi
    FIND_PATTERN="$FIND_PATTERN -iname '*.$type'"
done

echo -e "${GREEN}Dreamcast Batch Asset Converter${NC}"
echo "================================="
echo "Input directory: $INPUT_DIR"
echo "Output directory: $OUTPUT_DIR"
echo "Quality preset: $QUALITY"
echo "Parallel jobs: $PARALLEL_JOBS"
echo ""

# Count files to process
TOTAL_FILES=$(eval "find '$INPUT_DIR' \( $FIND_PATTERN \)" | wc -l)
echo "Found $TOTAL_FILES files to process"

if [ "$TOTAL_FILES" -eq 0 ]; then
    echo -e "${YELLOW}No files found matching the specified types${NC}"
    exit 0
fi

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}DRY RUN MODE - No files will be converted${NC}"
    echo ""
fi

# Process each file type
echo ""
echo "Processing images..."
eval "find '$INPUT_DIR' \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.bmp' -o -iname '*.tga' -o -iname '*.tiff' -o -iname '*.gif' \)" | \
    xargs -P "$PARALLEL_JOBS" -I {} bash -c 'process_image "$@"' _ {}

echo ""
echo "Processing models..."
eval "find '$INPUT_DIR' \( -iname '*.obj' -o -iname '*.fbx' -o -iname '*.3ds' -o -iname '*.dae' -o -iname '*.stl' -o -iname '*.ply' -o -iname '*.gltf' -o -iname '*.glb' \)" | \
    xargs -P "$PARALLEL_JOBS" -I {} bash -c 'process_model "$@"' _ {}

echo ""
echo "Processing audio..."
eval "find '$INPUT_DIR' \( -iname '*.wav' -o -iname '*.mp3' -o -iname '*.ogg' -o -iname '*.flac' -o -iname '*.aiff' -o -iname '*.m4a' \)" | \
    xargs -P "$PARALLEL_JOBS" -I {} bash -c 'process_audio "$@"' _ {}

# Generate summary report
if [ "$DRY_RUN" = false ]; then
    echo ""
    echo "Generating conversion report..."
    
    REPORT_FILE="$OUTPUT_DIR/conversion_report.txt"
    {
        echo "Dreamcast Asset Conversion Report"
        echo "================================="
        echo "Date: $(date)"
        echo "Input: $INPUT_DIR"
        echo "Output: $OUTPUT_DIR"
        echo ""
        echo "Converted Assets:"
        echo "-----------------"
        echo "Textures: $(find "$OUTPUT_DIR/textures" -name "*.pvr" 2>/dev/null | wc -l)"
        echo "Models: $(find "$OUTPUT_DIR/models" -name "*.dcm" 2>/dev/null | wc -l)"
        echo "Audio: $(find "$OUTPUT_DIR/audio" -name "*.adx" -o -name "*.wav" 2>/dev/null | wc -l)"
        echo ""
        echo "Total size: $(du -sh "$OUTPUT_DIR" | cut -f1)"
    } > "$REPORT_FILE"
    
    cat "$REPORT_FILE"
fi

echo ""
echo -e "${GREEN}✅ Batch conversion complete!${NC}"

if [ "$DRY_RUN" = false ]; then
    echo "Output directory: $OUTPUT_DIR"
    echo "Log file: $LOG_FILE"
    echo "Report: $REPORT_FILE"
fi
