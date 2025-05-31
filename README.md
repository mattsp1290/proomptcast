# Proomptcast - Dreamcast Game Development Base Repository

## 🎮 Overview

This is a comprehensive base repository for developing multiplayer games for the Sega Dreamcast using KallistiOS and Raylib. It's designed to help senior developers quickly port PyGame games to the Dreamcast platform while maintaining optimal performance.

**Key Features:**
- 🚀 One-click Docker development environment
- 🎯 Tower Defense example game with 4-player split-screen support
- 📚 Comprehensive documentation for Dreamcast newcomers
- 🔧 VS Code/Cursor integration with Cline support
- 📊 Performance profiling and monitoring
- 🎨 PyGame to Raylib migration guide

## 🏃 Quick Start

### Prerequisites
- Docker installed
- VS Code or Cursor editor
- 8GB+ RAM recommended
- macOS, Linux, or WSL2 on Windows

### Get Started in 5 Minutes

```bash
# Clone the repository
git clone https://github.com/yourusername/proomptcast.git
cd proomptcast

# Build the Docker development environment
docker build -t dreamcast-toolchain -f docker/Dockerfile.toolchain docker/

# Or use Docker Compose (recommended)
docker-compose -f docker/docker-compose.yml up -d

# Enter the development container
docker-compose -f docker/docker-compose.yml exec dreamcast-dev bash

# Inside container: validate toolchain
./scripts/validate_build.sh

# Build the example game
make

# Convert Unity/Synty assets (if you have them)
python3 /usr/local/bin/unity_asset_extractor.py unity_assets.bundle ./assets

# Batch convert assets
./scripts/batch_convert.sh -i raw_assets/ -o assets/
```

## 📁 Repository Structure

```
proomptcast/
├── .cursor/                 # AI assistant configurations
│   ├── prompts.md          # Hardware constraints for AI
│   └── rules.md            # Development rules
├── .vscode/                # VS Code/Cursor settings
│   ├── settings.json       # Editor configuration
│   └── tasks.json          # Build and run tasks
├── docs/                   # Documentation
│   ├── architecture/       # System architecture docs
│   │   ├── system-overview.md
│   │   ├── game-architecture.md
│   │   ├── multiplayer-design.md
│   │   └── performance-guide.md
│   ├── pygame-to-raylib.md
│   └── getting-started.md
├── docker/                 # Docker configurations
│   ├── Dockerfile.toolchain
│   └── docker-compose.yml
├── src/                    # Source code
│   ├── game/              # Game logic
│   ├── engine/            # Core engine
│   └── main.c             # Entry point
├── assets/                # Game assets
├── scripts/               # Build and utility scripts
├── tests/                 # Unit tests
└── proompts/
    └── task.yaml          # Project roadmap
```

## 🎯 Example Game: Tower Defense

The repository includes a complete tower defense game demonstrating:
- **Split-screen multiplayer** (1-4 players)
- **Object pooling** for memory efficiency
- **Fixed-point math** for performance
- **Optimized rendering** pipeline
- **Controller input** for all 4 ports

### Game Features
- 3 tower types (Basic, Rapid, Splash)
- 5 enemy types with different behaviors
- 10 waves of increasing difficulty
- Cooperative gameplay mechanics
- Resource sharing between players

## 🏗️ Architecture Highlights

### Hardware Constraints
- **CPU**: Hitachi SH4 @ 200MHz
- **RAM**: 16MB (no virtual memory)
- **GPU**: PowerVR CLX2 (tile-based renderer)
- **Resolution**: 640x480 fixed

### Performance Targets
- **60 FPS** with 4-player split-screen
- **< 14MB** memory usage
- **< 16.67ms** frame time

### Key Design Decisions
1. **Static memory allocation** - No malloc in game loop
2. **Fixed-point math** - Better performance than floats
3. **Object pools** - Reuse memory for entities
4. **Batched rendering** - Minimize draw calls

## 🔧 Development Workflow

### VS Code Integration

The repository is configured for optimal development in VS Code/Cursor:

- **F5**: Build and run in emulator
- **Ctrl+Shift+B**: Build game
- **Tasks**: Test with different player counts
- **IntelliSense**: Configured for Dreamcast SDK

