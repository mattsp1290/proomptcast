# PyGame to Raylib Migration Guide

## Overview

This guide helps developers port PyGame games to Raylib for Dreamcast development. While PyGame and Raylib share similar concepts, there are important differences in API design and capabilities.

## Quick Reference Table

| PyGame Concept | Raylib Equivalent | Notes |
|----------------|-------------------|-------|
| pygame.init() | InitWindow() | Raylib initializes subsystems automatically |
| pygame.display.set_mode() | InitWindow() | Fixed resolution on Dreamcast (640x480) |
| pygame.Surface | Texture2D | Hardware accelerated on Dreamcast |
| pygame.sprite.Sprite | Custom struct | Manual sprite management |
| pygame.sprite.Group | Custom array/pool | Use object pools for performance |
| pygame.time.Clock | GetFrameTime() | Built-in frame timing |
| pygame.event.get() | IsKeyPressed(), etc. | Event polling vs state checking |
| pygame.mixer | LoadSound(), PlaySound() | Simpler audio API |
| pygame.font | LoadFont(), DrawText() | Built-in text rendering |

## Core Concepts Translation

### 1. Initialization and Window Creation

**PyGame:**
```python
import pygame

pygame.init()
screen = pygame.display.set_mode((640, 480))
pygame.display.set_caption("My Game")
clock = pygame.time.Clock()
```

**Raylib (C):**
```c
#include "raylib.h"

int main() {
    InitWindow(640, 480, "My Game");
    SetTargetFPS(60);
    
    // Game loop
    while (!WindowShouldClose()) {
        // Update and draw
    }
    
    CloseWindow();
    return 0;
}
```

### 2. Game Loop Structure

**PyGame:**
```python
running = True
while running:
    # Handle events
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_SPACE:
                player.jump()
    
    # Update
    all_sprites.update(dt)
    
    # Draw
    screen.fill((0, 0, 0))
    all_sprites.draw(screen)
    pygame.display.flip()
    
    # Control frame rate
    dt = clock.tick(60) / 1000.0
```

**Raylib:**
```c
while (!WindowShouldClose()) {
    // Input handling (no event queue)
    if (IsKeyPressed(KEY_SPACE)) {
        player_jump(&player);
    }
    
    // Update
    float dt = GetFrameTime();
    update_entities(dt);
    
    // Draw
    BeginDrawing();
    ClearBackground(BLACK);
    draw_entities();
    EndDrawing();
}
```

### 3. Sprite Management

**PyGame Sprite Class:**
```python
class Player(pygame.sprite.Sprite):
    def __init__(self, x, y):
        super().__init__()
        self.image = pygame.image.load("player.png")
        self.rect = self.image.get_rect()
        self.rect.x = x
        self.rect.y = y
        self.velocity = pygame.Vector2(0, 0)
    
    def update(self, dt):
        self.rect.x += self.velocity.x * dt
        self.rect.y += self.velocity.y * dt
```

**Raylib Equivalent:**
```c
typedef struct {
    Vector2 position;
    Vector2 velocity;
    Texture2D texture;
    Rectangle bounds;
    bool active;
} Player;

void player_init(Player* player, float x, float y) {
    player->position = (Vector2){x, y};
    player->velocity = (Vector2){0, 0};
    player->texture = LoadTexture("player.png");
    player->bounds = (Rectangle){x, y, 
                                 player->texture.width, 
                                 player->texture.height};
    player->active = true;
}

void player_update(Player* player, float dt) {
    player->position.x += player->velocity.x * dt;
    player->position.y += player->velocity.y * dt;
    player->bounds.x = player->position.x;
    player->bounds.y = player->position.y;
}

void player_draw(Player* player) {
    if (player->active) {
        DrawTexture(player->texture, 
                   player->position.x, 
                   player->position.y, 
                   WHITE);
    }
}
```

### 4. Sprite Groups to Object Pools

**PyGame Groups:**
```python
all_sprites = pygame.sprite.Group()
enemies = pygame.sprite.Group()
bullets = pygame.sprite.Group()

# Add sprite
enemy = Enemy(100, 100)
all_sprites.add(enemy)
enemies.add(enemy)

# Update all
all_sprites.update(dt)

# Collision detection
hits = pygame.sprite.groupcollide(bullets, enemies, True, True)
```

