# Dreamcast Development Rules and Guidelines

## Memory Rules

### Rule 1: Static Allocation Only
```c
// ❌ WRONG - Dynamic allocation
Enemy* enemy = malloc(sizeof(Enemy));

// ✅ CORRECT - Static pool
static Enemy enemy_pool[MAX_ENEMIES];
Enemy* enemy = &enemy_pool[next_free_index];
```

### Rule 2: Memory Alignment
```c
// ❌ WRONG - Unaligned structure
typedef struct {
    char flag;      // 1 byte
    float x;        // 4 bytes - UNALIGNED!
} BadStruct;

// ✅ CORRECT - Properly aligned
typedef struct {
    float x;        // 4 bytes
    float y;        // 4 bytes
    uint32_t flags; // 4 bytes
} GoodStruct __attribute__((aligned(32)));
```

### Rule 3: Memory Budget
```
Maximum memory usage per subsystem:
- Game Logic: 4MB
- Entity Pools: 3MB
- Render Buffers: 3MB
- Audio: 2MB
- Textures: 2MB (in VRAM)
- Stack: 1MB
TOTAL: 15MB (leaving 1MB for KOS)
```

## Performance Rules

### Rule 4: Fixed-Point Math First
```c
// ❌ WRONG - Floating point everywhere
float distance = sqrt(dx * dx + dy * dy);

// ✅ CORRECT - Fixed-point math
fixed16_t distance = fixed_sqrt(
    fixed_mul(dx, dx) + fixed_mul(dy, dy)
);
```

### Rule 5: Loop Optimization
```c
// ❌ WRONG - Cache-unfriendly
for (int i = 0; i < count; i++) {
    entities[i].x += entities[i].vx;
    entities[i].sprite.frame++;
    entities[i].collision.checked = false;
}

// ✅ CORRECT - Process hot data together
for (int i = 0; i < count; i++) {
    positions[i].x += velocities[i].x;
    positions[i].y += velocities[i].y;
}
```

### Rule 6: Batch Rendering
```c
// ❌ WRONG - Individual draw calls
for (int i = 0; i < enemy_count; i++) {
    DrawTexture(enemy_texture, enemies[i].x, enemies[i].y);
}

// ✅ CORRECT - Batched rendering
BeginSpriteBatch(enemy_texture);
for (int i = 0; i < enemy_count; i++) {
    AddSpriteToBatch(enemies[i].x, enemies[i].y);
}
EndSpriteBatch();
```

## Code Organization Rules

### Rule 7: Data Structure Packing
```c
// Entity structure optimized for cache
typedef struct {
    // Hot data (accessed every frame) - 32 bytes
    struct {
        fixed16_t x, y;          // 8 bytes
        fixed16_t vx, vy;        // 8 bytes
        uint16_t health;         // 2 bytes
        uint16_t type;           // 2 bytes
        uint32_t flags;          // 4 bytes
        uint32_t _padding;       // 8 bytes padding to 32
    } hot;
    
    // Cold data (accessed rarely)
    struct {
        char name[32];
        uint32_t score_value;
        uint32_t spawn_time;
    } cold;
} Entity __attribute__((aligned(32)));
```

### Rule 8: Constants and Limits
```c
// All game limits must be compile-time constants
#define MAX_PLAYERS          4
#define MAX_ENEMIES          100
#define MAX_BULLETS          200
#define MAX_PARTICLES        500
#define MAX_TOWERS           50

// Memory pool sizes
#define ENEMY_POOL_SIZE      (sizeof(Enemy) * MAX_ENEMIES)
#define BULLET_POOL_SIZE     (sizeof(Bullet) * MAX_BULLETS)

// Ensure we don't exceed memory
#if (ENEMY_POOL_SIZE + BULLET_POOL_SIZE) > (4 * 1024 * 1024)
    #error "Entity pools exceed 4MB limit!"
#endif
```

## Rendering Rules

### Rule 9: Texture Management
```c
// Texture requirements:
// - Power of 2 dimensions (64, 128, 256, 512)
// - VQ compressed format for large textures
// - Palettized for small sprites
// - Maximum 512x512 (uses 512KB VRAM uncompressed)

// ❌ WRONG
LoadTexture("background_800x600.png");  // Non-power-of-2

// ✅ CORRECT
LoadTextureVQ("background_512x512.vq"); // Compressed, power-of-2
```

