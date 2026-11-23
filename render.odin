package main

import rl "vendor:raylib"

// Everything that turns simulation state into pixels lives in render.odin and
// hud.odin. This is the only place (besides main.odin and the isometric
// camera) that touches raylib, so the simulation stays headless.
//
// The render procs take the World by value. A World is a handful of slices
// and small structs, so the copy is cheap, and it means a render proc cannot
// mutate the simulation.

WALL_RENDER_HEIGHT     :: 2.5
BUILDING_RENDER_HEIGHT :: 4.0
CRATE_RENDER_HEIGHT    :: 2.0

// Map a simulation point into the renderer's 3D space (x → x, y → z).
mission_point_to_world :: proc(p: Mission_Point, height: f32 = 0) -> rl.Vector3 {
    return rl.Vector3{p.x, height, p.y}
}

// Draws the 3D scene. Call between BeginMode3D and EndMode3D. debug_path is
// optional; pass an empty result to draw nothing.
render_world :: proc(world: World, debug_path: Navigation_Path_Result) {
    // mission_bounds takes a pointer, so give it a local copy to point at.
    mission := world.mission

    render_ground(&mission)
    render_geometry(world.mission.geometry)
    render_debug_path(debug_path)
    render_objective(world)
    render_extraction(world)
    render_player(world.player)
    render_guards(world.guards)
}

render_ground :: proc(mission: ^Mission) {
    bounds := mission_bounds(mission)

    rl.DrawPlane(
        {bounds.width * 0.5, 0, bounds.height * 0.5},
        {bounds.width, bounds.height},
        rl.LIGHTGRAY,
    )
    rl.DrawGrid(i32(max(bounds.width, bounds.height)), 5)
}

// Draws the baked collision geometry. Because collision, line of sight and
// rendering all read the same list, a wall opening you can see is an opening
// the guards and the player can use, for walls of either orientation.
render_geometry :: proc(geo: Mission_Geometry) {
    for s in geo.solids {
        height: f32
        color: rl.Color
        wire: rl.Color
        draw_wires := false

        #partial switch s.kind {
        case .WALL:
            height = WALL_RENDER_HEIGHT
            color = rl.DARKGRAY
        case .BUILDING:
            height = BUILDING_RENDER_HEIGHT
            color = rl.BROWN
            wire = rl.DARKGRAY
            draw_wires = true
        case .CRATE:
            height = CRATE_RENDER_HEIGHT
            color = rl.BROWN
            wire = rl.DARKBROWN
            draw_wires = true
        case:
            continue
        }

        center := rl.Vector3{s.x + s.w*0.5, height*0.5, s.y + s.h*0.5}
        rl.DrawCube(center, s.w, height, s.h, color)
        if draw_wires {
            rl.DrawCubeWires(center, s.w, height, s.h, wire)
        }
    }

    for c in geo.circles {
        #partial switch c.kind {
        case .BARREL:
            rl.DrawCylinder({c.x, 1, c.y}, c.r, c.r, 2, 12, rl.DARKGREEN)
        case .TREE:
            rl.DrawCylinder({c.x, 1.5, c.y}, 0.55, 0.4, 3, 8, rl.BROWN)
            rl.DrawSphere({c.x, 4, c.y}, c.r, rl.GREEN)
        }
    }
}

render_debug_path :: proc(path: Navigation_Path_Result) {
    if !path.found || len(path.points) == 0 {
        return
    }

    // Path nodes sit just above ground level.
    for i in 0..<len(path.points) {
        point := mission_point_to_world(path.points[i], 0.18)
        rl.DrawSphere(point, 0.20, rl.GOLD)

        if i + 1 < len(path.points) {
            next := mission_point_to_world(path.points[i + 1], 0.18)
            rl.DrawLine3D(point, next, rl.GOLD)
        }
    }
}

// Objective marker: gold until retrieved, then greyed out.
render_objective :: proc(world: World) {
    if world.mission.objective.id == "" {
        return
    }

    color := rl.GOLD
    if world.objective_complete {
        color = rl.GRAY
    }

    rl.DrawCube(
        {world.mission.objective.x, 0.5, world.mission.objective.y},
        1.2, 1, 1.2,
        color,
    )
}

// Extraction: faded while locked, solid green once the objective is complete.
render_extraction :: proc(world: World) {
    color := rl.Fade(rl.GREEN, 0.3)
    if world.objective_complete {
        color = rl.GREEN
    }

    e := world.mission.extraction
    rl.DrawCylinder({e.x, 0.5, e.y}, e.radius, e.radius, 1, 16, color)
}

PLAYER_FACING_INDICATOR_LENGTH :: 2.5
GUARD_FACING_INDICATOR_LENGTH  :: 1.8

render_player :: proc(player: Player) {
    position := mission_point_to_world(player.position, 1)
    facing_tip := mission_point_to_world(
        {
            player.position.x + player.facing.x * PLAYER_FACING_INDICATOR_LENGTH,
            player.position.y + player.facing.y * PLAYER_FACING_INDICATOR_LENGTH,
        },
        1,
    )

    rl.DrawSphere(position, player.radius, rl.BLUE)
    rl.DrawLine3D(position, facing_tip, rl.DARKBLUE)
}

render_guards :: proc(guards: []Guard) {
    for guard in guards {
        position := mission_point_to_world(guard.position, 1)
        facing_tip := mission_point_to_world(
            {
                guard.position.x + guard.facing.x * GUARD_FACING_INDICATOR_LENGTH,
                guard.position.y + guard.facing.y * GUARD_FACING_INDICATOR_LENGTH,
            },
            1,
        )

        color := rl.RED
        #partial switch guard.awareness.state {
        case .SUSPICIOUS:
            color = rl.ORANGE
        case .ALERTED:
            color = rl.MAROON
        }

        rl.DrawSphere(position, guard.radius, color)
        rl.DrawLine3D(position, facing_tip, rl.MAROON)
    }
}
