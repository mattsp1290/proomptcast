#!/bin/bash

# Dreamcast texture optimization script
# Converts and optimizes textures for Dreamcast hardware

set -e

# Default values
INPUT_FILE=""
OUTPUT_DIR="."
MAX_SIZE=512
FORMAT="pvr"
QUALITY="high"
VERBOSE=false

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Usage function
usage() {
    cat << EOF
Usage: $0 -i INPUT_FILE [-o OUTPUT_DIR] [-s MAX_SIZE] [-f FORMAT] [-q QUALITY] [-v]

Optimize textures for Dreamcast hardware.

Options:
    -i INPUT_FILE   Input texture file (required)
    -o OUTPUT_DIR   Output directory (default: current directory)
    -s MAX_SIZE     Maximum texture size (default: 512)
    -f FORMAT       Output format: pvr, vq (default: pvr)
    -q QUALITY      Compression quality: low, medium, high (default: high)
    -v              Verbose output
    -h              Show this help message

Examples:
    $0 -i texture.png -o output/ -s 256 -f pvr
    $0 -i sprite_sheet.jpg -f vq -q medium

EOF
    exit 1
}

# Parse command line arguments
while getopts "i:o:s:f:q:vh" opt; do
    case $opt in
        i) INPUT_FILE="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        s) MAX_SIZE="$OPTARG" ;;
        f) FORMAT="$OPTARG" ;;
        q) QUALITY="$OPTARG" ;;
        v) VERBOSE=true ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Validate required arguments
if [ -z "$INPUT_FILE" ]; then
    echo -e "${RED}Error: Input file is required${NC}"
    usage
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}Error: Input file does not exist: $INPUT_FILE${NC}"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Get input filename without extension
BASENAME=$(basename "$INPUT_FILE" | sed 's/\.[^.]*$//')

# Function to get nearest power of 2
nearest_pow2() {
    local n=$1
    local pow2=1
    while [ $pow2 -lt $n ]; do
        pow2=$((pow2 * 2))
    done
    echo $pow2
}

# Function to log messages
log() {
    if [ "$VERBOSE" = true ]; then
        echo -e "$1"
    fi
}

echo -e "${GREEN}Optimizing texture: $INPUT_FILE${NC}"

# Get image dimensions
DIMENSIONS=$(identify -format "%wx%h" "$INPUT_FILE" 2>/dev/null)
WIDTH=$(echo $DIMENSIONS | cut -d'x' -f1)
HEIGHT=$(echo $DIMENSIONS | cut -d'x' -f2)

log "Original dimensions: ${WIDTH}x${HEIGHT}"

# Calculate power-of-2 dimensions
NEW_WIDTH=$(nearest_pow2 $WIDTH)
NEW_HEIGHT=$(nearest_pow2 $HEIGHT)

# Limit to maximum size
if [ $NEW_WIDTH -gt $MAX_SIZE ]; then
    NEW_WIDTH=$MAX_SIZE
fi
if [ $NEW_HEIGHT -gt $MAX_SIZE ]; then
    NEW_HEIGHT=$MAX_SIZE
fi

log "Target dimensions: ${NEW_WIDTH}x${NEW_HEIGHT}"

# Create temporary resized image
TEMP_FILE="/tmp/${BASENAME}_resized.png"

# Resize image to power-of-2 dimensions
log "Resizing image..."
convert "$INPUT_FILE" \
    -resize "${NEW_WIDTH}x${NEW_HEIGHT}!" \
    -filter Lanczos \
    "$TEMP_FILE"

# Apply optimization based on quality setting
case $QUALITY in
    low)
        OPTIMIZE_ARGS="-quality 60 -colors 128"
        ;;
    medium)
        OPTIMIZE_ARGS="-quality 80 -colors 256"
        ;;
    high)
        OPTIMIZE_ARGS="-quality 95"
        ;;
    *)
        echo -e "${YELLOW}Warning: Unknown quality '$QUALITY', using high${NC}"
        OPTIMIZE_ARGS="-quality 95"
        ;;
esac

# Apply optimization
log "Applying optimization (quality: $QUALITY)..."
convert "$TEMP_FILE" $OPTIMIZE_ARGS "$TEMP_FILE"

# Convert to requested format
case $FORMAT in
    pvr)
        OUTPUT_FILE="$OUTPUT_DIR/${BASENAME}.pvr"
        log "Converting to PVR format..."
        
        # Convert to raw RGB565 first
        RAW_FILE="/tmp/${BASENAME}.raw"
        convert "$TEMP_FILE" -depth 16 RGB565:"$RAW_FILE"
        
        # Use pvr_converter if available
        if command -v pvr_converter &> /dev/null; then
            pvr_converter "$RAW_FILE" "$OUTPUT_FILE"
        else
            # Fallback: create simple PVR header
            log "Using fallback PVR creation..."
            {
                # PVR header
                printf "PVRV"                          # Magic
                printf "\x08\x00\x00\x00"             # Header size
                printf "\x%02x\x%02x" $((NEW_WIDTH & 0xFF)) $((NEW_WIDTH >> 8))
                printf "\x%02x\x%02x" $((NEW_HEIGHT & 0xFF)) $((NEW_HEIGHT >> 8))
                printf "\x01"                          # RGB565 format
                printf "\x01"                          # Square twiddled
                printf "\x00\x00"                      # Padding
                cat "$RAW_FILE"
            } > "$OUTPUT_FILE"
        fi
        
        rm -f "$RAW_FILE"
        ;;
        
    vq)
        OUTPUT_FILE="$OUTPUT_DIR/${BASENAME}.vq"
        log "Converting to VQ format..."
        
        # VQ compression would go here
        # For now, create a placeholder
        echo "VQ compressed texture (placeholder)" > "${OUTPUT_FILE}.info"
        cp "$TEMP_FILE" "$OUTPUT_FILE.png"
        
        echo -e "${YELLOW}Note: VQ compression not yet implemented${NC}"
        ;;
        
    *)
        echo -e "${RED}Error: Unknown format '$FORMAT'${NC}"
        rm -f "$TEMP_FILE"
        exit 1
        ;;
esac

# Clean up temporary file
rm -f "$TEMP_FILE"

# Report results
if [ -f "$OUTPUT_FILE" ]; then
    SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE")
    SIZE_KB=$((SIZE / 1024))
    echo -e "${GREEN}✅ Texture optimized successfully!${NC}"
    echo "   Output: $OUTPUT_FILE"
    echo "   Size: ${SIZE_KB}KB"
    echo "   Dimensions: ${NEW_WIDTH}x${NEW_HEIGHT}"
    echo "   Format: $FORMAT"
else
    echo -e "${RED}❌ Failed to create output file${NC}"
    exit 1
fi
