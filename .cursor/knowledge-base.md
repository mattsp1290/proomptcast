# Dreamcast Development Knowledge Base

## Quick Reference

### KallistiOS Essential APIs

#### Memory Management
```c
// Aligned allocation (required for DMA)
void* memalign(size_t alignment, size_t size);

// Memory statistics
size_t mallinfo_total_mem();  // Total heap size
size_t mallinfo_free_mem();   // Free heap space

// DMA transfers
void dcache_flush_range(void* start, size_t len);
void dcache_inval_range(void* start, size_t len);
```

#### Timer Functions
```c
// High-resolution timing
uint64 timer_us_gettime64();     // Microseconds since boot
uint32 timer_ms_gettime();       // Milliseconds since boot

// Performance profiling
void timer_spin_sleep(int ms);   // Precise busy-wait
```

#### PVR Graphics
```c
// Initialization
int pvr_init(pvr_init_params_t* params);
void pvr_shutdown();

// Scene management
void pvr_scene_begin();
void pvr_scene_begin_txr(pvr_ptr_t txr, uint32* rx, uint32* ry);
void pvr_scene_finish();
void pvr_wait_ready();

// Polygon lists
void pvr_list_begin(pvr_list_t list);
void pvr_list_finish();
pvr_prim(void* data, int size);

// Texture loading
void pvr_txr_load(void* src, pvr_ptr_t dst, uint32 count);
pvr_ptr_t pvr_mem_malloc(size_t size);
```

### Raylib4Dreamcast Specific

#### Initialization
```c
// Window and graphics initialization
void InitWindow(int width, int height, const char* title);
void CloseWindow(void);
bool WindowShouldClose(void);

// IMPORTANT: Always use 640x480 for Dreamcast
InitWindow(640, 480, "Game Title");
```

#### Drawing Functions
```c
// Frame control
void BeginDrawing(void);
void EndDrawing(void);
void ClearBackground(Color color);

// Basic shapes (optimized for PVR)
void DrawRectangle(int x, int y, int width, int height, Color color);
void DrawCircle(int centerX, int centerY, float radius, Color color);
void DrawTexture(Texture2D texture, int posX, int posY, Color tint);

// Text rendering
void DrawText(const char* text, int x, int y, int fontSize, Color color);
void DrawFPS(int x, int y);
```

#### Texture Management
```c
// Loading textures (prefer PVR format)
Texture2D LoadTexture(const char* fileName);
Texture2D LoadTextureFromImage(Image image);
void UnloadTexture(Texture2D texture);

// IMPORTANT: Textures must be power-of-2
// Good: 64x64, 128x128, 256x256, 512x512
// Bad: 100x100, 640x480, 800x600
```

#### Input Handling
```c
// Controller support (up to 4 players)
bool IsGamepadAvailable(int gamepad);  // 0-3
bool IsGamepadButtonPressed(int gamepad, int button);
bool IsGamepadButtonDown(int gamepad, int button);
float GetGamepadAxisMovement(int gamepad, int axis);

// Dreamcast button mappings
#define GAMEPAD_BUTTON_A        0
#define GAMEPAD_BUTTON_B        1
#define GAMEPAD_BUTTON_X        2
#define GAMEPAD_BUTTON_Y        3
#define GAMEPAD_BUTTON_START    4
#define GAMEPAD_BUTTON_LTRIGGER 5
#define GAMEPAD_BUTTON_RTRIGGER 6
```

### Fixed-Point Math Library

```c
// Basic operations
fixed16_t fix16_add(fixed16_t a, fixed16_t b);
fixed16_t fix16_sub(fixed16_t a, fixed16_t b);
fixed16_t fix16_mul(fixed16_t a, fixed16_t b);
fixed16_t fix16_div(fixed16_t a, fixed16_t b);

// Conversions
fixed16_t fix16_from_int(int a);
fixed16_t fix16_from_float(float a);
int fix16_to_int(fixed16_t a);
float fix16_to_float(fixed16_t a);

// Math functions
fixed16_t fix16_sqrt(fixed16_t a);
fixed16_t fix16_sin(fixed16_t a);
fixed16_t fix16_cos(fixed16_t a);
fixed16_t fix16_atan2(fixed16_t y, fixed16_t x);

// Constants
#define FIX16_ONE     0x00010000
#define FIX16_HALF    0x00008000
#define FIX16_PI      0x0003243F
```

## Common Patterns

### Object Pool Implementation
```c
typedef struct {
    Entity entities[MAX_ENTITIES];
    uint32_t active_mask[(MAX_ENTITIES + 31) / 32];
    int active_count;
    int first_free;
} EntityPool;

Entity* pool_allocate(EntityPool* pool) {
    if (pool->active_count >= MAX_ENTITIES) return NULL;
    
    // Find first free slot
    for (int i = 0; i < MAX_ENTITIES; i++) {
        int word = i / 32;
        int bit = i % 32;
        if (!(pool->active_mask[word] & (1 << bit))) {
            pool->active_mask[word] |= (1 << bit);
            pool->active_count++;
            return &pool->entities[i];
        }
    }
    return NULL;
}

void pool_free(EntityPool* pool, Entity* entity) {
    int index = entity - pool->entities;
    int word = index / 32;
    int bit = index % 32;
    pool->active_mask[word] &= ~(1 << bit);
    pool->active_count--;
}
```

