#!/bin/bash
set -e

echo "🔍 Validating Dreamcast Toolchain..."
echo "=================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track validation status
VALIDATION_PASSED=true

# Function to check if a command exists
check_command() {
    local cmd=$1
    local description=$2
    
    if command -v "$cmd" &> /dev/null; then
        echo -e "${GREEN}✅ $description found: $(command -v $cmd)${NC}"
        return 0
    else
        echo -e "${RED}❌ $description not found!${NC}"
        VALIDATION_PASSED=false
        return 1
    fi
}

# Function to check environment variable
check_env() {
    local var=$1
    local description=$2
    
    if [ -n "${!var}" ]; then
        echo -e "${GREEN}✅ $description set: ${!var}${NC}"
        return 0
    else
        echo -e "${RED}❌ $description not set!${NC}"
        VALIDATION_PASSED=false
        return 1
    fi
}

# Function to check file/directory exists
check_path() {
    local path=$1
    local description=$2
    
    if [ -e "$path" ]; then
        echo -e "${GREEN}✅ $description exists: $path${NC}"
        return 0
    else
        echo -e "${RED}❌ $description not found: $path${NC}"
        VALIDATION_PASSED=false
        return 1
    fi
}

echo "1. Checking environment variables..."
echo "------------------------------------"
check_env "KOS_BASE" "KallistiOS base directory"
check_env "KOS_PORTS" "KallistiOS ports directory"
check_env "DC_TOOLS" "Dreamcast tools directory"
check_env "PATH" "PATH variable"

echo ""
echo "2. Checking SH4 toolchain..."
echo "-----------------------------"
check_command "sh-elf-gcc" "SH4 GCC compiler"
check_command "sh-elf-g++" "SH4 G++ compiler"
check_command "sh-elf-as" "SH4 assembler"
check_command "sh-elf-ld" "SH4 linker"
check_command "sh-elf-ar" "SH4 archiver"
check_command "sh-elf-objcopy" "SH4 objcopy"
check_command "sh-elf-objdump" "SH4 objdump"
check_command "sh-elf-strip" "SH4 strip"
check_command "sh-elf-gdb" "SH4 GDB debugger"
check_command "sh-elf-gprof" "SH4 profiler"

# Check ARM toolchain for sound processor
echo ""
echo "3. Checking ARM toolchain..."
echo "-----------------------------"
if check_command "arm-eabi-gcc" "ARM GCC compiler"; then
    check_command "arm-eabi-as" "ARM assembler"
    check_command "arm-eabi-ld" "ARM linker"
fi

echo ""
echo "4. Checking KallistiOS installation..."
echo "--------------------------------------"
if [ -n "$KOS_BASE" ]; then
    check_path "$KOS_BASE/environ.sh" "KallistiOS environment script"
    check_path "$KOS_BASE/include/kos.h" "KallistiOS headers"
    check_path "$KOS_BASE/lib/libkallisti.a" "KallistiOS library"
    check_path "$KOS_BASE/kernel/arch/dreamcast" "Dreamcast architecture files"
    
    # Check raylib4Dreamcast
    check_path "$KOS_BASE/include/raylib/raylib.h" "raylib4Dreamcast headers"
    check_path "$KOS_BASE/lib/libraylib.a" "raylib4Dreamcast library"
fi

echo ""
echo "5. Checking asset conversion tools..."
echo "-------------------------------------"
check_command "pvr_converter" "PVR texture converter"
check_command "img2ktx" "KTX texture converter"
check_command "adxtool" "ADPCM audio converter"
check_command "assimp" "3D model converter"
check_command "img4dc" "Dreamcast image creator"
check_command "mkdcdisc" "Dreamcast disc creator"
check_command "convert" "ImageMagick"
check_command "sox" "SoX audio processor"
check_command "ffmpeg" "FFmpeg"

echo ""
echo "6. Checking Python environment..."
echo "---------------------------------"
check_command "python3" "Python 3"
check_command "pip3" "pip package manager"

