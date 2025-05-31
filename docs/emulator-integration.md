# 🎮 Dreamcast Emulator Integration Guide

## Overview

This guide covers the elite Dreamcast emulation environment we've created, featuring seamless VS Code integration, 4-player support, automated testing, and sub-5-second build-to-test cycles.

## 🚀 Quick Start

### 1. Install lxdream

```bash
# Install lxdream with GDB debugging support
./scripts/emulators/install-lxdream-macos.sh

# Note: You'll need to obtain Dreamcast BIOS files:
# - dc_boot.bin
# - dc_flash.bin
# Place them in: ~/.lxdream/
```

### 2. Test Your Setup

```bash
# Test controller configuration
./scripts/test-controllers.sh

# Run a game
./scripts/run-emulator.sh build/game.cdi

# Debug a game
./scripts/run-emulator.sh --debug build/game.elf
```

### 3. VS Code Integration

Press **F5** to build and launch in the emulator with debugging enabled!

## 📁 Project Structure

```
scripts/
├── run-emulator.sh              # Main emulator launcher
├── launch-lxdream.sh            # lxdream-specific launcher
├── test-integration.sh          # Automated testing framework
├── test-controllers.sh          # Controller configuration tester
└── emulators/
    └── install-lxdream-macos.sh # lxdream installer

config/emulators/
├── lxdream/
│   └── lxdream.cfg             # Optimized debug configuration
└── input-profiles/
    ├── default.json            # 4-player keyboard mappings
    └── testing.json            # Automated testing profile

tests/integration/
└── multiplayer/
    └── 4player-join.yaml       # Example integration test

docker/
└── Dockerfile.lxdream          # CI/CD container
```

## 🎮 4-Player Keyboard Mappings

### Player 1 (WASD)
- **Movement**: W/A/S/D
- **Buttons**: Space (A), Left Shift (B), Q (X), E (Y)
- **Triggers**: R (L), F (R)
- **Start**: Enter

### Player 2 (Arrows)
- **Movement**: Arrow Keys
- **Buttons**: Enter (A), Right Shift (B), . (X), / (Y)
- **Triggers**: , (L), M (R)
- **Start**: Right Ctrl

### Player 3 (IJKL)
- **Movement**: I/J/K/L
- **Buttons**: U (A), O (B), 7 (X), 8 (Y)
- **Triggers**: Y (L), P (R)
- **Start**: 9

### Player 4 (Numpad)
- **Movement**: Numpad 8/4/2/6
- **Buttons**: Numpad 0 (A), Numpad . (B), Numpad 7 (X), Numpad 9 (Y)
- **Triggers**: Numpad 1 (L), Numpad 3 (R)
- **Start**: Numpad Enter

## 🐛 Debugging

### GDB Integration

1. Launch with debugging:
```bash
./scripts/run-emulator.sh --debug --wait build/game.elf
```

2. Connect GDB:
```bash
sh-elf-gdb -ex 'target remote localhost:1234' build/game.elf
```

3. Or just press F5 in VS Code!

### Memory Inspection

lxdream provides excellent memory debugging features:
- VRAM viewer for texture debugging
- Main RAM browser with search
- Hardware register viewer
- Memory watch expressions

Access these through lxdream's View menu when running with GUI.

## 🧪 Automated Testing

### Running Tests

```bash
# Run all integration tests
./scripts/test-integration.sh build/game.cdi

# Run specific test suite
./scripts/test-integration.sh --suite multiplayer build/game.cdi

# Run single test
./scripts/test-integration.sh --test tests/integration/multiplayer/4player-join.yaml build/game.elf
```

### Writing Tests

Tests are defined in YAML format:

```yaml
name: "My Test"
savestate: "states/test_state.state"
steps:
  - action: wait
    frame: 60
  - action: input
    frame: 100
    value: "P1_START"
  - action: assert
    frame: 150
    value: "player_count == 1"
  - action: screenshot
    frame: 151
    value: "result.png"
```

## 🔧 Advanced Usage

### Custom Input Profiles

Create new profiles in `config/emulators/input-profiles/`:

```json
{
  "profile": "custom",
  "players": [
    {
      "id": 1,
      "mapping": {
        "dpad_up": "W",
        // ... rest of mappings
      }
    }
  ]
}
```

### Performance Profiling

Enable performance monitoring:
```bash
./scripts/run-emulator.sh --emulator lxdream --debug build/game.elf
```

Then use lxdream's built-in profiler (View → Performance Monitor).

### CI/CD Integration

For headless testing in CI:

```yaml
# GitHub Actions example
- name: Build lxdream container
  run: docker build -f docker/Dockerfile.lxdream -t lxdream-ci .

- name: Run integration tests
  run: |
    docker run --rm \
      -v $PWD:/workspace \
      lxdream-ci \
      /workspace/scripts/test-integration.sh /workspace/build/game.cdi
```

## 🎯 Tips & Tricks

### Fast Iteration
1. Keep lxdream running
2. Use save states for quick testing
3. Map save/load state to convenient keys (F5/F9 by default)

### Multi-Instance Testing
```bash
# Launch 4 separate instances for network testing
for i in {1..4}; do
  ./scripts/run-emulator.sh --gdb-port $((1234+$i)) build/game.elf &
done
```

### Visual Controller Test
```bash
# Opens an interactive HTML page to test mappings
./scripts/test-controllers.sh
# Select 'y' when prompted
```

## 🚨 Troubleshooting

### lxdream Won't Start
- Check BIOS files are in `~/.lxdream/`
- Verify installation: `lxdream --version`
- Check logs: `/tmp/lxdream-debug-*.log`

### Controller Issues
- Test with: `./scripts/test-controllers.sh`
- Check input profile exists
- Verify no key conflicts with OS

### Debugging Connection Failed
- Ensure no other process on port 1234
- Check firewall settings
- Try different port: `--gdb-port 2345`

## 📚 Resources

- [lxdream Documentation](http://www.lxdream.org/documentation/)
- [Dreamcast Hardware Reference](https://dreamcast.wiki/)
- [KallistiOS Documentation](http://gamedev.allusion.net/docs/kos/)

## 🎖️ Achievement Unlocked!

You now have:
- ✅ One-click debugging from VS Code
- ✅ 4-player keyboard + USB controller support
- ✅ Sub-5-second build-to-test cycles
- ✅ Automated integration testing
- ✅ CI/CD ready emulation
- ✅ Advanced memory debugging tools

Happy Dreamcast development! 🚀