### Sprite Batching
```c
typedef struct {
    pvr_sprite_txr_t sprites[MAX_BATCH_SIZE];
    int count;
    pvr_ptr_t current_texture;
} SpriteBatch;

void batch_begin(SpriteBatch* batch, pvr_ptr_t texture) {
    batch->count = 0;
    batch->current_texture = texture;
    pvr_list_begin(PVR_LIST_TR_POLY);
}

void batch_add(SpriteBatch* batch, float x, float y, float w, float h) {
    if (batch->count >= MAX_BATCH_SIZE) {
        batch_flush(batch);
    }
    
    pvr_sprite_txr_t* sprite = &batch->sprites[batch->count++];
    pvr_sprite_cxt_txr(sprite, PVR_LIST_TR_POLY, 
                       PVR_TXRFMT_RGB565 | PVR_TXRFMT_TWIDDLED,
                       256, 256, batch->current_texture, PVR_FILTER_BILINEAR);
    
    sprite->ax = x;
    sprite->ay = y;
    sprite->bx = x + w;
    sprite->by = y;
    sprite->cx = x + w;
    sprite->cy = y + h;
    sprite->dx = x;
    sprite->dy = y + h;
}

void batch_flush(SpriteBatch* batch) {
    for (int i = 0; i < batch->count; i++) {
        pvr_prim(&batch->sprites[i], sizeof(pvr_sprite_txr_t));
    }
    batch->count = 0;
}
```

### Performance Profiling
```c
typedef struct {
    const char* name;
    uint64_t start_time;
    uint64_t total_time;
    uint32_t call_count;
} ProfileTimer;

#define MAX_PROFILE_TIMERS 16
static ProfileTimer profile_timers[MAX_PROFILE_TIMERS];
static int profile_timer_count = 0;

void profile_begin(const char* name) {
    for (int i = 0; i < profile_timer_count; i++) {
        if (profile_timers[i].name == name) {
            profile_timers[i].start_time = timer_us_gettime64();
            return;
        }
    }
    
    // New timer
    if (profile_timer_count < MAX_PROFILE_TIMERS) {
        ProfileTimer* timer = &profile_timers[profile_timer_count++];
        timer->name = name;
        timer->start_time = timer_us_gettime64();
        timer->total_time = 0;
        timer->call_count = 0;
    }
}

void profile_end(const char* name) {
    uint64_t end_time = timer_us_gettime64();
    
    for (int i = 0; i < profile_timer_count; i++) {
        if (profile_timers[i].name == name) {
            profile_timers[i].total_time += end_time - profile_timers[i].start_time;
            profile_timers[i].call_count++;
            return;
        }
    }
}

void profile_report() {
    printf("=== Performance Report ===\n");
    for (int i = 0; i < profile_timer_count; i++) {
        ProfileTimer* timer = &profile_timers[i];
        if (timer->call_count > 0) {
            uint64_t avg = timer->total_time / timer->call_count;
            printf("%s: %llu us avg (%u calls)\n", 
                   timer->name, avg, timer->call_count);
        }
    }
}
```

### Memory-Aligned Structures
```c
// Entity structure optimized for cache
typedef struct __attribute__((aligned(32))) {
    // Hot data - accessed every frame (32 bytes)
    fixed16_t x, y;        // 8 bytes
    fixed16_t vx, vy;      // 8 bytes
    uint16_t type;         // 2 bytes
    uint16_t health;       // 2 bytes
    uint32_t flags;        // 4 bytes
    uint8_t _pad1[8];      // 8 bytes padding
    
    // Warm data - accessed occasionally (32 bytes)
    fixed16_t target_x, target_y;  // 8 bytes
    uint16_t animation_frame;       // 2 bytes
    uint16_t animation_timer;       // 2 bytes
    uint32_t score_value;          // 4 bytes
    uint8_t _pad2[16];             // 16 bytes padding
    
    // Cold data - rarely accessed
    char name[32];
    uint32_t spawn_time;
    uint32_t last_damage_time;
} Entity;

// Ensure proper size
_Static_assert(sizeof(Entity) % 32 == 0, "Entity must be 32-byte aligned");
```

## Optimization Techniques

### 1. Loop Unrolling
```c
// Instead of:
for (int i = 0; i < count; i++) {
    positions[i] += velocities[i];
}

// Use (when count is known to be multiple of 4):
for (int i = 0; i < count; i += 4) {
    positions[i+0] += velocities[i+0];
    positions[i+1] += velocities[i+1];
    positions[i+2] += velocities[i+2];
    positions[i+3] += velocities[i+3];
}
```