### Available Tasks

```bash
# Build tasks
"Build Game"          # Default build
"Clean Build"         # Clean and rebuild
"Create CDI Image"    # Create disc image
"Convert Assets"      # Process game assets

# Test tasks  
"Run in Emulator"     # Launch with lxdream
"Test 2 Players"      # Test split-screen
"Test 4 Players"      # Test quad-screen
"Profile Performance" # Run profiler

# Development
"Monitor Performance" # Real-time metrics
"Check Memory Usage"  # Memory analysis
"Lint Code"          # Static analysis
```

## 🐳 Docker Environment

The Docker container includes:
- KallistiOS SDK with SH4 cross-compiler
- ARM toolchain for sound processor
- raylib4Dreamcast pre-integrated
- Comprehensive asset conversion pipeline:
  - PVR texture converter
  - Unity asset extractor
  - ADPCM audio converter
  - 3D model optimizer (Assimp)
  - Dreamcast disc image tools
- Full debugging suite (GDB, profiler)
- Python environment with asset tools
- Multi-architecture support (AMD64 + ARM64)

### Building the Container

```bash
# Build locally
docker build -t dreamcast-toolchain -f docker/Dockerfile.toolchain docker/

# Or pull from registry (after CI/CD setup)
docker pull registry.digitalocean.com/your-registry/dreamcast-toolchain:latest
```

### Asset Conversion Tools

```bash
# Optimize individual texture
./scripts/optimize_texture.sh -i texture.png -o assets/textures/ -s 256 -f pvr

# Optimize 3D model
./scripts/optimize_model.sh -i model.fbx -o assets/models/ -v 10000

# Batch convert entire directory
./scripts/batch_convert.sh -i unity_export/ -o assets/ -j 8

# Extract Unity assets
python3 scripts/unity_asset_extractor.py synty_pack.unitypackage ./extracted/
```

### Using Docker Compose

```bash
# Start development environment
docker-compose -f docker/docker-compose.yml up -d

# Stop when done
docker-compose -f docker/docker-compose.yml down
```

## 📚 Documentation

### For Dreamcast Beginners
1. [System Overview](docs/architecture/system-overview.md) - Hardware and software architecture
2. [Getting Started](docs/getting-started.md) - Step-by-step setup guide
3. [Performance Guide](docs/architecture/performance-guide.md) - Optimization techniques

### For Game Development
1. [Game Architecture](docs/architecture/game-architecture.md) - Tower defense implementation
2. [Multiplayer Design](docs/architecture/multiplayer-design.md) - Split-screen rendering
3. [PyGame to Raylib](docs/pygame-to-raylib.md) - Migration guide

## 🚀 Performance Monitoring

The repository integrates with OpenTelemetry for performance monitoring:

```c
// Automatic performance tracking
PROF_START(game_update);
update_game_logic(dt);
PROF_END(game_update);

// Memory tracking
track_memory_usage(MEM_ENTITIES);
```

Connect to your local OpenTelemetry instance at `/Users/punk1290/git/local-otel` for real-time metrics.

## 🎮 Controller Mapping

| Dreamcast | Action |
|-----------|--------|
| D-Pad | Move cursor |
| A Button | Place tower |
| B Button | Cancel |
| X Button | Upgrade tower |
| Y Button | Sell tower |
| Start | Pause game |
| Analog | Pan camera |
| L Trigger | Previous tower type |
| R Trigger | Next tower type |

## 🧪 Testing

### Unit Tests
```bash
docker run --rm -v $(pwd):/workspace -w /workspace dreamcast-dev make test
```

### Performance Tests
- Frame time must be < 16.67ms
- Memory usage must be < 14MB
- All 4 controllers must respond
- 60 FPS in 4-player mode

## 🤝 Contributing

1. Follow the coding rules in `.cursor/rules.md`
2. Test on real hardware when possible
3. Profile performance impacts
4. Update documentation

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- KallistiOS team for the amazing SDK
- Raylib team for the game development library
- Dreamcast homebrew community

---

**Remember**: This is a career-defining project. Every optimization matters. Every byte counts. Make it exceptional! 🚀
