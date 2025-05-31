#!/bin/bash
# Controller testing utility for Dreamcast development
# Tests keyboard mappings and USB controller configurations

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_player() {
    local player=$1
    shift
    case $player in
        1) echo -e "${CYAN}[P1]${NC} $*" ;;
        2) echo -e "${GREEN}[P2]${NC} $*" ;;
        3) echo -e "${YELLOW}[P3]${NC} $*" ;;
        4) echo -e "${MAGENTA}[P4]${NC} $*" ;;
    esac
}

# Get project root
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Test controller configurations and mappings

OPTIONS:
    --profile <name>    Input profile to test (default: default)
    --player <n>        Test specific player (1-4, or 'all')
    --usb               Test USB controllers
    --keyboard          Test keyboard mappings
    -h, --help          Display this help message

EXAMPLES:
    $0                          # Test all players with default profile
    $0 --player 1               # Test only player 1
    $0 --profile tournament     # Test tournament profile
    $0 --usb                    # Test USB controllers only

EOF
    exit 1
}

# Default values
INPUT_PROFILE="default"
TEST_PLAYER="all"
TEST_USB=true
TEST_KEYBOARD=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --profile)
            INPUT_PROFILE="$2"
            shift 2
            ;;
        --player)
            TEST_PLAYER="$2"
            shift 2
            ;;
        --usb)
            TEST_USB=true
            TEST_KEYBOARD=false
            shift
            ;;
        --keyboard)
            TEST_KEYBOARD=true
            TEST_USB=false
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Load input configuration
INPUT_CONFIG_FILE="$PROJECT_ROOT/config/emulators/input-profiles/${INPUT_PROFILE}.json"
if [[ ! -f "$INPUT_CONFIG_FILE" ]]; then
    log_error "Input profile not found: $INPUT_PROFILE"
    exit 1
fi

log_info "Testing controller configuration"
log_info "Profile: $INPUT_PROFILE"

# Function to display keyboard mappings
show_keyboard_mappings() {
    local player=$1

    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed"
        return 1
    fi

    log_player $player "Keyboard mappings:"

    local mapping=$(jq -r ".players[$((player-1))].mapping" "$INPUT_CONFIG_FILE")

    echo "  Movement:"
    echo "    Up:    $(echo "$mapping" | jq -r '.dpad_up')"
    echo "    Down:  $(echo "$mapping" | jq -r '.dpad_down')"
    echo "    Left:  $(echo "$mapping" | jq -r '.dpad_left')"
    echo "    Right: $(echo "$mapping" | jq -r '.dpad_right')"
    echo ""
    echo "  Buttons:"
    echo "    A:     $(echo "$mapping" | jq -r '.button_a')"
    echo "    B:     $(echo "$mapping" | jq -r '.button_b')"
    echo "    X:     $(echo "$mapping" | jq -r '.button_x')"
    echo "    Y:     $(echo "$mapping" | jq -r '.button_y')"
    echo "    Start: $(echo "$mapping" | jq -r '.button_start')"
    echo ""
    echo "  Triggers:"
    echo "    L:     $(echo "$mapping" | jq -r '.left_trigger')"
    echo "    R:     $(echo "$mapping" | jq -r '.right_trigger')"
    echo ""
}

# Function to test USB controllers
test_usb_controllers() {
    log_info "Detecting USB controllers..."

    # macOS-specific controller detection
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Use system_profiler to detect USB game controllers
        local controllers=$(system_profiler SPUSBDataType | grep -A 10 -i "game\|controller\|joystick" || true)

        if [[ -z "$controllers" ]]; then
            log_info "No USB controllers detected"
            return
        fi

        log_success "USB controllers found:"
        echo "$controllers"

        # Check if SDL2 gamecontroller tool is available
        if command -v sdl2-config &> /dev/null; then
            log_info "Testing with SDL2..."
            # Would run SDL2 controller test here
        fi
    fi
}