### 2. Lookup Tables
```c
// Pre-calculated sine table for fixed-point
static const fixed16_t sin_table[256] = {
    0x0000, 0x0192, 0x0324, 0x04B6, // ...
};

fixed16_t fast_sin(uint8_t angle) {
    return sin_table[angle];
}
```

### 3. Spatial Partitioning
```c
typedef struct {
    Entity* entities[MAX_ENTITIES_PER_CELL];
    uint8_t count;
} GridCell;

typedef struct {
    GridCell cells[GRID_WIDTH][GRID_HEIGHT];
} SpatialGrid;

void grid_insert(SpatialGrid* grid, Entity* entity) {
    int gx = (int)(fix16_to_int(entity->x) / CELL_SIZE);
    int gy = (int)(fix16_to_int(entity->y) / CELL_SIZE);
    
    if (gx >= 0 && gx < GRID_WIDTH && gy >= 0 && gy < GRID_HEIGHT) {
        GridCell* cell = &grid->cells[gx][gy];
        if (cell->count < MAX_ENTITIES_PER_CELL) {
            cell->entities[cell->count++] = entity;
        }
    }
}
```

### 4. DMA Optimization
```c
// Ensure data is aligned and cache-flushed before DMA
void* dma_prepare(void* data, size_t size) {
    // Data must be 32-byte aligned
    assert(((uintptr_t)data & 31) == 0);
    
    // Flush cache to ensure coherency
    dcache_flush_range(data, size);
    
    return data;
}
```

## Hardware-Specific Tips

### PowerVR Rendering
1. **Always use triangle strips over individual triangles**
2. **Sort polygons by texture to minimize state changes**
3. **Use PVR texture compression for large textures**
4. **Avoid alpha blending when possible (use punch-through)**

### SH4 CPU Optimization
1. **Align hot data to cache line boundaries (32 bytes)**
2. **Use prefetch instructions for predictable access patterns**
3. **Minimize branches in inner loops**
4. **Use integer operations over floating-point**

### Memory Bandwidth
1. **Pack vertex data tightly**
2. **Use 16-bit color formats (RGB565)**
3. **Compress textures with VQ encoding**
4. **Batch similar operations together**

## Debugging Techniques

### Memory Tracking
```c
void debug_memory_report() {
    size_t total = mallinfo_total_mem();
    size_t free = mallinfo_free_mem();
    size_t used = total - free;
    
    printf("Memory: %zu KB used / %zu KB total (%.1f%%)\n",
           used / 1024, total / 1024,
           (float)used / total * 100.0f);
}
```

### Frame Time Analysis
```c
void debug_frame_times() {
    static uint64_t last_frame = 0;
    uint64_t current = timer_us_gettime64();
    
    if (last_frame != 0) {
        uint64_t delta = current - last_frame;
        float ms = delta / 1000.0f;
        
        if (ms > 16.67f) {  // Missed 60 FPS target
            printf("PERF WARNING: Frame took %.2f ms\n", ms);
        }
    }
    
    last_frame = current;
}
```

## Common Errors and Solutions

### Error: "Out of PVR memory"
**Solution**: Reduce texture sizes, use compression, or unload unused textures

### Error: "Stack overflow"
**Solution**: Move large arrays to static storage or heap

### Error: "Unaligned memory access"
**Solution**: Use aligned allocation and proper structure packing

### Error: "DMA transfer failed"
**Solution**: Ensure data is 32-byte aligned and cache is flushed

### Error: "Frame drops in 4-player mode"
**Solution**: Reduce particle effects, simplify rendering, use LOD

## Performance Targets

| Operation | Target Time | Max Time |
|-----------|------------|----------|
| Entity Update (100 entities) | < 1ms | 2ms |
| Collision Detection | < 1ms | 1.5ms |
| Rendering | < 8ms | 10ms |
| Audio Mixing | < 0.5ms | 1ms |
| Input Processing | < 0.1ms | 0.2ms |
| **Total Frame** | < 16.67ms | 16.67ms |

## Quick Command Reference

### Build Commands
```bash
# Standard build
make

# Clean build
make clean && make

# Release build
make RELEASE=1

# Create CDI image
mkdcdisc game.cdi game.elf
```

### Memory Analysis
```bash
# Check section sizes
sh-elf-size -A game.elf

# Generate memory map
sh-elf-objdump -h game.elf

# Find large symbols
sh-elf-nm --size-sort game.elf | tail -20
```

### Performance Tools
```bash
# Profile on hardware
dc-tool -t COM1 -x game.elf

# Analyze assembly
sh-elf-objdump -d game.elf > game.asm

# Check optimization
sh-elf-objdump -d game.elf | grep "float"
```

Remember: Always think in terms of Dreamcast's constraints. Every allocation, every float, every texture switch has a cost!
