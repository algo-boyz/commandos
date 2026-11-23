package main

import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:os"
import rl "vendor:raylib"

Mission_Point :: struct {
    x: f32,
    y: f32,
}

Mission_Rect :: struct {
    id: string,
    x: f32,
    y: f32,
    w: f32,
    h: f32,
}

Mission_Opening :: struct {
    id: string,
    y: f32,
    h: f32,
}

Mission_Wall :: struct {
    id: string,
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    openings: []Mission_Opening,
}

Mission_Cover :: struct {
    kind: string `json:"type"`,
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    r: f32,
}

Mission_Guard :: struct {
    id: string,
    patrol: []Mission_Point,
    speed: f32,
    pause_duration: f32 `json:"pauseDuration"`,
}

Mission_Extraction :: struct {
    x: f32,
    y: f32,
    radius: f32,
}

// A retrieve-style objective: the player completes it by interacting while
// within OBJECTIVE_INTERACT_RADIUS of (x, y). An empty id means the mission
// has no objective and extraction is available from the start.
Mission_Objective :: struct {
    id: string,
    kind: string `json:"type"`,
    x: f32,
    y: f32,
    building: string,
}

// Runtime collision / LOS geometry produced by mission_bake.
// Openings are expanded into solid segments so every consumer sees the same
// shape. Horizontal and vertical walls are both supported.
Solid_Rect :: struct {
    x, y, w, h: f32,
}

Solid_Circle :: struct {
    x, y, r: f32,
}

Mission_Geometry :: struct {
    solids:  []Solid_Rect,   // buildings, wall segments, crates
    circles: []Solid_Circle, // barrels, trees (collision only)
    baked:   bool,
}

Mission :: struct {
    player_spawn: Mission_Point `json:"playerSpawn"`,
    extraction: Mission_Extraction,
    objective: Mission_Objective,
    buildings: []Mission_Rect,
    walls: []Mission_Wall,
    cover: []Mission_Cover,
    guards: []Mission_Guard,
    // Filled by mission_bake / mission_ensure_baked. Not present in JSON.
    geometry: Mission_Geometry,
}

mission_load :: proc(path: string) -> (Mission, bool) {
    data, read_err := os.read_entire_file(path, context.allocator)
    if read_err != nil {
        fmt.eprintfln("mission: could not read %s: %v", path, read_err)
        return {}, false
    }
    defer delete(data)

    mission: Mission
    if err := json.unmarshal(data, &mission); err != nil {
        fmt.eprintfln("mission: invalid JSON in %s: %v", path, err)
        return {}, false
    }
    mission.geometry = mission_bake(&mission)
    return mission, true
}

// Expand walls (both orientations), buildings and cover into a single list of
// solid rects and circles. Openings become gaps between solid segments.
// The opening coordinate (Mission_Opening.y / .h) is treated as an interval
// along the wall's long axis.
mission_bake :: proc(mission: ^Mission, allocator := context.allocator) -> Mission_Geometry {
    solids:  [dynamic]Solid_Rect
    circles: [dynamic]Solid_Circle
    solids.allocator  = allocator
    circles.allocator = allocator

    for b in mission.buildings {
        append(&solids, Solid_Rect{b.x, b.y, b.w, b.h})
    }

    for wall in mission.walls {
        if len(wall.openings) == 0 {
            append(&solids, Solid_Rect{wall.x, wall.y, wall.w, wall.h})
            continue
        }

        vertical := wall.h >= wall.w
        if vertical {
            cursor := wall.y
            end := wall.y + wall.h
            for op in wall.openings {
                start := math.clamp(op.y, wall.y, end)
                stop  := math.clamp(op.y + op.h, wall.y, end)
                if start > cursor {
                    append(&solids, Solid_Rect{wall.x, cursor, wall.w, start - cursor})
                }
                cursor = max(cursor, stop)
            }
            if cursor < end {
                append(&solids, Solid_Rect{wall.x, cursor, wall.w, end - cursor})
            }
        } else {
            // Horizontal wall: openings measured along x.
            cursor := wall.x
            end := wall.x + wall.w
            for op in wall.openings {
                start := math.clamp(op.y, wall.x, end)
                stop  := math.clamp(op.y + op.h, wall.x, end)
                if start > cursor {
                    append(&solids, Solid_Rect{cursor, wall.y, start - cursor, wall.h})
                }
                cursor = max(cursor, stop)
            }
            if cursor < end {
                append(&solids, Solid_Rect{cursor, wall.y, end - cursor, wall.h})
            }
        }
    }

    for item in mission.cover {
        switch item.kind {
        case "crate":
            append(&solids, Solid_Rect{item.x, item.y, item.w, item.h})
        case "barrel", "tree":
            append(&circles, Solid_Circle{item.x, item.y, item.r})
        }
    }

    return Mission_Geometry{
        solids  = solids[:],
        circles = circles[:],
        baked   = true,
    }
}

mission_geometry_destroy :: proc(geo: ^Mission_Geometry) {
    delete(geo.solids)
    delete(geo.circles)
    geo^ = {}
}