# Check Python packages
echo "Checking Python packages..."
python3 -c "import unitypack" 2>/dev/null && \
    echo -e "${GREEN}✅ unitypack module found${NC}" || \
    echo -e "${YELLOW}⚠️  unitypack module not found (optional)${NC}"

python3 -c "import PIL" 2>/dev/null && \
    echo -e "${GREEN}✅ PIL/Pillow module found${NC}" || \
    echo -e "${RED}❌ PIL/Pillow module not found${NC}"

python3 -c "import numpy" 2>/dev/null && \
    echo -e "${GREEN}✅ numpy module found${NC}" || \
    echo -e "${RED}❌ numpy module not found${NC}"

echo ""
echo "7. Testing compilation..."
echo "-------------------------"

# Create a temporary test file
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

cat > test.c << 'EOF'
#include <kos.h>
#include <stdio.h>

int main(int argc, char *argv[]) {
    printf("Dreamcast toolchain test successful!\n");
    vid_set_mode(DM_640x480, PM_RGB565);
    return 0;
}
EOF

echo "Attempting to compile test program..."

# Source KallistiOS environment
if [ -f "$KOS_BASE/environ.sh" ]; then
    source "$KOS_BASE/environ.sh"
    
    # Try to compile
    if sh-elf-gcc -o test.elf test.c -lkallisti -lc 2>/dev/null; then
        echo -e "${GREEN}✅ Compilation test passed!${NC}"
        
        # Check binary
        if sh-elf-objdump -h test.elf >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Binary validation passed!${NC}"
            
            # Show binary info
            echo "Binary information:"
            sh-elf-size test.elf
        fi
    else
        echo -e "${RED}❌ Compilation test failed!${NC}"
        VALIDATION_PASSED=false
        
        # Try to show error
        echo "Compilation error:"
        sh-elf-gcc -o test.elf test.c -lkallisti -lc 2>&1 | head -20
    fi
else
    echo -e "${RED}❌ Cannot source KallistiOS environment!${NC}"
    VALIDATION_PASSED=false
fi

# Test raylib compilation
echo ""
echo "Testing raylib4Dreamcast compilation..."

cat > test_raylib.c << 'EOF'
#include <kos.h>
#include <raylib/raylib.h>

int main(int argc, char *argv[]) {
    InitWindow(640, 480, "Dreamcast Raylib Test");
    
    while (!WindowShouldClose()) {
        BeginDrawing();
        ClearBackground(RAYWHITE);
        DrawText("Hello Dreamcast!", 10, 10, 20, BLACK);
        EndDrawing();
    }
    
    CloseWindow();
    return 0;
}
EOF

if sh-elf-gcc -o test_raylib.elf test_raylib.c -I${KOS_BASE}/include -L${KOS_BASE}/lib -lraylib -lkallisti -lc 2>/dev/null; then
    echo -e "${GREEN}✅ raylib compilation test passed!${NC}"
else
    echo -e "${YELLOW}⚠️  raylib compilation test failed (may need additional setup)${NC}"
fi

# Clean up
cd - >/dev/null
rm -rf "$TEMP_DIR"

echo ""
echo "8. Checking configuration files..."
echo "----------------------------------"
check_path "/etc/dreamcast/asset_pipeline.json" "Asset pipeline configuration"
check_path "/etc/dreamcast-toolchain-info" "Toolchain info file"

if [ -f "/etc/dreamcast-toolchain-info" ]; then
    echo ""
    echo "Toolchain information:"
    echo "---------------------"
    cat /etc/dreamcast-toolchain-info
fi

echo ""
echo "=================================="
if [ "$VALIDATION_PASSED" = true ]; then
    echo -e "${GREEN}🎉 All validation checks passed!${NC}"
    echo "The Dreamcast toolchain is properly installed and ready to use."
    exit 0
else
    echo -e "${RED}❌ Some validation checks failed!${NC}"
    echo "Please check the errors above and ensure all components are properly installed."
    exit 1
fi
