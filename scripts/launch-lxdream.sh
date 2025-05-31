#!/bin/bash
# Elite lxdream launcher with debugging and multi-player support

set -euo pipefail

# Parse arguments
GAME_FILE="$1"
DEBUG_MODE="${2:-false}"
GDB_PORT="${3:-1234}"
WAIT_FOR_DEBUGGER="${4:-false}"
HEADLESS="${5:-false}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[LXDREAM]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[LXDREAM]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[LXDREAM]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[LXDREAM]${NC} $1" >&2
}

# Get project root
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Configuration paths
LXDREAM_CONFIG="$PROJECT_ROOT/config/emulators/lxdream/lxdream.cfg"
LXDREAM_USER_CONFIG="$HOME/.lxdream/lxdreamrc"
INPUT_CONFIG="${DREAMCAST_INPUT_CONFIG:-$PROJECT_ROOT/config/emulators/input-profiles/default.json}"

# Check if lxdream is installed
if ! command -v lxdream &> /dev/null; then
    log_error "lxdream not found!"
    log_info "Please run: $PROJECT_ROOT/scripts/emulators/install-lxdream-macos.sh"
    exit 1
fi

# Check for BIOS files
BIOS_DIR="$HOME/.lxdream"
if [[ ! -f "$BIOS_DIR/dc_boot.bin" ]] || [[ ! -f "$BIOS_DIR/dc_flash.bin" ]]; then
    log_warn "Dreamcast BIOS files not found in $BIOS_DIR"
    log_info "lxdream may not function properly without BIOS files"
    log_info "Place dc_boot.bin and dc_flash.bin in: $BIOS_DIR/"
fi

# Create temporary configuration if project config exists
TEMP_CONFIG=""
if [[ -f "$LXDREAM_CONFIG" ]]; then
    # Merge project config with user config
    TEMP_CONFIG="/tmp/lxdream-config-$$.cfg"
    cp "$LXDREAM_CONFIG" "$TEMP_CONFIG"

    # Apply player count configuration
    PLAYERS="${DREAMCAST_PLAYERS:-1}"
    log_info "Configuring for $PLAYERS player(s)"

    # Configure input devices based on player count
    for i in $(seq 1 4); do
        if [[ $i -le $PLAYERS ]]; then
            echo "input.device$i = keyboard" >> "$TEMP_CONFIG"
        else
            echo "input.device$i = none" >> "$TEMP_CONFIG"
        fi
    done

    # Add debug settings if in debug mode
    if [[ "$DEBUG_MODE" == "true" ]]; then
        cat >> "$TEMP_CONFIG" << EOF

# Debug mode settings
gdb.enabled = 1
gdb.port = $GDB_PORT
gdb.wait = $(if [[ "$WAIT_FOR_DEBUGGER" == "true" ]]; then echo 1; else echo 0; fi)
debug.level = 3
debug.modules = CPU,MMU,SH4,AICA,PVR2,MAPLE
EOF
    fi

    CONFIG_ARGS="-c $TEMP_CONFIG"
else
    CONFIG_ARGS=""
    if [[ -f "$LXDREAM_USER_CONFIG" ]]; then
        CONFIG_ARGS="-c $LXDREAM_USER_CONFIG"
    fi
fi

# Build lxdream command
LXDREAM_CMD="lxdream"
LXDREAM_ARGS=()

# Add configuration file if available
if [[ -n "$CONFIG_ARGS" ]]; then
    LXDREAM_ARGS+=($CONFIG_ARGS)
fi

# Add debug options
if [[ "$DEBUG_MODE" == "true" ]]; then
    log_info "Starting in debug mode on port $GDB_PORT"
    LXDREAM_ARGS+=("-g" "$GDB_PORT")

    if [[ "$WAIT_FOR_DEBUGGER" == "true" ]]; then
        log_info "Waiting for debugger connection..."
        log_info "Connect with: sh-elf-gdb -ex 'target remote localhost:$GDB_PORT' $GAME_FILE"
    fi
fi

# Add headless mode if requested
if [[ "$HEADLESS" == "true" ]]; then
    log_info "Running in headless mode"
    LXDREAM_ARGS+=("-A" "null" "-V" "null")
fi

# Add game file
LXDREAM_ARGS+=("$GAME_FILE")

# Set up environment for input handling
export LXDREAM_INPUT_CONFIG="$INPUT_CONFIG"

# Create a wrapper script for input injection (for testing)
if [[ -f "$INPUT_CONFIG" ]] && command -v jq &> /dev/null; then
    # Parse input configuration and set up keyboard mappings
    log_info "Loading input configuration from: $(basename "$INPUT_CONFIG")"

    # Export keyboard mappings for lxdream to use
    # This would require a more sophisticated input handling system
    # For now, we'll rely on lxdream's built-in keyboard mapping
fi

# Launch lxdream
log_info "Launching lxdream..."
log_info "Command: $LXDREAM_CMD ${LXDREAM_ARGS[@]}"

# For debugging output
if [[ "$DEBUG_MODE" == "true" ]]; then
    # Create a log file for debug output
    DEBUG_LOG="/tmp/lxdream-debug-$$.log"
    log_info "Debug log: $DEBUG_LOG"

    # Launch with output capture
    $LXDREAM_CMD "${LXDREAM_ARGS[@]}" 2>&1 | tee "$DEBUG_LOG"
    EXIT_CODE=${PIPESTATUS[0]}
else
    # Normal launch
    $LXDREAM_CMD "${LXDREAM_ARGS[@]}"
    EXIT_CODE=$?
fi

# Cleanup
if [[ -n "$TEMP_CONFIG" ]] && [[ -f "$TEMP_CONFIG" ]]; then
    rm -f "$TEMP_CONFIG"
fi

# Report exit status
if [[ $EXIT_CODE -eq 0 ]]; then
    log_success "lxdream exited successfully"
else
    log_error "lxdream exited with code: $EXIT_CODE"
    if [[ "$DEBUG_MODE" == "true" ]] && [[ -f "$DEBUG_LOG" ]]; then
        log_info "Check debug log: $DEBUG_LOG"
    fi
fi

exit $EXIT_CODE
