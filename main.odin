
package main

import "core:math"
import rl "vendor:raylib"
import iso "isometric"

Player :: struct {
    position: rl.Vector3,
    velocity: rl.Vector3,
    facing: rl.Vector3,
    radius: f32,
    move_speed: f32,
    acceleration: f32,
    deceleration: f32,
}

player_init :: proc(position: rl.Vector3) -> Player {
    return Player{
        position = position,
        facing = {0, 0, -1},
        radius = 0.8,
        move_speed = 12.0,
        acceleration = 36.0,
        deceleration = 48.0,
    }
}

player_update :: proc(p: ^Player, dt: f32) {
    input := rl.Vector3{}

    if rl.IsKeyDown(rl.KeyboardKey.W) do input.z -= 1
    if rl.IsKeyDown(rl.KeyboardKey.S) do input.z += 1
    if rl.IsKeyDown(rl.KeyboardKey.A) do input.x -= 1
    if rl.IsKeyDown(rl.KeyboardKey.D) do input.x += 1

    input_length := math.sqrt(input.x * input.x + input.z * input.z)

    desired := rl.Vector3{}
    if input_length > 0 {
        desired = input * (p.move_speed / input_length)
    }

    // Accelerate toward desired velocity, decelerate when released.
    delta := desired - p.velocity
    delta_length := math.sqrt(delta.x * delta.x + delta.z * delta.z)

    rate := p.acceleration
    if input_length == 0 do rate = p.deceleration

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

    if !player_collides(next, p.radius) {
        p.position.x = next.x
    } else {
        p.velocity.x = 0
    }

    next = p.position
    next.z += p.velocity.z * dt

    if !player_collides(next, p.radius) {
        p.position.z = next.z
    } else {
        p.velocity.z = 0
    }

    // Keep the player inside the mission area.
    p.position.x = math.clamp(p.position.x, p.radius, 100 - p.radius)
    p.position.z = math.clamp(p.position.z, p.radius, 100 - p.radius)
}

circle_hits_box :: proc(
    pos: rl.Vector3,
    radius: f32,
    min_x, min_z, max_x, max_z: f32,
) -> bool {
    closest_x := math.clamp(pos.x, min_x, max_x)
    closest_z := math.clamp(pos.z, min_z, max_z)

    dx := pos.x - closest_x
    dz := pos.z - closest_z

    return dx * dx + dz * dz < radius * radius
}

player_collides :: proc(pos: rl.Vector3, radius: f32) -> bool {
    // Barracks: x=37..65, z=12..31.
    if circle_hits_box(pos, radius, 37, 12, 65, 31) {
        return true
    }

    // Watchtower: x=78..86, z=25..33.
    if circle_hits_box(pos, radius, 78, 25, 86, 33) {
        return true
    }

    return false
}

main :: proc() {
    rl.InitWindow(1280, 720, "Operation Eagle Nest - Greybox")
    defer rl.CloseWindow()

    rl.SetTargetFPS(60)

    player := player_init({12, 1, 82})

    camera := iso.camera_init(player.position, 65)
    camera.follow_enabled = true

    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()

        // Toggle camera follow with F.
        if rl.IsKeyPressed(rl.KeyboardKey.F) {
            camera.follow_enabled = !camera.follow_enabled
        }

        player_update(&player, dt)

        iso.camera_update(&camera, dt)
        iso.camera_follow(&camera, player.position, dt)

        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)

        rl.BeginMode3D(camera.camera)

        rl.DrawPlane(
            {50, 0, 50},
            {100, 100},
            rl.LIGHTGRAY,
        )
        rl.DrawGrid(100, 5)

        // Barracks.
        rl.DrawCube(
            {51, 2, 21.5},
            28, 4, 19,
            rl.BROWN,
        )
        rl.DrawCubeWires(
            {51, 2, 21.5},
            28, 4, 19,
            rl.DARKGRAY,
        )

        // Watchtower.
        rl.DrawCube(
            {82, 5, 29},
            8, 10, 8,
            rl.GRAY,
        )
        rl.DrawCubeWires(
            {82, 5, 29},
            8, 10, 8,
            rl.DARKGRAY,
        )

        // Player and facing indicator.
        rl.DrawSphere(
            player.position,
            player.radius,
            rl.BLUE,
        )

        rl.DrawLine3D(
            player.position,
            player.position + player.facing * 2.5,
            rl.DARKBLUE,
        )

        // Extraction.
        rl.DrawCylinder(
            {84, 0.5, 88},
            3, 3, 1,
            16,
            rl.GREEN,
        )

        // Guard placeholders.
        rl.DrawSphere({30, 1, 35}, 1.2, rl.RED)
        rl.DrawSphere({55, 1, 48}, 1.2, rl.RED)
        rl.DrawSphere({76, 1, 35}, 1.2, rl.RED)

        rl.EndMode3D()

        rl.DrawText("OPERATION EAGLE NEST", 20, 20, 24, rl.DARKGRAY)
        rl.DrawText("WASD: move   F: toggle camera follow", 20, 54, 18, rl.DARKGRAY)
        rl.DrawText("Shift + drag: pan   Trackpad scroll: zoom", 20, 78, 18, rl.DARKGRAY)

        rl.EndDrawing()
    }
}
