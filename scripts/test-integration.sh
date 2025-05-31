#!/bin/bash
# Elite integration testing framework for Dreamcast games
# Supports automated input sequences, state validation, and performance tracking

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[TEST]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_test() {
    echo -e "${CYAN}[RUN]${NC} $1" >&2
}

# Default values
TEST_SUITE=""
TEST_FILE=""
GAME_FILE=""
HEADLESS=true
CAPTURE_VIDEO=false
CAPTURE_SCREENSHOTS=true
OUTPUT_DIR="test-results"
EMULATOR="lxdream"
VERBOSE=false

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] <game-file>

Run automated integration tests for Dreamcast games

OPTIONS:
    --suite <name>      Test suite to run (multiplayer, performance, etc.)
    --test <file>       Specific test file to run
    --output <dir>      Output directory for results (default: test-results)
    --emulator <name>   Emulator to use (default: lxdream)
    --capture-video     Capture video of test execution
    --no-screenshots    Disable screenshot capture
    --gui               Run with GUI (not headless)
    --verbose           Enable verbose output
    -h, --help          Display this help message

EXAMPLES:
    $0 --suite multiplayer build/game.cdi
    $0 --test tests/integration/4player-join.yaml build/game.elf
    $0 --suite performance --capture-video build/game.cdi

EOF
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --suite)
            TEST_SUITE="$2"
            shift 2
            ;;
        --test)
            TEST_FILE="$2"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --emulator)
            EMULATOR="$2"
            shift 2
            ;;
        --capture-video)
            CAPTURE_VIDEO=true
            shift
            ;;
        --no-screenshots)
            CAPTURE_SCREENSHOTS=false
            shift
            ;;
        --gui)
            HEADLESS=false
            shift
            ;;
        --verbose)
            VERBOSE=true
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

# Get absolute paths
GAME_FILE="$(cd "$(dirname "$GAME_FILE")" && pwd)/$(basename "$GAME_FILE")"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Create output directory
mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TEST_RUN_DIR="$OUTPUT_DIR/run_$TIMESTAMP"
mkdir -p "$TEST_RUN_DIR"

# Initialize test report
REPORT_FILE="$TEST_RUN_DIR/report.json"
cat > "$REPORT_FILE" << EOF
{
    "timestamp": "$TIMESTAMP",
    "game_file": "$GAME_FILE",
    "emulator": "$EMULATOR",
    "tests": []
}
EOF

# Function to execute a single test
run_test() {
    local test_file="$1"
    local test_name="$(basename "$test_file" .yaml)"

    log_test "Running test: $test_name"

    # Create test output directory
    local test_output_dir="$TEST_RUN_DIR/$test_name"
    mkdir -p "$test_output_dir"

    # Parse test file (simplified YAML parsing)
    if ! command -v yq &> /dev/null; then
        log_warn "yq not found, using basic parsing"
        # Basic parsing implementation would go here
        return 1
    fi

    # Extract test steps
    local savestate=$(yq eval '.savestate' "$test_file")
    local steps=$(yq eval '.steps[]' "$test_file")

    # Prepare virtual input file
    local input_script="$test_output_dir/input_sequence.txt"
    echo "$steps" | while read -r step; do
        local action=$(echo "$step" | yq eval '.action' -)
        local frame=$(echo "$step" | yq eval '.frame' -)
        local value=$(echo "$step" | yq eval '.value' -)

        case "$action" in
            input)
                echo "FRAME:$frame INPUT:$value" >> "$input_script"
                ;;
            wait)
                echo "FRAME:$frame WAIT:$value" >> "$input_script"
                ;;
            screenshot)
                echo "FRAME:$frame SCREENSHOT:$test_output_dir/$value" >> "$input_script"
                ;;
            assert)
                echo "FRAME:$frame ASSERT:$value" >> "$input_script"
                ;;
        esac
    done

    # Launch emulator with test configuration
    local emulator_log="$test_output_dir/emulator.log"
    local test_start_time=$(date +%s)

    # Run emulator with input script
    DREAMCAST_TEST_MODE=1 \
    DREAMCAST_INPUT_SCRIPT="$input_script" \
    DREAMCAST_TEST_OUTPUT="$test_output_dir" \
    "$PROJECT_ROOT/scripts/run-emulator.sh" \
        --emulator "$EMULATOR" \
        --headless \
        --input testing \
        "$GAME_FILE" \
        > "$emulator_log" 2>&1

    local exit_code=$?
    local test_end_time=$(date +%s)
    local test_duration=$((test_end_time - test_start_time))

    # Analyze results
    local test_status="passed"
    local failure_reason=""

    if [[ $exit_code -ne 0 ]]; then
        test_status="failed"
        failure_reason="Emulator exited with code $exit_code"
    fi

    # Check assertions
    if [[ -f "$test_output_dir/assertions.log" ]]; then
        if grep -q "FAIL" "$test_output_dir/assertions.log"; then
            test_status="failed"
            failure_reason=$(grep "FAIL" "$test_output_dir/assertions.log" | head -1)
        fi
    fi

    # Update report
    local test_result=$(cat << EOF
{
    "name": "$test_name",
    "status": "$test_status",
    "duration": $test_duration,
    "failure_reason": "$failure_reason",
    "output_dir": "$test_output_dir"
}
EOF
)

    # Add to report (would use jq in production)
    echo "$test_result" >> "$TEST_RUN_DIR/test_results.jsonl"

    # Log result
    if [[ "$test_status" == "passed" ]]; then
        log_success "$test_name - ${test_duration}s"
    else
        log_error "$test_name - $failure_reason"
    fi

    return $([ "$test_status" == "passed" ] && echo 0 || echo 1)
}