**Raylib Object Pools:**
```c
#define MAX_ENEMIES 100
#define MAX_BULLETS 200

typedef struct {
    Enemy enemies[MAX_ENEMIES];
    int enemy_count;
} EnemyPool;

typedef struct {
    Bullet bullets[MAX_BULLETS];
    int bullet_count;
} BulletPool;

// Add enemy
Enemy* enemy_pool_spawn(EnemyPool* pool, float x, float y) {
    for (int i = 0; i < MAX_ENEMIES; i++) {
        if (!pool->enemies[i].active) {
            enemy_init(&pool->enemies[i], x, y);
            pool->enemy_count++;
            return &pool->enemies[i];
        }
    }
    return NULL;  // Pool full
}

// Update all
void enemy_pool_update(EnemyPool* pool, float dt) {
    for (int i = 0; i < MAX_ENEMIES; i++) {
        if (pool->enemies[i].active) {
            enemy_update(&pool->enemies[i], dt);
        }
    }
}

// Collision detection
void check_bullet_enemy_collisions(BulletPool* bullets, EnemyPool* enemies) {
    for (int b = 0; b < MAX_BULLETS; b++) {
        if (!bullets->bullets[b].active) continue;
        
        for (int e = 0; e < MAX_ENEMIES; e++) {
            if (!enemies->enemies[e].active) continue;
            
            if (CheckCollisionRecs(bullets->bullets[b].bounds, 
                                 enemies->enemies[e].bounds)) {
                bullets->bullets[b].active = false;
                enemies->enemies[e].active = false;
                bullets->bullet_count--;
                enemies->enemy_count--;
            }
        }
    }
}
```

### 5. Image Loading and Drawing

**PyGame:**
```python
# Load image
player_image = pygame.image.load("player.png").convert_alpha()

# Draw image
screen.blit(player_image, (x, y))

# Draw rotated/scaled
rotated = pygame.transform.rotate(player_image, angle)
scaled = pygame.transform.scale(player_image, (width, height))
screen.blit(rotated, (x, y))
```

**Raylib:**
```c
// Load texture
Texture2D player_texture = LoadTexture("player.png");

// Draw texture
DrawTexture(player_texture, x, y, WHITE);

// Draw rotated/scaled
DrawTextureEx(player_texture, 
              (Vector2){x, y}, 
              angle,      // rotation
              scale,      // scale
              WHITE);     // tint

// Draw part of texture (sprite sheet)
Rectangle source = {0, 0, 32, 32};  // Source rectangle
Rectangle dest = {x, y, 64, 64};    // Destination (scaled)
DrawTexturePro(player_texture, source, dest, 
               (Vector2){0, 0}, 0, WHITE);
```

### 6. Input Handling

**PyGame Event-Based:**
```python
for event in pygame.event.get():
    if event.type == pygame.KEYDOWN:
        if event.key == pygame.K_LEFT:
            player.move_left()
    elif event.type == pygame.KEYUP:
        if event.key == pygame.K_LEFT:
            player.stop_horizontal()
    elif event.type == pygame.MOUSEBUTTONDOWN:
        if event.button == 1:  # Left click
            shoot(event.pos)
```

**Raylib State-Based:**
```c
// Keyboard input
if (IsKeyDown(KEY_LEFT)) {
    player_move_left(&player);
}
if (IsKeyReleased(KEY_LEFT)) {
    player_stop_horizontal(&player);
}
if (IsKeyPressed(KEY_SPACE)) {  // Just pressed this frame
    player_shoot(&player);
}

// Mouse input (not applicable on Dreamcast)
// Use controller instead:
if (IsGamepadButtonPressed(0, GAMEPAD_BUTTON_RIGHT_FACE_DOWN)) {  // A button
    player_shoot(&player);
}

// Analog stick
float axis_x = GetGamepadAxisMovement(0, GAMEPAD_AXIS_LEFT_X);
float axis_y = GetGamepadAxisMovement(0, GAMEPAD_AXIS_LEFT_Y);
```

### 7. Sound and Music

**PyGame:**
```python
# Load and play sound
jump_sound = pygame.mixer.Sound("jump.wav")
jump_sound.play()

# Background music
pygame.mixer.music.load("background.ogg")
pygame.mixer.music.play(-1)  # Loop forever
pygame.mixer.music.set_volume(0.5)
```