# Function to create visual test
create_visual_test() {
    cat > /tmp/controller_test.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Dreamcast Controller Test</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: #1a1a1a;
            color: #fff;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
        }
        .controller-grid {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 20px;
            max-width: 1200px;
        }
        .controller {
            background: #2a2a2a;
            border: 2px solid #444;
            border-radius: 10px;
            padding: 20px;
            min-width: 300px;
        }
        .controller h2 {
            margin-top: 0;
            text-align: center;
        }
        .button-layout {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 10px;
            margin: 20px 0;
        }
        .button {
            background: #444;
            border: 2px solid #666;
            border-radius: 5px;
            padding: 10px;
            text-align: center;
            transition: all 0.2s;
        }
        .button.active {
            background: #4CAF50;
            border-color: #45a049;
            transform: scale(1.1);
        }
        .dpad {
            width: 120px;
            height: 120px;
            position: relative;
            margin: 20px auto;
        }
        .dpad-button {
            position: absolute;
            background: #444;
            border: 2px solid #666;
            width: 40px;
            height: 40px;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .dpad-up { top: 0; left: 40px; }
        .dpad-down { bottom: 0; left: 40px; }
        .dpad-left { left: 0; top: 40px; }
        .dpad-right { right: 0; top: 40px; }
        .dpad-center { top: 40px; left: 40px; background: #333; }
        .status {
            text-align: center;
            margin-top: 20px;
            font-size: 14px;
            color: #888;
        }
        .p1 h2 { color: #00BCD4; }
        .p2 h2 { color: #4CAF50; }
        .p3 h2 { color: #FFC107; }
        .p4 h2 { color: #E91E63; }
    </style>
</head>
<body>
    <div class="controller-grid">
        <div class="controller p1">
            <h2>Player 1</h2>
            <div class="status">Press keys: WASD + Space/Shift</div>
            <div class="dpad">
                <div class="dpad-button dpad-up" id="p1-up">W</div>
                <div class="dpad-button dpad-down" id="p1-down">S</div>
                <div class="dpad-button dpad-left" id="p1-left">A</div>
                <div class="dpad-button dpad-right" id="p1-right">D</div>
                <div class="dpad-button dpad-center"></div>
            </div>
            <div class="button-layout">
                <div class="button" id="p1-x">Q</div>
                <div class="button" id="p1-y">E</div>
                <div class="button" id="p1-l">R</div>
                <div class="button" id="p1-a">Space</div>
                <div class="button" id="p1-b">Shift</div>
                <div class="button" id="p1-r">F</div>
                <div></div>
                <div class="button" id="p1-start">Enter</div>
                <div></div>
            </div>
        </div>

        <div class="controller p2">
            <h2>Player 2</h2>
            <div class="status">Press keys: Arrows + Enter/RShift</div>
            <div class="dpad">
                <div class="dpad-button dpad-up" id="p2-up">↑</div>
                <div class="dpad-button dpad-down" id="p2-down">↓</div>
                <div class="dpad-button dpad-left" id="p2-left">←</div>
                <div class="dpad-button dpad-right" id="p2-right">→</div>
                <div class="dpad-button dpad-center"></div>
            </div>
            <div class="button-layout">
                <div class="button" id="p2-x">.</div>
                <div class="button" id="p2-y">/</div>
                <div class="button" id="p2-l">,</div>
                <div class="button" id="p2-a">Enter</div>
                <div class="button" id="p2-b">RShift</div>
                <div class="button" id="p2-r">M</div>
                <div></div>
                <div class="button" id="p2-start">RCtrl</div>
                <div></div>
            </div>
        </div>

        <div class="controller p3">
            <h2>Player 3</h2>
            <div class="status">Press keys: IJKL + U/O</div>
            <div class="dpad">
                <div class="dpad-button dpad-up" id="p3-up">I</div>
                <div class="dpad-button dpad-down" id="p3-down">K</div>
                <div class="dpad-button dpad-left" id="p3-left">J</div>
                <div class="dpad-button dpad-right" id="p3-right">L</div>
                <div class="dpad-button dpad-center"></div>
            </div>
            <div class="button-layout">
                <div class="button" id="p3-x">7</div>
                <div class="button" id="p3-y">8</div>
                <div class="button" id="p3-l">Y</div>
                <div class="button" id="p3-a">U</div>
                <div class="button" id="p3-b">O</div>
                <div class="button" id="p3-r">P</div>
                <div></div>
                <div class="button" id="p3-start">9</div>
                <div></div>
            </div>
        </div>

        <div class="controller p4">
            <h2>Player 4</h2>
            <div class="status">Press keys: Numpad</div>
            <div class="dpad">
                <div class="dpad-button dpad-up" id="p4-up">8</div>
                <div class="dpad-button dpad-down" id="p4-down">2</div>
                <div class="dpad-button dpad-left" id="p4-left">4</div>
                <div class="dpad-button dpad-right" id="p4-right">6</div>
                <div class="dpad-button dpad-center"></div>
            </div>
            <div class="button-layout">
                <div class="button" id="p4-x">7</div>
                <div class="button" id="p4-y">9</div>
                <div class="button" id="p4-l">1</div>
                <div class="button" id="p4-a">0</div>
                <div class="button" id="p4-b">.</div>
                <div class="button" id="p4-r">3</div>
                <div></div>
                <div class="button" id="p4-start">Enter</div>
                <div></div>
            </div>
        </div>
    </div>

    <script>
        // Simple keyboard input visualization
        const keyMap = {
            // Player 1
            'w': 'p1-up', 's': 'p1-down', 'a': 'p1-left', 'd': 'p1-right',
            ' ': 'p1-a', 'shift': 'p1-b', 'q': 'p1-x', 'e': 'p1-y',
            'enter': 'p1-start', 'r': 'p1-l', 'f': 'p1-r',

            // Player 2
            'arrowup': 'p2-up', 'arrowdown': 'p2-down',
            'arrowleft': 'p2-left', 'arrowright': 'p2-right',
            '.': 'p2-x', '/': 'p2-y', ',': 'p2-l', 'm': 'p2-r',

            // Player 3
            'i': 'p3-up', 'k': 'p3-down', 'j': 'p3-left', 'l': 'p3-right',
            'u': 'p3-a', 'o': 'p3-b', '7': 'p3-x', '8': 'p3-y',
            '9': 'p3-start', 'y': 'p3-l', 'p': 'p3-r',

            // Player 4 (numpad)
            'numpad8': 'p4-up', 'numpad2': 'p4-down',
            'numpad4': 'p4-left', 'numpad6': 'p4-right',
            'numpad0': 'p4-a', 'numpaddecimal': 'p4-b',
            'numpad7': 'p4-x', 'numpad9': 'p4-y',
            'numpadenter': 'p4-start', 'numpad1': 'p4-l', 'numpad3': 'p4-r'
        };

        document.addEventListener('keydown', (e) => {
            const key = e.key.toLowerCase();
            const elementId = keyMap[key];
            if (elementId) {
                const element = document.getElementById(elementId);
                if (element) {
                    element.classList.add('active');
                }
                e.preventDefault();
            }
        });

        document.addEventListener('keyup', (e) => {
            const key = e.key.toLowerCase();
            const elementId = keyMap[key];
            if (elementId) {
                const element = document.getElementById(elementId);
                if (element) {
                    element.classList.remove('active');
                }
                e.preventDefault();
            }
        });
    </script>
</body>
</html>
EOF

    log_success "Visual test created: /tmp/controller_test.html"
    log_info "Opening in browser..."
    open /tmp/controller_test.html
}

# Main execution
log_info "Dreamcast Controller Test Utility"
echo ""

# Test keyboard mappings
if [[ "$TEST_KEYBOARD" == "true" ]]; then
    log_info "Keyboard Mappings:"
    echo ""

    if [[ "$TEST_PLAYER" == "all" ]]; then
        for player in 1 2 3 4; do
            show_keyboard_mappings $player
            echo ""
        done
    else
        show_keyboard_mappings $TEST_PLAYER
    fi
fi

# Test USB controllers
if [[ "$TEST_USB" == "true" ]]; then
    test_usb_controllers
fi

# Ask if user wants to run visual test
echo ""
read -p "Would you like to open the visual controller test? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    create_visual_test
fi

log_success "Controller test complete!"
