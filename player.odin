package main

import "core:math"
import rl "vendor:raylib"

PLAYER_WALK_SPEED :: 12.0
PLAYER_SNEAK_SPEED :: 4.5
PLAYER_RUN_SPEED :: 18.0

PLAYER_WALK_INTERVAL :f32: 0.45
PLAYER_SNEAK_INTERVAL :: 0.70
PLAYER_RUN_INTERVAL :: 0.30

PLAYER_WALK_NOISE_RADIUS :: 18.0
PLAYER_SNEAK_NOISE_RADIUS :: 6.0
PLAYER_RUN_NOISE_RADIUS :: 30.0

PLAYER_WALK_NOISE_INTENSITY :: 1.0
PLAYER_SNEAK_NOISE_INTENSITY :: 0.35
PLAYER_RUN_NOISE_INTENSITY :: 1.5

Player :: struct {
    position: rl.Vector3,
    velocity: rl.Vector3,
    facing: rl.Vector3,
    radius: f32,
    move_speed: f32,
    acceleration: f32,
    deceleration: f32,
    footstep_timer: f32,
    footstep_noise_radius: f32,
    footstep_noise_intensity: f32,
}

player_init :: proc(position: rl.Vector3) -> Player {
    return Player{
        position = position,
        facing = {0, 0, -1},
        radius = 0.8,
        move_speed = 12.0,
        acceleration = 36.0,
        deceleration = 48.0,
        footstep_timer = 0,
        footstep_noise_radius = PLAYER_WALK_NOISE_RADIUS,
        footstep_noise_intensity = PLAYER_WALK_NOISE_INTENSITY,
    }
}

// Advances the player by dt using the given input.
// Returns true on the frame a footstep is emitted.
player_update :: proc(
    p: ^Player,
    input: Input,
    mission: ^Mission,
    dt: f32,
) -> bool {
    sneaking := input.sneak
    running := input.run && !sneaking

    if sneaking {
        p.move_speed = PLAYER_SNEAK_SPEED
        p.footstep_noise_radius = PLAYER_SNEAK_NOISE_RADIUS
        p.footstep_noise_intensity = PLAYER_SNEAK_NOISE_INTENSITY
    } else if running {
        p.move_speed = PLAYER_RUN_SPEED
        p.footstep_noise_radius = PLAYER_RUN_NOISE_RADIUS
        p.footstep_noise_intensity = PLAYER_RUN_NOISE_INTENSITY
    } else {
        p.move_speed = PLAYER_WALK_SPEED
        p.footstep_noise_radius = PLAYER_WALK_NOISE_RADIUS
        p.footstep_noise_intensity = PLAYER_WALK_NOISE_INTENSITY
    }

    move := rl.Vector3{input.move.x, 0, input.move.y}
    move_length := math.sqrt(move.x * move.x + move.z * move.z)

    desired := rl.Vector3{}
    if move_length > 0 {
        desired = move * (p.move_speed / move_length)
    }

    // Accelerate toward desired velocity, decelerate when released.
    delta := desired - p.velocity
    delta_length := math.sqrt(delta.x * delta.x + delta.z * delta.z)

    rate := p.acceleration
    if move_length == 0 do rate = p.deceleration

    max_change := rate * dt

    if delta_length > max_change && delta_length > 0 {
        p.velocity += delta * (max_change / delta_length)
    } else {
        p.velocity = desired
    }

    // Update facing only while moving.
    velocity_length := math.sqrt(
        p.velocity.x * p.velocity.x +
        p.velocity.z * p.velocity.z,
    )

    if velocity_length > 0.1 {
        p.facing = {
            p.velocity.x / velocity_length,
            0,
            p.velocity.z / velocity_length,
        }
    }

    // Resolve movement independently on each axis.
    next := p.position
    next.x += p.velocity.x * dt

    if !mission_collides(mission, next, p.radius) {
        p.position.x = next.x
    } else {
        p.velocity.x = 0
    }

    next = p.position
    next.z += p.velocity.z * dt

    if !mission_collides(mission, next, p.radius) {
        p.position.z = next.z
    } else {
        p.velocity.z = 0
    }

    // Keep the player inside the mission area.
    p.position.x = math.clamp(p.position.x, p.radius, 100 - p.radius)
    p.position.z = math.clamp(p.position.z, p.radius, 100 - p.radius)

    interval := PLAYER_WALK_INTERVAL

    if sneaking {
        interval = PLAYER_SNEAK_INTERVAL
    } else if running {
        interval = PLAYER_RUN_INTERVAL
    }
    // Emit a footstep at the configured cadence while moving.
    speed := math.sqrt(p.velocity.x*p.velocity.x + p.velocity.z*p.velocity.z)

    if speed > 0.5 {
        p.footstep_timer -= dt

        if p.footstep_timer <= 0 {
            p.footstep_timer = interval
            return true
        }
    } else {
        p.footstep_timer = 0
    }

    return false
}