**Raylib:**
```c
// Load and play sound
Sound jump_sound = LoadSound("jump.wav");
PlaySound(jump_sound);

// Background music
Music background = LoadMusicStream("background.ogg");
PlayMusicStream(background);
SetMusicVolume(background, 0.5f);

// In game loop:
UpdateMusicStream(background);  // Must call each frame
```

### 8. Text Rendering

**PyGame:**
```python
font = pygame.font.Font(None, 36)
text_surface = font.render("Score: 100", True, (255, 255, 255))
screen.blit(text_surface, (10, 10))
```

**Raylib:**
```c
// Simple text
DrawText("Score: 100", 10, 10, 36, WHITE);

// Custom font
Font custom_font = LoadFont("myfont.ttf");
DrawTextEx(custom_font, "Score: 100", 
           (Vector2){10, 10}, 36, 2, WHITE);
```

### 9. Collision Detection

**PyGame:**
```python
# Rectangle collision
if player.rect.colliderect(enemy.rect):
    handle_collision()

# Pixel-perfect collision
if pygame.sprite.collide_mask(player, enemy):
    handle_collision()

# Circle collision (custom)
distance = player.pos.distance_to(enemy.pos)
if distance < player.radius + enemy.radius:
    handle_collision()
```

**Raylib:**
```c
// Rectangle collision
if (CheckCollisionRecs(player.bounds, enemy.bounds)) {
    handle_collision();
}

// Circle collision
if (CheckCollisionCircles(player.pos, player.radius,
                         enemy.pos, enemy.radius)) {
    handle_collision();
}

// Point in rectangle
if (CheckCollisionPointRec(mouse_pos, button_rect)) {
    button_clicked();
}
```

## Common Patterns and Solutions

### 1. Animation System

**PyGame Animation:**
```python
class AnimatedSprite(pygame.sprite.Sprite):
    def __init__(self, images):
        super().__init__()
        self.images = images
        self.current_image = 0
        self.image = self.images[0]
        self.animation_speed = 0.1
        self.animation_timer = 0
    
    def update(self, dt):
        self.animation_timer += dt
        if self.animation_timer >= self.animation_speed:
            self.animation_timer = 0
            self.current_image = (self.current_image + 1) % len(self.images)
            self.image = self.images[self.current_image]
```

**Raylib Animation:**
```c
typedef struct {
    Texture2D sprite_sheet;
    Rectangle* frames;
    int frame_count;
    int current_frame;
    float frame_time;
    float timer;
} Animation;

void animation_update(Animation* anim, float dt) {
    anim->timer += dt;
    if (anim->timer >= anim->frame_time) {
        anim->timer = 0;
        anim->current_frame = (anim->current_frame + 1) % anim->frame_count;
    }
}

void animation_draw(Animation* anim, Vector2 position) {
    DrawTextureRec(anim->sprite_sheet, 
                   anim->frames[anim->current_frame],
                   position, WHITE);
}
```

### 2. Particle Systems

**PyGame Particles:**
```python
class Particle:
    def __init__(self, x, y):
        self.pos = pygame.Vector2(x, y)
        self.vel = pygame.Vector2(random.uniform(-100, 100), 
                                  random.uniform(-200, -50))
        self.lifetime = 1.0
        self.age = 0
        
    def update(self, dt):
        self.pos += self.vel * dt
        self.vel.y += 500 * dt  # Gravity
        self.age += dt
        
    def draw(self, screen):
        alpha = 1.0 - (self.age / self.lifetime)
        color = (*pygame.Color("yellow"), int(255 * alpha))
        pygame.draw.circle(screen, color, self.pos, 3)
```

**Raylib Particles:**
```c
typedef struct {
    Vector2 position;
    Vector2 velocity;
    Color color;
    float lifetime;
    float age;
    bool active;
} Particle;

typedef struct {
    Particle particles[MAX_PARTICLES];
    int active_count;
} ParticleSystem;

void particle_update(Particle* p, float dt) {
    if (!p->active) return;
    
    p->position.x += p->velocity.x * dt;
    p->position.y += p->velocity.y * dt;
    p->velocity.y += 500 * dt;  // Gravity
    p->age += dt;
    
    if (p->age >= p->lifetime) {
        p->active = false;
    }
}

void particle_draw(Particle* p) {
    if (!p->active) return;
    
    float alpha = 1.0f - (p->age / p->lifetime);
    Color c = Fade(p->color, alpha);
    DrawCircleV(p->position, 3, c);
}
```

