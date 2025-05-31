#!/bin/bash

# Dreamcast model optimization script
# Converts and optimizes 3D models for Dreamcast hardware

set -e

# Default values
INPUT_FILE=""
OUTPUT_DIR="."
FORMAT="dcm"
MAX_VERTICES=65536
MAX_POLYGONS=32768
OPTIMIZE=true
VERBOSE=false

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Usage function
usage() {
    cat << EOF
Usage: $0 -i INPUT_FILE [-o OUTPUT_DIR] [-f FORMAT] [-v MAX_VERTICES] [-p MAX_POLYGONS] [-n] [-V]

Optimize 3D models for Dreamcast hardware.

Options:
    -i INPUT_FILE      Input model file (required)
    -o OUTPUT_DIR      Output directory (default: current directory)
    -f FORMAT          Output format: dcm, obj (default: dcm)
    -v MAX_VERTICES    Maximum vertices (default: 65536)
    -p MAX_POLYGONS    Maximum polygons (default: 32768)
    -n                 No optimization (keep original geometry)
    -V                 Verbose output
    -h                 Show this help message

Supported input formats:
    - OBJ, FBX, 3DS, DAE, STL, PLY, GLTF, GLB

Examples:
    $0 -i model.fbx -o output/ -v 10000
    $0 -i character.obj -f dcm -p 5000

EOF
    exit 1
}

# Parse command line arguments
while getopts "i:o:f:v:p:nVh" opt; do
    case $opt in
        i) INPUT_FILE="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        f) FORMAT="$OPTARG" ;;
        v) MAX_VERTICES="$OPTARG" ;;
        p) MAX_POLYGONS="$OPTARG" ;;
        n) OPTIMIZE=false ;;
        V) VERBOSE=true ;;
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

# Function to log messages
log() {
    if [ "$VERBOSE" = true ]; then
        echo -e "$1"
    fi
}

echo -e "${GREEN}Optimizing model: $INPUT_FILE${NC}"

# Create temporary working directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# First, convert to OBJ format using assimp for consistency
TEMP_OBJ="$TEMP_DIR/${BASENAME}_temp.obj"

log "Converting to intermediate OBJ format..."
if command -v assimp &> /dev/null; then
    ASSIMP_ARGS=""
    
    if [ "$OPTIMIZE" = true ]; then
        # Optimization flags for assimp
        ASSIMP_ARGS="$ASSIMP_ARGS --optimize-meshes"
        ASSIMP_ARGS="$ASSIMP_ARGS --remove-redundant-materials"
        ASSIMP_ARGS="$ASSIMP_ARGS --find-degenerates"
        ASSIMP_ARGS="$ASSIMP_ARGS --join-identical-vertices"
        ASSIMP_ARGS="$ASSIMP_ARGS --improve-cache-locality"
    fi
    
    assimp export "$INPUT_FILE" "$TEMP_OBJ" $ASSIMP_ARGS 2>/dev/null || {
        echo -e "${RED}Error: Failed to convert model${NC}"
        exit 1
    }
else
    echo -e "${RED}Error: assimp not found. Please install assimp.${NC}"
    exit 1
fi

# Parse OBJ file to get statistics
VERTEX_COUNT=0
FACE_COUNT=0
UV_COUNT=0
NORMAL_COUNT=0

while IFS= read -r line; do
    case "$line" in
        v\ *) ((VERTEX_COUNT++)) ;;
        f\ *) ((FACE_COUNT++)) ;;
        vt\ *) ((UV_COUNT++)) ;;
        vn\ *) ((NORMAL_COUNT++)) ;;
    esac
done < "$TEMP_OBJ"

log "Model statistics:"
log "  Vertices: $VERTEX_COUNT"
log "  Faces: $FACE_COUNT"
log "  UVs: $UV_COUNT"
log "  Normals: $NORMAL_COUNT"

# Check if optimization is needed
NEEDS_REDUCTION=false
if [ $VERTEX_COUNT -gt $MAX_VERTICES ] || [ $FACE_COUNT -gt $MAX_POLYGONS ]; then
    NEEDS_REDUCTION=true
    echo -e "${YELLOW}Model exceeds limits, reduction needed${NC}"
fi

