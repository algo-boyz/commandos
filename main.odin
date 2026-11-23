
package main

import rl "vendor:raylib"
import iso "isometric"

// Translates the keyboard into one frame of simulation input.
input_poll :: proc() -> Input {
    input := Input{
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

    mission, mission_ok := mission_load("mission.json")
    if !mission_ok {
        return
    }

    world := world_init(mission)
    defer world_destroy(&world)

    camera := iso.camera_init(world.player.position, 65)
    camera.follow_enabled = true

    nav_debug_path := Navigation_Path_Result{}
    defer delete(nav_debug_path.points)

    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()

        // Toggle camera follow with F.
        if rl.IsKeyPressed(rl.KeyboardKey.F) {
            camera.follow_enabled = !camera.follow_enabled
        }

        game_update(&world, input_poll(), dt)

        // Recalculate a debug path for the west guard on demand.
        if rl.IsKeyPressed(rl.KeyboardKey.P) {
            delete(nav_debug_path.points)
            nav_debug_path = Navigation_Path_Result{}

            if len(world.guards) > 0 {
                guard := &world.guards[0]

                if len(guard.patrol.points) > 0 &&
                   guard.patrol.target_index >= 0 &&
                   guard.patrol.target_index < len(guard.patrol.points) {
                    nav_debug_path = nav_find_path(
                        &world.mission,
                        guard.position,
                        guard.patrol.points[guard.patrol.target_index],
                        guard.radius,
                    )
                }
            }
        }

        iso.camera_update(&camera, dt)
        iso.camera_follow(&camera, world.player.position, dt)

        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)

        rl.BeginMode3D(camera.camera)

        rl.DrawPlane(
            {50, 0, 50},
            {100, 100},
            rl.LIGHTGRAY,
        )
        rl.DrawGrid(100, 5)

        mission_draw(&world.mission)

        // Navigation debug path.
        if nav_debug_path.found && len(nav_debug_path.points) > 0 {
            for i in 0..<len(nav_debug_path.points) {
                point := nav_debug_path.points[i]

                // Draw path nodes just above ground level.
                rl.DrawSphere(
                    {point.x, 0.18, point.y},
                    0.20,
                    rl.GOLD,
                )

                // Connect consecutive nodes.
                if i + 1 < len(nav_debug_path.points) {
                    next := nav_debug_path.points[i + 1]

                    rl.DrawLine3D(
                        {point.x, 0.18, point.y},
                        {next.x, 0.18, next.y},
                        rl.GOLD,
                    )
                }
            }
        }

        // Player and facing indicator.
        rl.DrawSphere(
            world.player.position,
            world.player.radius,
            rl.BLUE,
        )

        rl.DrawLine3D(
            world.player.position,
            world.player.position + world.player.facing * 2.5,
            rl.DARKBLUE,
        )

        // Objective marker: gold until retrieved, then greyed out.
        if mission_has_objective(&world.mission) {
            objective_color := rl.GOLD
            if world.objective_complete {
                objective_color = rl.GRAY
            }

            rl.DrawCube(
                {world.mission.objective.x, 0.5, world.mission.objective.y},
                1.2, 1, 1.2,
                objective_color,
            )
        }

        // Extraction: faded while locked, solid green once the objective
        // is complete.
        extraction_color := rl.Fade(rl.GREEN, 0.3)
        if world.objective_complete {
            extraction_color = rl.GREEN
        }

        rl.DrawCylinder(
            {world.mission.extraction.x, 0.5, world.mission.extraction.y},
            world.mission.extraction.radius, world.mission.extraction.radius, 1,
            16,
            extraction_color,
        )

        // Guards
        for i in 0..<len(world.guards) {
            guard := &world.guards[i]

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
        rl.DrawText("WASD: move   Ctrl: sneak   Shift: run   E: interact   R: restart", 20, 54, 18, rl.DARKGRAY)
        rl.DrawText("F: camera follow   P: calculate guard path   Shift + drag: pan   Trackpad scroll: zoom", 20, 78, 18, rl.DARKGRAY)

        if mission_has_objective(&world.mission) {
            if world.objective_complete {
                rl.DrawText("OBJECTIVE COMPLETE - reach the extraction zone", 20, 102, 20, rl.DARKGREEN)
            } else {
                rl.DrawText("OBJECTIVE: retrieve the documents (press E near them)", 20, 102, 20, rl.DARKGRAY)
            }
        }

        if world.outcome == .SUCCESS {
            rl.DrawText("MISSION COMPLETE - press R to restart", 20, 134, 30, rl.DARKGREEN)
        } else if world.outcome == .FAILED {
            rl.DrawText("CAUGHT - press R to restart", 20, 134, 30, rl.MAROON)
        }

        rl.EndDrawing()
    }
}
