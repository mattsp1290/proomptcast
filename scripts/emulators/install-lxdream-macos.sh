#!/bin/bash
# Elite lxdream installation script for macOS
# Builds from source with GDB debugging enabled

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    log_error "This script is designed for macOS only"
    exit 1
fi

log_info "Starting lxdream installation for macOS..."

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    log_error "Homebrew is required but not installed."
    log_info "Install it from https://brew.sh/"
    exit 1
fi

# Install dependencies
log_info "Installing dependencies via Homebrew..."
brew install \
    gtk+ \
    sdl2 \
    libpng \
    libjpeg \
    zlib \
    gettext \
    pkg-config \
    autoconf \
    automake \
    libtool \
    mercurial \
    || true

# Create build directory
BUILD_DIR="/tmp/lxdream-build"
INSTALL_PREFIX="/usr/local"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Clone lxdream repository
log_info "Cloning lxdream repository..."
if [[ -d "lxdream" ]]; then
    log_warn "Existing lxdream directory found, removing..."
    rm -rf lxdream
fi

# Clone from the official repository
hg clone http://www.lxdream.org/hg/lxdream || {
    log_error "Failed to clone lxdream repository"
    log_info "Trying alternative mirror..."
    git clone https://github.com/lxdream/lxdream.git || {
        log_error "Failed to clone from alternative source"
        exit 1
    }
}

cd lxdream

# Apply macOS compatibility patches
log_info "Applying macOS compatibility patches..."
cat > macos-compat.patch << 'EOF'
--- a/configure.ac
+++ b/configure.ac
@@ -50,7 +50,7 @@
 AC_DEFINE(HAVE_FASTCALL, [1], [Use fast register-passing calling convention])
 AC_DEFINE(HAVE_FRAME_ADDRESS, [1], [Define if the GNU __builtin_frame_address is available])

-CFLAGS="$CFLAGS -fno-strict-aliasing"
+CFLAGS="$CFLAGS -fno-strict-aliasing -Wno-deprecated-declarations"

 AC_ARG_ENABLE(optimized,
 AS_HELP_STRING([--disable-optimized], [Disable compile-time optimizations]),
@@ -120,6 +120,11 @@
     LIBS="$LIBS -framework Carbon -framework IOKit -framework OpenGL -framework AppKit"
     LDFLAGS="$LDFLAGS -Wl,-headerpad_max_install_names"
     AC_DEFINE([MACOSX], [1], [Building on Mac OS X])
+    # Fix for newer macOS versions
+    CFLAGS="$CFLAGS -Wno-error=implicit-function-declaration"
+    if test "$host_cpu" = "aarch64" -o "$host_cpu" = "arm64"; then
+        AC_DEFINE([APPLE_SILICON], [1], [Building on Apple Silicon])
+    fi
 fi

 # Check for GDB stub support
EOF

# Apply patch if it exists
if [[ -f "configure.ac" ]]; then
    patch -p1 < macos-compat.patch || log_warn "Patch may have already been applied"
fi

# Configure with debugging enabled
log_info "Configuring lxdream with GDB stub support..."
if [[ -f "autogen.sh" ]]; then
    ./autogen.sh
else
    autoreconf -fi
fi

# Configure with optimal settings for debugging
./configure \
    --prefix="$INSTALL_PREFIX" \
    --enable-trace \
    --enable-watch \
    --enable-gdb-stub \
    --with-gtk \
    --with-sdl \
    || {
        log_error "Configuration failed"
        exit 1
    }

# Build lxdream
log_info "Building lxdream (this may take a few minutes)..."
make -j$(sysctl -n hw.ncpu) || {
    log_error "Build failed"
    log_info "Attempting single-threaded build..."
    make clean
    make || {
        log_error "Single-threaded build also failed"
        exit 1
    }
}

# Install lxdream
log_info "Installing lxdream (may require sudo)..."
sudo make install || {
    log_error "Installation failed"
    exit 1
}

# Create default configuration directory
CONFIG_DIR="$HOME/.lxdream"
mkdir -p "$CONFIG_DIR"

# Create a default configuration optimized for debugging
log_info "Creating default configuration..."
cat > "$CONFIG_DIR/lxdreamrc" << EOF
# lxdream configuration - optimized for debugging
[global]
# Fullscreen mode (0=windowed, 1=fullscreen)
fullscreen = 0

# Window size
width = 640
height = 480

# Show FPS counter
show_fps = 1

# Audio settings
audio.driver = osx
audio.buffer_size = 2048

# Input settings
input.device1 = keyboard
input.device2 = keyboard
input.device3 = keyboard
input.device4 = keyboard

# GDB settings
gdb.enabled = 1
gdb.port = 1234
gdb.wait = 0

# Paths
path.bios =
path.flash =
path.save = $HOME/.lxdream/save
path.state = $HOME/.lxdream/state
path.screenshot = $HOME/.lxdream/screenshots

# Debug settings
debug.level = 2
debug.modules = CPU,MMU,SH4

# Performance
render.driver = gl
render.vsync = 0
EOF

# Create necessary directories
mkdir -p "$CONFIG_DIR/save" "$CONFIG_DIR/state" "$CONFIG_DIR/screenshots"

# Test installation
log_info "Testing lxdream installation..."
if command -v lxdream &> /dev/null; then
    log_success "lxdream installed successfully!"
    lxdream --version || true
else
    log_error "lxdream installation verification failed"
    exit 1
fi

# Create a helper script for easy GDB debugging
log_info "Creating GDB helper script..."
cat > "$INSTALL_PREFIX/bin/lxdream-gdb" << 'EOF'
#!/bin/bash
# Helper script to launch lxdream with GDB stub enabled

GAME_FILE="$1"
GDB_PORT="${2:-1234}"

if [[ -z "$GAME_FILE" ]]; then
    echo "Usage: lxdream-gdb <game.elf> [gdb-port]"
    exit 1
fi

echo "Starting lxdream with GDB stub on port $GDB_PORT..."
echo "Connect with: sh-elf-gdb -ex 'target remote localhost:$GDB_PORT' $GAME_FILE"
lxdream -g "$GDB_PORT" -A null "$GAME_FILE"
EOF
chmod +x "$INSTALL_PREFIX/bin/lxdream-gdb"

# Clean up
log_info "Cleaning up build directory..."
cd /
rm -rf "$BUILD_DIR"

log_success "lxdream installation complete!"
log_info ""
log_info "Next steps:"
log_info "1. Download Dreamcast BIOS files (dc_boot.bin, dc_flash.bin)"
log_info "2. Place them in: $CONFIG_DIR/"
log_info "3. Launch with: lxdream <game.cdi>"
log_info "4. Debug with: lxdream-gdb <game.elf>"
log_info ""
log_info "Configuration file: $CONFIG_DIR/lxdreamrc"
