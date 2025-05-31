#!/bin/bash
# Main emulator launcher for Dreamcast development
# Intelligently selects emulator and configuration based on parameters

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

# Default values
DEBUG_MODE=false
PLAYERS=1
EMULATOR="lxdream"
GAME_FILE=""
GDB_PORT=1234
INPUT_PROFILE="default"
HEADLESS=false
WAIT_FOR_DEBUGGER=false

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] <game-file>

Launch Dreamcast emulator with specified game file (.elf or .cdi)

OPTIONS:
    --debug             Enable GDB debugging mode
    --players <n>       Number of players (1-4)
    --emulator <name>   Choose emulator (lxdream, flycast)
    --input <profile>   Input profile (default, testing, tournament)
    --gdb-port <port>   GDB server port (default: 1234)
    --headless          Run without GUI (CI mode)
    --wait              Wait for debugger connection before starting
    -h, --help          Display this help message

EXAMPLES:
    $0 build/game.cdi
    $0 --debug build/game.elf
    $0 --players 4 --input tournament build/game.cdi
    $0 --debug --wait --gdb-port 2345 build/game.elf

EOF
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            DEBUG_MODE=true
            shift
            ;;
        --players)
            PLAYERS="$2"
            if [[ ! "$PLAYERS" =~ ^[1-4]$ ]]; then
                log_error "Invalid player count: $PLAYERS (must be 1-4)"
                exit 1
            fi
            shift 2
            ;;
        --emulator)
            EMULATOR="$2"
            shift 2
            ;;
        --input)
            INPUT_PROFILE="$2"
            shift 2
            ;;
        --gdb-port)
            GDB_PORT="$2"
            shift 2
            ;;
        --headless)
            HEADLESS=true
            shift
            ;;
        --wait)
            WAIT_FOR_DEBUGGER=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [[ -z "$GAME_FILE" ]]; then
                GAME_FILE="$1"
            else
                log_error "Unknown option: $1"
                usage
            fi
            shift
            ;;
    esac
done

# Validate game file
if [[ -z "$GAME_FILE" ]]; then
    log_error "No game file specified"
    usage
fi

if [[ ! -f "$GAME_FILE" ]]; then
    log_error "Game file not found: $GAME_FILE"
    exit 1
fi

# Get absolute path
GAME_FILE="$(cd "$(dirname "$GAME_FILE")" && pwd)/$(basename "$GAME_FILE")"

# Determine file type
FILE_EXT="${GAME_FILE##*.}"
case "$FILE_EXT" in
    elf)
        log_info "Detected ELF file - suitable for debugging"
        if [[ "$DEBUG_MODE" != "true" ]]; then
            log_warn "ELF files are typically used with --debug mode"
        fi
        ;;
    cdi|iso)
        log_info "Detected disc image file"
        if [[ "$DEBUG_MODE" == "true" ]]; then
            log_warn "Debug mode works better with ELF files"
        fi
        ;;
    *)
        log_error "Unknown file type: .$FILE_EXT"
        log_info "Supported types: .elf, .cdi, .iso"
        exit 1
        ;;
esac

# Check emulator availability
case "$EMULATOR" in
    lxdream)
        if ! command -v lxdream &> /dev/null; then
            log_error "lxdream not found. Run: ./scripts/emulators/install-lxdream-macos.sh"
            exit 1
        fi
        ;;
    flycast)
        if ! command -v flycast &> /dev/null; then
            log_error "Flycast not found. Run: ./scripts/emulators/install-flycast-macos.sh"
            exit 1
        fi
        ;;
    *)
        log_error "Unknown emulator: $EMULATOR"
        log_info "Available emulators: lxdream, flycast"
        exit 1
        ;;
esac

# Load input configuration
INPUT_CONFIG_FILE="${PROOMPTCAST_ROOT:-$(dirname "$0")/..}/config/emulators/input-profiles/${INPUT_PROFILE}.json"
if [[ ! -f "$INPUT_CONFIG_FILE" ]]; then
    log_warn "Input profile not found: $INPUT_PROFILE"
    log_info "Using default configuration"
    INPUT_CONFIG_FILE="${PROOMPTCAST_ROOT:-$(dirname "$0")/..}/config/emulators/input-profiles/default.json"
fi

# Launch emulator based on configuration
log_info "Launching $EMULATOR..."
log_info "Game: $(basename "$GAME_FILE")"
log_info "Players: $PLAYERS"
log_info "Debug mode: $DEBUG_MODE"
log_info "Input profile: $INPUT_PROFILE"

# Set up environment for multi-player
export DREAMCAST_PLAYERS="$PLAYERS"
export DREAMCAST_INPUT_CONFIG="$INPUT_CONFIG_FILE"

# Launch appropriate emulator
case "$EMULATOR" in
    lxdream)
        SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
        "$SCRIPT_DIR/launch-lxdream.sh" \
            "$GAME_FILE" \
            "$DEBUG_MODE" \
            "$GDB_PORT" \
            "$WAIT_FOR_DEBUGGER" \
            "$HEADLESS"
        ;;
    flycast)
        SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
        "$SCRIPT_DIR/launch-flycast.sh" \
            "$GAME_FILE" \
            "$DEBUG_MODE" \
            "$PLAYERS"
        ;;
esac

EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
    log_success "Emulator exited successfully"
else
    log_error "Emulator exited with code: $EXIT_CODE"
fi

exit $EXIT_CODE