# Function to run a test suite
run_suite() {
    local suite_name="$1"
    local suite_dir="$PROJECT_ROOT/tests/integration/$suite_name"

    if [[ ! -d "$suite_dir" ]]; then
        log_error "Test suite not found: $suite_name"
        return 1
    fi

    log_info "Running test suite: $suite_name"

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # Find all test files in suite
    while IFS= read -r -d '' test_file; do
        ((total_tests++))
        if run_test "$test_file"; then
            ((passed_tests++))
        else
            ((failed_tests++))
        fi
    done < <(find "$suite_dir" -name "*.yaml" -type f -print0)

    # Summary
    log_info "Suite complete: $passed_tests/$total_tests passed"

    return $([ $failed_tests -eq 0 ] && echo 0 || echo 1)
}

# Main execution
log_info "Starting integration tests"
log_info "Game: $(basename "$GAME_FILE")"
log_info "Output: $TEST_RUN_DIR"

# Start video capture if requested
if [[ "$CAPTURE_VIDEO" == "true" ]] && command -v ffmpeg &> /dev/null; then
    log_info "Starting video capture..."
    VIDEO_FILE="$TEST_RUN_DIR/test_run.mp4"
    # This would capture the screen - implementation depends on platform
    # For now, we'll skip actual implementation
fi

# Run tests
TEST_EXIT_CODE=0

if [[ -n "$TEST_FILE" ]]; then
    # Run single test
    if ! run_test "$TEST_FILE"; then
        TEST_EXIT_CODE=1
    fi
elif [[ -n "$TEST_SUITE" ]]; then
    # Run test suite
    if ! run_suite "$TEST_SUITE"; then
        TEST_EXIT_CODE=1
    fi
else
    # Run all tests
    log_info "Running all test suites..."
    for suite_dir in "$PROJECT_ROOT/tests/integration"/*; do
        if [[ -d "$suite_dir" ]]; then
            suite_name=$(basename "$suite_dir")
            if ! run_suite "$suite_name"; then
                TEST_EXIT_CODE=1
            fi
        fi
    done
fi

# Stop video capture
if [[ "$CAPTURE_VIDEO" == "true" ]]; then
    log_info "Stopping video capture..."
    # Stop ffmpeg process
fi

# Generate summary report
log_info "Generating test report..."
"$PROJECT_ROOT/scripts/generate-test-report.sh" "$TEST_RUN_DIR" || true

# Final summary
if [[ $TEST_EXIT_CODE -eq 0 ]]; then
    log_success "All tests passed!"
else
    log_error "Some tests failed"
fi

log_info "Full report: $TEST_RUN_DIR/report.html"

exit $TEST_EXIT_CODE