### 3. Screen Transitions

**PyGame:**
```python
def fade_transition(surface1, surface2, progress):
    result = surface1.copy()
    surface2.set_alpha(int(255 * progress))
    result.blit(surface2, (0, 0))
    return result
```

**Raylib:**
```c
void draw_fade_transition(float progress) {
    // Draw current scene
    draw_current_scene();
    
    // Draw fade overlay
    DrawRectangle(0, 0, 640, 480, 
                  Fade(BLACK, progress));
}
```

## Performance Considerations for Dreamcast

### 1. Texture Management
- Convert all images to PVR format for hardware acceleration
- Use texture atlases to reduce texture switches
- Keep textures power-of-2 sizes (64x64, 128x128, etc.)

### 2. Memory Management
- Replace dynamic sprite groups with fixed-size pools
- Pre-allocate all game objects at startup
- Use object pooling for bullets, particles, etc.

### 3. Rendering Optimization
- Batch similar draw calls together
- Use hardware-accelerated primitives when possible
- Minimize transparency/alpha blending

## Migration Checklist

- [ ] Replace pygame.init() with InitWindow()
- [ ] Convert Surface objects to Texture2D
- [ ] Replace sprite Groups with object pools
- [ ] Convert event-based input to state-based
- [ ] Update collision detection functions
- [ ] Convert animations to sprite sheets
- [ ] Replace dynamic allocation with pools
- [ ] Optimize textures for PVR format
- [ ] Test with 4-player split screen
- [ ] Profile and optimize for 60 FPS

## Example: Simple Game Migration

Here's a complete example migrating a simple PyGame shooter to Raylib:

**Original PyGame (simplified):**
```python
import pygame

class Player(pygame.sprite.Sprite):
    def __init__(self):
        super().__init__()
        self.image = pygame.Surface((32, 32))
        self.image.fill((0, 255, 0))
        self.rect = self.image.get_rect(center=(320, 400))
        self.speed = 300
        
    def update(self, dt):
        keys = pygame.key.get_pressed()
        if keys[pygame.K_LEFT]:
            self.rect.x -= self.speed * dt
        if keys[pygame.K_RIGHT]:
            self.rect.x += self.speed * dt

pygame.init()
screen = pygame.display.set_mode((640, 480))
clock = pygame.time.Clock()
player = Player()
all_sprites = pygame.sprite.Group(player)

running = True
while running:
    dt = clock.tick(60) / 1000.0
    
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
            
    all_sprites.update(dt)
    
    screen.fill((0, 0, 0))
    all_sprites.draw(screen)
    pygame.display.flip()
```

**Migrated to Raylib:**
```c
#include "raylib.h"

typedef struct {
    Vector2 position;
    float speed;
    Color color;
} Player;

void player_init(Player* p) {
    p->position = (Vector2){320, 400};
    p->speed = 300.0f;
    p->color = GREEN;
}

void player_update(Player* p, float dt) {
    if (IsKeyDown(KEY_LEFT)) {
        p->position.x -= p->speed * dt;
    }
    if (IsKeyDown(KEY_RIGHT)) {
        p->position.x += p->speed * dt;
    }
    
    // Keep on screen
    if (p->position.x < 16) p->position.x = 16;
    if (p->position.x > 624) p->position.x = 624;
}

void player_draw(Player* p) {
    DrawRectangle(p->position.x - 16, p->position.y - 16, 
                  32, 32, p->color);
}

int main() {
    InitWindow(640, 480, "Simple Shooter");
    SetTargetFPS(60);
    
    Player player;
    player_init(&player);
    
    while (!WindowShouldClose()) {
        float dt = GetFrameTime();
        
        player_update(&player, dt);
        
        BeginDrawing();
        ClearBackground(BLACK);
        player_draw(&player);
        EndDrawing();
    }
    
    CloseWindow();
    return 0;
}
```

## Resources

- [Raylib Cheatsheet](https://www.raylib.com/cheatsheet/cheatsheet.html)
- [KallistiOS Documentation](http://gamedev.allusion.net/docs/kos/)
- [Dreamcast Development Forum](https://dcemulation.org/phpBB/viewforum.php?f=29)
