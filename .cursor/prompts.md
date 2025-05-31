# Dreamcast Development AI Assistant Prompts

## System Context

You are developing for the Sega Dreamcast console with these hardware constraints:
- CPU: Hitachi SH4 200MHz (limited floating-point performance)
- RAM: 16MB main memory (no virtual memory/swap)
- VRAM: 8MB video memory
- GPU: PowerVR CLX2 (tile-based deferred renderer)
- Resolution: 640x480 fixed
- Target: 60 FPS consistently

## Critical Constraints to Remember

### Memory Management
- Total usable RAM: ~15MB (1MB for KallistiOS)
- No dynamic memory allocation in game loop
- Use object pools for all game entities
- Pre-allocate everything at startup
- Track memory usage constantly

### Performance Guidelines
- Use fixed-point math (16.16 format) for game logic
- Reserve floating-point for critical 3D calculations only
- Batch similar draw calls together
- Minimize texture switches
- Use VQ compressed textures (PVR format)

### Code Patterns

When writing code, always:
1. Use static allocation over dynamic
2. Pack data structures for cache efficiency
3. Align data to 32-byte boundaries
4. Prefer integer math over floating-point
5. Unroll critical loops

## Common Prompts

### For Entity Systems
"Create an entity system using object pools with a maximum of [N] entities. Use fixed-point math for positions and velocities. Pack the structure for cache efficiency."

### For Rendering
"Implement sprite batching for the PowerVR renderer. Group sprites by texture and minimize state changes. Use hardware-accelerated primitives where possible."

### For Multiplayer
"Implement split-screen rendering for [N] players. Each viewport should cull entities outside its frustum. Adjust quality settings based on player count."

### For Memory Optimization
"Optimize this data structure to fit within [N] bytes. Use bit packing for flags and small values. Ensure 32-byte alignment for DMA transfers."

### For Performance Profiling
"Add performance timers to measure frame time breakdown. Display FPS, memory usage, and entity counts in a debug overlay."

## Code Templates

### Object Pool Template
```c
typedef struct {
    Entity entities[MAX_ENTITIES];
    uint32_t active_flags[(MAX_ENTITIES + 31) / 32];
    uint16_t active_count;
} EntityPool;
```

### Fixed-Point Math Template
```c
typedef int32_t fixed16_t;
#define FIXED_ONE (1 << 16)
#define INT_TO_FIXED(x) ((x) << 16)
#define FIXED_MUL(a, b) (((int64_t)(a) * (b)) >> 16)
```

### Performance Timer Template
```c
#define PROF_START(name) uint64_t _prof_##name = timer_us_gettime64()
#define PROF_END(name) printf(#name ": %llu us\n", timer_us_gettime64() - _prof_##name)
```

## Optimization Checklist

Before committing code, verify:
- [ ] No malloc/free in game loop
- [ ] All floats converted to fixed-point where possible
- [ ] Data structures are cache-aligned
- [ ] Textures are power-of-2 and compressed
- [ ] Draw calls are batched by texture
- [ ] Memory usage is under 14MB
- [ ] Frame rate maintains 60 FPS

## Common Pitfalls to Avoid

1. **Dynamic string operations** - Pre-allocate string buffers
2. **Floating-point in tight loops** - Use lookup tables or fixed-point
3. **Large stack allocations** - Use static buffers instead
4. **Unaligned memory access** - Always align to natural boundaries
5. **Too many draw calls** - Batch everything possible

## Testing Reminders

- Test with 4 controllers connected
- Verify 60 FPS in 4-player split-screen
- Check memory usage doesn't exceed limits
- Profile on real hardware, not just emulator
- Test with maximum entities spawned

Remember: The Dreamcast is a fixed platform. Every byte and cycle counts!
