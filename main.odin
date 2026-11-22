
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

player_update :: proc(p: ^Player, mission: ^Mission, dt: f32) {
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
}

main :: proc() {
    rl.InitWindow(1280, 720, "Operation Eagle Nest - Greybox")
    defer rl.CloseWindow()

    rl.SetTargetFPS(60)

    mission, mission_ok := mission_load("mission.json")
    if !mission_ok {
        return
    }

    player := player_init({mission.player_spawn.x, 1, mission.player_spawn.y})

    guards := guards_init(&mission)
    defer delete(guards)

    camera := iso.camera_init(player.position, 65)
    camera.follow_enabled = true

    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()

        // Toggle camera follow with F.
        if rl.IsKeyPressed(rl.KeyboardKey.F) {
            camera.follow_enabled = !camera.follow_enabled
        }

        player_update(&player, &mission, dt)

        vision := VISION_DEFAULT
        awareness_config := AWARENESS_DEFAULT
        player_point := Mission_Point{player.position.x, player.position.z}

        // 1. Perception and awareness.
        for i in 0..<len(guards) {
            guard := &guards[i]

            sees_player := guard_can_see(
                guard.position,
                guard.facing,
                player_point,
                &mission,
                vision,
            )

            guard.player_visible = sees_player

            guard_awareness_update(
                &guard.awareness,
                sees_player,
                player_point,
                dt,
                awareness_config,
            )
        }

        // 2. Behaviour reacts to the freshly updated awareness.
        guard_update(guards, &mission, dt)
        
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

        mission_draw(&mission)

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
            {mission.extraction.x, 0.5, mission.extraction.y},
            mission.extraction.radius, mission.extraction.radius, 1,
            16,
            rl.GREEN,
        )

        // Guards
        for i in 0..<len(guards) {
            guard := &guards[i]

            sees_player := guard_can_see(
                guard.position,
                guard.facing,
                player_point,
                &mission,
                vision,
            )

            guard.player_visible = sees_player

            guard_awareness_update(
                &guard.awareness,
                sees_player,
                player_point,
                dt,
                awareness_config,
            )

            guard_position := rl.Vector3{
                guard.position.x,
                1,
                guard.position.y,
            }

            guard_color := rl.RED
            if guard.awareness.state == .SUSPICIOUS {
                guard_color = rl.ORANGE
            } else if guard.awareness.state == .ALERTED {
                guard_color = rl.MAROON
            }

            rl.DrawSphere(guard_position, guard.radius, guard_color)

            rl.DrawLine3D(
                guard_position,
                guard_position + rl.Vector3{
                    guard.facing.x,
                    0,
                    guard.facing.y,
                } * 1.8,
                rl.MAROON,
            )
        }

        rl.EndMode3D()

        rl.DrawText("OPERATION EAGLE NEST", 20, 20, 24, rl.DARKGRAY)
        rl.DrawText("WASD: move   F: toggle camera follow", 20, 54, 18, rl.DARKGRAY)
        rl.DrawText("Shift + drag: pan   Trackpad scroll: zoom", 20, 78, 18, rl.DARKGRAY)

        rl.EndDrawing()
    }
}