### Rule 10: Draw Order
```
Rendering order for optimal performance:
1. Opaque geometry (back to front)
2. Alpha-tested geometry
3. Transparent geometry (back to front)
4. UI overlay (no depth testing)
```

## Multiplayer Rules

### Rule 11: Split-Screen Quality Scaling
```c
// Automatically reduce quality based on player count
switch (active_players) {
    case 1:
        max_particles = 500;
        shadow_quality = HIGH;
        texture_detail = HIGH;
        break;
    case 2:
        max_particles = 250;
        shadow_quality = MEDIUM;
        texture_detail = HIGH;
        break;
    case 3:
    case 4:
        max_particles = 100;
        shadow_quality = OFF;
        texture_detail = MEDIUM;
        break;
}
```

### Rule 12: Viewport Culling
```c
// Every viewport must cull independently
for (int p = 0; p < player_count; p++) {
    Viewport* vp = &viewports[p];
    
    // Only process visible entities
    int visible_count = 0;
    for (int i = 0; i < entity_count; i++) {
        if (entity_in_viewport(&entities[i], vp)) {
            visible_entities[visible_count++] = i;
        }
    }
    
    // Only render visible
    render_entities(visible_entities, visible_count);
}
```

## Debug and Release Rules

### Rule 13: Conditional Compilation
```c
#ifdef DEBUG
    #define PROF_START(name) prof_start(name)
    #define PROF_END(name) prof_end(name)
    #define ASSERT(x) if (!(x)) { printf("Assert: " #x "\n"); abort(); }
#else
    #define PROF_START(name)
    #define PROF_END(name)
    #define ASSERT(x)
#endif
```

### Rule 14: Debug Overlays
```c
// Debug info must not affect performance
typedef struct {
    bool show_fps;
    bool show_memory;
    bool show_entities;
    bool show_collision;
} DebugFlags;

#ifdef DEBUG
static DebugFlags debug = {true, true, false, false};
#else
// Completely removed in release
#endif
```

## Testing Rules

### Rule 15: Performance Benchmarks
Every major system must have benchmarks:
- Entity update: < 2ms for 100 entities
- Rendering: < 8ms for full scene
- Collision: < 1ms for 100 vs 100 checks
- Audio mixing: < 1ms per frame

### Rule 16: Memory Tracking
```c
// Track allocations by category
typedef enum {
    MEM_GAME_LOGIC,
    MEM_RENDERING,
    MEM_AUDIO,
    MEM_ENTITIES,
    MEM_COUNT
} MemCategory;

static size_t mem_usage[MEM_COUNT] = {0};

// Wrapper for tracking
void* tracked_alloc(size_t size, MemCategory cat) {
    mem_usage[cat] += size;
    return aligned_alloc(32, size);
}
```

## File I/O Rules

### Rule 17: Async Loading
```c
// Never block on file I/O during gameplay
typedef struct {
    char filename[64];
    void* buffer;
    size_t size;
    bool complete;
} AsyncLoad;

// Load in background
void start_async_load(AsyncLoad* load, const char* file);
bool is_load_complete(AsyncLoad* load);
```

### Rule 18: Asset Bundling
```
Asset organization:
- Bundle related assets together
- Use single file with offset table
- Compress where possible
- Align to sector boundaries (2KB)
```

## Golden Rules Summary

1. **Never allocate memory during gameplay**
2. **Always use fixed-point math for game logic**
3. **Profile everything, assume nothing**
4. **Test on real hardware regularly**
5. **Batch similar operations together**
6. **Respect the 16MB memory limit**
7. **Target 60 FPS always, no exceptions**
8. **Plan for 4-player split-screen from day one**

## Enforcement

These rules are not guidelines - they are requirements. Code reviews must verify:
- [ ] No dynamic allocation in game loop
- [ ] All math operations use appropriate types
- [ ] Memory usage stays within budgets
- [ ] Performance targets are met
- [ ] Code follows naming conventions
- [ ] Debug code is properly conditionally compiled

Remember: The Dreamcast hardware is fixed. We must adapt our code to it, not the other way around!