// Ensures geometry is present. Safe to call repeatedly; used so hand-built
// Mission values in tests still work without an explicit bake step.
mission_ensure_baked :: proc(mission: ^Mission) {
    if mission.geometry.baked {
        return
    }
    mission.geometry = mission_bake(mission)
}

circle_hits_box :: proc(
    x, z, radius: f32,
    min_x, min_z, max_x, max_z: f32,
) -> bool {
    closest_x := math.clamp(x, min_x, max_x)
    closest_z := math.clamp(z, min_z, max_z)
    dx := x - closest_x
    dz := z - closest_z
    return dx*dx + dz*dz < radius*radius
}

circle_hits_circle :: proc(
    x, z, radius: f32,
    cx, cz, other_radius: f32,
) -> bool {
    dx := x - cx
    dz := z - cz
    combined := radius + other_radius
    return dx*dx + dz*dz < combined*combined
}

mission_point_collides :: proc(
    mission: ^Mission,
    point: Mission_Point,
    radius: f32,
) -> bool {
    mission_ensure_baked(mission)

    for s in mission.geometry.solids {
        if circle_hits_box(point.x, point.y, radius, s.x, s.y, s.x + s.w, s.y + s.h) {
            return true
        }
    }
    for c in mission.geometry.circles {
        if circle_hits_circle(point.x, point.y, radius, c.x, c.y, c.r) {
            return true
        }
    }
    return false
}

mission_collides :: proc(
    mission: ^Mission,
    pos: rl.Vector3,
    radius: f32,
) -> bool {
    return mission_point_collides(
        mission,
        Mission_Point{x = pos.x, y = pos.z},
        radius,
    )
}

mission_draw :: proc(mission: ^Mission) {
    // Draw from the original authoring data so openings remain visible as
    // gaps. Collision/LOS already use the baked solids, which stay in sync
    // because both paths are produced by the same bake rules.
    for wall in mission.walls {
        wall_height: f32 = 2.5
        if len(wall.openings) == 0 {
            rl.DrawCube(
                {wall.x + wall.w*0.5, wall_height*0.5, wall.y + wall.h*0.5},
                wall.w, wall_height, wall.h, rl.DARKGRAY,
            )
        } else {
            // Support both orientations (previously only vertical walls
            // were drawn when they had openings).
            vertical := wall.h >= wall.w
            if vertical {
                cursor := wall.y
                for opening in wall.openings {
                    opening_start := math.clamp(opening.y, wall.y, wall.y + wall.h)
                    opening_end := math.clamp(opening.y + opening.h, wall.y, wall.y + wall.h)
                    if opening_start > cursor {
                        segment_h := opening_start - cursor
                        rl.DrawCube(
                            {wall.x + wall.w*0.5, wall_height*0.5, cursor + segment_h*0.5},
                            wall.w, wall_height, segment_h, rl.DARKGRAY,
                        )
                    }
                    cursor = max(cursor, opening_end)
                }
                if cursor < wall.y + wall.h {
                    segment_h := wall.y + wall.h - cursor
                    rl.DrawCube(
                        {wall.x + wall.w*0.5, wall_height*0.5, cursor + segment_h*0.5},
                        wall.w, wall_height, segment_h, rl.DARKGRAY,
                    )
                }
            } else {
                cursor := wall.x
                for opening in wall.openings {
                    opening_start := math.clamp(opening.y, wall.x, wall.x + wall.w)
                    opening_end := math.clamp(opening.y + opening.h, wall.x, wall.x + wall.w)
                    if opening_start > cursor {
                        segment_w := opening_start - cursor
                        rl.DrawCube(
                            {cursor + segment_w*0.5, wall_height*0.5, wall.y + wall.h*0.5},
                            segment_w, wall_height, wall.h, rl.DARKGRAY,
                        )
                    }
                    cursor = max(cursor, opening_end)
                }
                if cursor < wall.x + wall.w {
                    segment_w := wall.x + wall.w - cursor
                    rl.DrawCube(
                        {cursor + segment_w*0.5, wall_height*0.5, wall.y + wall.h*0.5},
                        segment_w, wall_height, wall.h, rl.DARKGRAY,
                    )
                }
            }
        }
    }

    for building in mission.buildings {
        height: f32 = 4
        center := rl.Vector3{
            building.x + building.w*0.5,
            height*0.5,
            building.y + building.h*0.5,
        }
        rl.DrawCube(center, building.w, height, building.h, rl.BROWN)
        rl.DrawCubeWires(center, building.w, height, building.h, rl.DARKGRAY)
    }

    for item in mission.cover {
        if item.kind == "crate" {
            center := rl.Vector3{item.x + item.w*0.5, 1, item.y + item.h*0.5}
            rl.DrawCube(center, item.w, 2, item.h, rl.BROWN)
            rl.DrawCubeWires(center, item.w, 2, item.h, rl.DARKBROWN)
        } else if item.kind == "barrel" {
            rl.DrawCylinder({item.x, 1, item.y}, item.r, item.r, 2, 12, rl.DARKGREEN)
        } else if item.kind == "tree" {
            rl.DrawCylinder({item.x, 1.5, item.y}, 0.55, 0.4, 3, 8, rl.BROWN)
            rl.DrawSphere({item.x, 4, item.y}, item.r, rl.GREEN)
        }
    }
}
