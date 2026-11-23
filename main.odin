
package main

import rl "vendor:raylib"
import "game"
import iso "isometric"
import "mission"
import "nav"
import "render"

// Translates the keyboard into one frame of simulation input.
input_poll :: proc() -> game.Input {
    input := game.Input{
        sneak = rl.IsKeyDown(rl.KeyboardKey.LEFT_CONTROL),
        run = rl.IsKeyDown(rl.KeyboardKey.LEFT_SHIFT),
        interact = rl.IsKeyPressed(rl.KeyboardKey.E),
        restart = rl.IsKeyPressed(rl.KeyboardKey.R),
    }

    if rl.IsKeyDown(rl.KeyboardKey.W) do input.move.y -= 1
    if rl.IsKeyDown(rl.KeyboardKey.S) do input.move.y += 1
    if rl.IsKeyDown(rl.KeyboardKey.A) do input.move.x -= 1
    if rl.IsKeyDown(rl.KeyboardKey.D) do input.move.x += 1

    return input
}

main :: proc() {
    rl.InitWindow(1280, 720, "Operation Eagle Nest - Greybox")
    defer rl.CloseWindow()

    rl.SetTargetFPS(60)

    level, mission_ok := mission.mission_load("missions/eagle/mission.json")
    if !mission_ok {
        return
    }

    world := game.world_init(level)
    defer game.world_destroy(&world)

    camera := iso.camera_init(render.mission_point_to_world(world.player.position, 1), 65)
    camera.follow_enabled = true

    nav_debug_path := nav.Navigation_Path_Result{}
    defer delete(nav_debug_path.points)

    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()

        // Toggle camera follow with F.
        if rl.IsKeyPressed(rl.KeyboardKey.F) {
            camera.follow_enabled = !camera.follow_enabled
        }

        game.game_update(&world, input_poll(), dt)

        // Recalculate a debug path for the west guard on demand.
        if rl.IsKeyPressed(rl.KeyboardKey.P) {
            delete(nav_debug_path.points)
            nav_debug_path = nav.Navigation_Path_Result{}

            if len(world.guards) > 0 {
                guard := &world.guards[0]

                if len(guard.patrol.points) > 0 &&
                   guard.patrol.target_index >= 0 &&
                   guard.patrol.target_index < len(guard.patrol.points) {
                    nav_debug_path = nav.nav_find_path(
                        &world.level,
                        guard.position,
                        guard.patrol.points[guard.patrol.target_index],
                        guard.radius,
                    )
                }
            }
        }

        iso.camera_update(&camera, dt)
        iso.camera_follow(&camera, render.mission_point_to_world(world.player.position, 1), dt)

        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)

        rl.BeginMode3D(camera.camera)
        render.render_world(world, nav_debug_path)
        rl.EndMode3D()

        render.hud_draw(world)

        rl.EndDrawing()
    }
}