# Apply polygon reduction if needed
if [ "$NEEDS_REDUCTION" = true ] && [ "$OPTIMIZE" = true ]; then
    log "Applying polygon reduction..."
    
    # Calculate reduction ratio
    VERTEX_RATIO=$(echo "scale=4; $MAX_VERTICES / $VERTEX_COUNT" | bc)
    FACE_RATIO=$(echo "scale=4; $MAX_POLYGONS / $FACE_COUNT" | bc)
    RATIO=$(echo "scale=4; if ($VERTEX_RATIO < $FACE_RATIO) $VERTEX_RATIO else $FACE_RATIO" | bc)
    
    if (( $(echo "$RATIO < 1.0" | bc -l) )); then
        # Use meshlab or other tool for reduction if available
        # For now, we'll just warn
        echo -e "${YELLOW}Warning: Model needs ${RATIO}x reduction${NC}"
        echo -e "${YELLOW}Consider using a 3D modeling tool to reduce polygon count${NC}"
    fi
fi

# Convert to requested format
case $FORMAT in
    dcm)
        OUTPUT_FILE="$OUTPUT_DIR/${BASENAME}.dcm"
        log "Converting to DCM format..."
        
        # Create DCM file
        python3 << EOF
import struct

def obj_to_dcm(obj_file, dcm_file):
    vertices = []
    faces = []
    uvs = []
    
    # Parse OBJ file
    with open(obj_file, 'r') as f:
        for line in f:
            parts = line.strip().split()
            if not parts:
                continue
                
            if parts[0] == 'v':
                vertices.append([float(parts[1]), float(parts[2]), float(parts[3])])
            elif parts[0] == 'vt':
                uvs.append([float(parts[1]), float(parts[2])])
            elif parts[0] == 'f':
                # Parse face (assuming triangles)
                face = []
                for vertex in parts[1:4]:
                    indices = vertex.split('/')
                    face.append(int(indices[0]) - 1)  # OBJ is 1-indexed
                faces.append(face)
    
    # Write DCM file
    with open(dcm_file, 'wb') as f:
        # Header
        f.write(b'DCM\x01')  # Magic + version
        
        # Vertex count
        f.write(struct.pack('<I', len(vertices)))
        
        # Write vertices
        for v in vertices:
            f.write(struct.pack('<fff', v[0], v[1], v[2]))
        
        # Face count
        f.write(struct.pack('<I', len(faces)))
        
        # Write faces
        for face in faces:
            f.write(struct.pack('<HHH', face[0], face[1], face[2]))
        
        # UV count
        f.write(struct.pack('<I', len(uvs)))
        
        # Write UVs
        for uv in uvs:
            f.write(struct.pack('<ff', uv[0], uv[1]))
    
    print(f"Created DCM file with {len(vertices)} vertices and {len(faces)} faces")

obj_to_dcm("$TEMP_OBJ", "$OUTPUT_FILE")
EOF
        ;;
        
    obj)
        OUTPUT_FILE="$OUTPUT_DIR/${BASENAME}_optimized.obj"
        log "Saving as OBJ format..."
        cp "$TEMP_OBJ" "$OUTPUT_FILE"
        ;;
        
    *)
        echo -e "${RED}Error: Unknown format '$FORMAT'${NC}"
        exit 1
        ;;
esac

# Add metadata file
METADATA_FILE="$OUTPUT_DIR/${BASENAME}.meta"
cat > "$METADATA_FILE" << EOF
{
    "source_file": "$INPUT_FILE",
    "output_format": "$FORMAT",
    "vertices": $VERTEX_COUNT,
    "faces": $FACE_COUNT,
    "uvs": $UV_COUNT,
    "normals": $NORMAL_COUNT,
    "optimized": $OPTIMIZE,
    "max_vertices": $MAX_VERTICES,
    "max_polygons": $MAX_POLYGONS,
    "conversion_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

# Report results
if [ -f "$OUTPUT_FILE" ]; then
    SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE")
    SIZE_KB=$((SIZE / 1024))
    echo -e "${GREEN}✅ Model optimized successfully!${NC}"
    echo "   Output: $OUTPUT_FILE"
    echo "   Size: ${SIZE_KB}KB"
    echo "   Vertices: $VERTEX_COUNT"
    echo "   Faces: $FACE_COUNT"
    echo "   Format: $FORMAT"
    
    if [ "$NEEDS_REDUCTION" = true ] && [ "$OPTIMIZE" = true ]; then
        echo -e "${YELLOW}   Note: Model may still exceed recommended limits${NC}"
    fi
else
    echo -e "${RED}❌ Failed to create output file${NC}"
    exit 1
fi
