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

Mission :: struct {
    player_spawn: Mission_Point `json:"playerSpawn"`,
    extraction: Mission_Extraction,
    objective: Mission_Objective,
    buildings: []Mission_Rect,
    walls: []Mission_Wall,
    cover: []Mission_Cover,
    guards: []Mission_Guard,
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
    return mission, true
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

wall_collides :: proc(wall: Mission_Wall, x, z, radius: f32) -> bool {
    if len(wall.openings) == 0 {
        return circle_hits_box(
            x, z, radius,
            wall.x, wall.y, wall.x + wall.w, wall.y + wall.h,
        )
    }

    // Openings in this mission are specified along vertical wall segments.
    if wall.h >= wall.w {
        cursor := wall.y
        for opening in wall.openings {
            opening_start := math.clamp(opening.y, wall.y, wall.y + wall.h)
            opening_end := math.clamp(opening.y + opening.h, wall.y, wall.y + wall.h)
            if opening_start > cursor && circle_hits_box(
                x, z, radius,
                wall.x, cursor, wall.x + wall.w, opening_start,
            ) {
                return true
            }
            cursor = max(cursor, opening_end)
        }
        if cursor < wall.y + wall.h && circle_hits_box(
            x, z, radius,
            wall.x, cursor, wall.x + wall.w, wall.y + wall.h,
        ) {
            return true
        }
        return false
    }

    return circle_hits_box(
        x, z, radius,
        wall.x, wall.y, wall.x + wall.w, wall.y + wall.h,
    )
}


mission_point_collides :: proc(
    mission: ^Mission,
    point: Mission_Point,
    radius: f32,
) -> bool {
    for building in mission.buildings {
        if circle_hits_box(
            point.x, point.y, radius,
            building.x, building.y,
            building.x + building.w, building.y + building.h,
        ) {
            return true
        }
    }

    for wall in mission.walls {
        if wall_collides(wall, point.x, point.y, radius) {
            return true
        }
    }

    for item in mission.cover {
        if item.kind == "crate" {
            if circle_hits_box(
                point.x, point.y, radius,
                item.x, item.y,
                item.x + item.w, item.y + item.h,
            ) {
                return true
            }
        } else if item.kind == "barrel" || item.kind == "tree" {
            if circle_hits_circle(
                point.x, point.y, radius,
                item.x, item.y, item.r,
            ) {
                return true
            }
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
    for wall in mission.walls {
        wall_height: f32 = 2.5
        if len(wall.openings) == 0 {
            rl.DrawCube(
                {wall.x + wall.w*0.5, wall_height*0.5, wall.y + wall.h*0.5},
                wall.w, wall_height, wall.h, rl.DARKGRAY,
            )
        } else if wall.h >= wall.w {
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
